import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';

/// Bridge to the native Compose Language screen.
///
/// [openLanguageScreen] opens the screen as a native nav destination via
/// [KmpNavigationBridge] (single-Activity + NavHost — no `LanguageActivity`). The
/// screen's save-apply + analytics call back over the `com.snabbit.runner/language`
/// MethodChannel (native -> Dart), handled by [_handleNativeCall] (installed lazily
/// by [_ensureNativeCallHandler] before the screen can call back). Mirrors
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/LanguagePlugin.kt`.
class LanguageChannel {
  static const _channel = MethodChannel('com.snabbit.runner/language');
  static bool _nativeHandlerInstalled = false;

  /// shared_preferences key the native side writes the just-changed language to
  /// (natively as `flutter.pending_language_preference` — the plugin strips the
  /// `flutter.` prefix on read). Consumed + cleared by [reconcilePendingLanguage].
  /// Mirrors `LanguagePlugin.writePendingLanguage`.
  static const _pendingLanguagePrefKey = 'pending_language_preference';

  /// Opens the native Compose Language screen as a native nav destination in the
  /// single nav host (no `LanguageActivity`). The current language and the two
  /// server-driven i18n labels are passed as string args so the native screen
  /// renders without a round-trip back to Flutter.
  ///
  /// Returns `false` if the destination couldn't be opened (e.g. KMP not ready /
  /// no native host) — the caller falls back to the Flutter `LanguageHome`.
  static Future<bool> openLanguageScreen({
    required String? currentLanguage,
    required String title,
    required String confirmLabel,
  }) async {
    // Belt-and-suspenders: the handler is installed eagerly at startup
    // ([ensureNativeCallHandler] in main.dart), but re-assert it here (idempotent)
    // for the drawer entry.
    ensureNativeCallHandler();
    return KmpNavigationBridge.instance.openNativeDestination('language', {
      if (currentLanguage != null) 'currentLanguage': currentLanguage,
      'title': title,
      'confirmLabel': confirmLabel,
    });
  }

  /// Installs the native -> Dart handler for the Language screen's callbacks
  /// (`applyLanguage` / `trackLanguageEvent`). Idempotent.
  ///
  /// Must be installed BEFORE the screen can call back, regardless of entry
  /// path — the Flutter drawer ([openLanguageScreen]) OR the KMP Profile tab
  /// (`nav.navigate(LanguageDestination)`, which never goes through
  /// [openLanguageScreen]). So it's called eagerly at startup in `main.dart`;
  /// without that, the Profile-tab entry has no listener and native's
  /// `applyLanguage` invoke times out (15s), stalling the confirm.
  static void ensureNativeCallHandler() {
    if (_nativeHandlerInstalled) return;
    _nativeHandlerInstalled = true;
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'applyLanguage':
        await _handleApplyLanguage(call.arguments as String);
        return null;
      case 'trackLanguageEvent':
        _handleTrackLanguageEvent(
          (call.arguments as Map).cast<String, dynamic>(),
        );
        return null;
      default:
        throw MissingPluginException(
          'LanguageChannel: no handler for "${call.method}"',
        );
    }
  }

  /// Applies an already-persisted language change to Flutter-owned state:
  /// updates the local profile preference and reloads the i18n file. The
  /// network persist (`PATCH change_language`) is done by the KMP datasource
  /// BEFORE this is called, so this is best-effort and never throws — a
  /// failure here only means the in-app strings lag until the next reload.
  static Future<void> _handleApplyLanguage(String code) async {
    final context = GlobalState().navigatorKey.currentContext;
    if (context == null) {
      MonitoringServiceHelper.logError('language_apply_no_context', {
        'code': code,
      });
      return;
    }
    final languageProvider = await _applyLanguageToProviders(context, code);
    if (languageProvider.error != null) {
      MonitoringServiceHelper.logError('language_apply_i18n_failed', {
        'code': code,
        'error': languageProvider.error,
      });
    }
  }

  /// Applies an already-persisted language [code] to Flutter-owned state — the
  /// local profile preference + a reload of the i18n file — and returns the
  /// [LanguageProvider] so callers can inspect [LanguageProvider.error]. Shared by
  /// the live native callback ([_handleApplyLanguage]) and the resume-time safety
  /// net ([reconcilePendingLanguage]).
  static Future<LanguageProvider> _applyLanguageToProviders(
    BuildContext context,
    String code,
  ) async {
    final userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    userProfileProvider.languagePreference = code;

    // Reload the i18n file for the new language (populates app-wide messages).
    await languageProvider.fetchMessages(code);
    return languageProvider;
  }

  /// Resume-time safety net for a KMP language change the live
  /// [_handleApplyLanguage] callback couldn't apply: the Compose Language screen
  /// runs in `NavigationHostActivity` with the Flutter engine backgrounded, so
  /// that round-trip can be dropped or time out, leaving reused Flutter pages on
  /// the old language until the next cold start.
  ///
  /// The native side reliably persists the chosen code
  /// (`LanguagePlugin.writePendingLanguage`); this reads it back the moment
  /// Flutter is foreground again, reloads the i18n file if it differs from what's
  /// loaded, then clears the flag. Idempotent and cheap — safe to call on every
  /// `resumed` lifecycle event (a no-op when nothing is pending).
  ///
  /// Callers gate this behind the `cmpLanguageScreenEnabled` RC kill-switch (only
  /// the native Compose Language screen produces a pending write) — see
  /// `main.dart`'s resume handler.
  static Future<void> reconcilePendingLanguage() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      // The native write landed after this isolate cached prefs — refresh first.
      await prefs.reload();
    } catch (e) {
      MonitoringServiceHelper.logError('language_reconcile_prefs_failed', {
        'error': e.toString(),
      });
      return;
    }

    final pending = prefs.getString(_pendingLanguagePrefKey);
    if (pending == null || pending.isEmpty) return;

    // Clear the flag only when the language was actually applied; otherwise keep
    // it so the next resume retries. The apply is factored out so the navigator
    // context is fetched fresh (no await before its use) — reused Flutter pages'
    // one source of truth is the in-memory LanguageProvider, not this flag.
    if (await _applyPendingLanguage(pending)) {
      await prefs.remove(_pendingLanguagePrefKey);
    }
  }

  /// Applies a [pending] language read from prefs to the live providers. Returns
  /// true when the flag can be cleared (applied, or already current), false to
  /// retry on the next resume (no navigator context yet, or the i18n reload
  /// failed). Fetches the navigator context at the top so it's never used across
  /// an async gap.
  static Future<bool> _applyPendingLanguage(String pending) async {
    final context = GlobalState().navigatorKey.currentContext;
    if (context == null) {
      // No navigator yet — keep the flag and retry on the next resume.
      MonitoringServiceHelper.logError('language_reconcile_no_context', {
        'code': pending,
      });
      return false;
    }

    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    if (pending == languageProvider.currentLanguageCode) {
      // Already applied (e.g. the live callback won the race) — just clear.
      return true;
    }

    await _applyLanguageToProviders(context, pending);
    if (languageProvider.error != null) {
      // i18n reload failed — keep the flag so the next resume retries.
      MonitoringServiceHelper.logError('language_reconcile_i18n_failed', {
        'code': pending,
        'error': languageProvider.error,
      });
      return false;
    }
    return true;
  }

  static void _handleTrackLanguageEvent(Map<String, dynamic> args) {
    final event = args['event'] as String?;
    if (event == null) return;
    final code = args['code'] as String?;
    final props = <String, dynamic>{
      if (code != null) 'language_code': code,
    };
    // Best-effort; swallow async rejections so a failing analytics SDK can't
    // surface as an unhandled async error.
    MixpanelSetup.logEvent(event, props).catchError((_) {});
    ClevertapSetup.logEvent(event, props).catchError((_) {});
  }
}
