import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/pages/insurance_support.dart';
import 'package:snabbit_runner/pages/language_home.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/pages/payout/early_payouts/early_payouts_screen.dart';
import 'package:snabbit_runner/pages/payout/payout_home.dart';
import 'package:snabbit_runner/pages/payout/transaction_history.dart';
import 'package:snabbit_runner/pages/referral_home.dart';
import 'package:snabbit_runner/providers/loan_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/loan_service.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/nav_observer.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/drawer/identity_card.dart';
import 'package:snabbit_runner/widgets/drawer/long_leave.dart';

import 'deeplink_channel.dart';
import 'deeplink_result.dart';
import 'referral_attribution_store.dart';

/// Signature for a destination handler. [context] is the navigator-bound
/// context, guaranteed non-null and on a routable (PartnerHome) screen by the
/// dispatcher before any handler runs.
typedef _DeeplinkHandler = Future<void> Function(BuildContext context);

/// Central deeplink router. Every inbound deeplink — FCM, CleverTap, or
/// AppsFlyer OneLink — is normalised to a [Uri] and dispatched here.
///
/// Backend / marketing payload contract (path-only, v1, no query params):
///
///   `snabbitrunner:///{path}`
///
/// where `{path}` is one of the keys in [_routes]. The URI path and the Flutter
/// `routeName` are intentionally decoupled — [_routes] is the single source of
/// truth. Unknown paths and unservable destinations fall back to Home; the
/// runner never lands on a blank/broken screen.
///
/// The whole router is gated by [RemoteConfigKeys.enableDeeplinks] (default
/// on) — when off, [dispatch] returns [DeepLinkResult.notHandled] so callers
/// revert to pre-feature behaviour.
class DeepLinkRouter {
  DeepLinkRouter._();
  static final DeepLinkRouter instance = DeepLinkRouter._();

  /// path -> handler. The single allowlist of what a deeplink may open.
  late final Map<String, _DeeplinkHandler> _routes = {
    'identity-card': (c) => _push(c, IdentityCard.routeName),
    'monthly-earnings': _openMonthlyEarnings,
    'rate-card': (c) => _openWebviewPath(
        c, WebviewRoutes.payoutsRateCardEducation, 'Rate card'),
    'early-payouts': (c) => _push(c, EarlyPayoutsScreen.routeName),
    'referral-home': _openReferral,
    'transaction-history': (c) => _push(c, TransactionHistory.routeName),
    'seva': (c) => _openProfileWebview(c, _userOf(c)?.sevaUrl, 'Seva', 'seva'),
    'merch-store': (c) => _openProfileWebview(
        c, _userOf(c)?.merchStoreUrl, 'Merch Store', 'merch-store'),
    'insurance-support': (c) => _push(c, InsuranceSupport.routeName),
    'long-leave': (c) => _push(c, LongLeaveApplication.routeName),
    'language-home': _openLanguage,
    'loan': _openLoan,
  };

  /// The KMP navigation bridge. A field (rather than a direct
  /// `KmpNavigationBridge.instance` reference at each call site) so tests can
  /// substitute a fake to exercise the host-backed keep-host path.
  @visibleForTesting
  KmpNavigationBridge bridge = KmpNavigationBridge.instance;

  /// Test-only override for the [RemoteConfigKeys.enableDeeplinks] kill switch.
  /// Null (production) → read Remote Config.
  @visibleForTesting
  bool? debugEnabledOverride;

  bool get _enabled =>
      debugEnabledOverride ??
      RemoteConfigService.instance
          .getBool(RemoteConfigKeys.enableDeeplinks, defaultValue: true);

  StreamSubscription<Map<String, dynamic>>? _oneLinkSub;

  /// Wire AppsFlyer OneLink (UDL) into the router: subscribe to the warm stream
  /// and drain any link that resolved before the stream attached (cold start).
  /// Idempotent — safe to call once during app init. Dispatch itself is gated
  /// by [RemoteConfigKeys.enableDeeplinks], so this is inert while the flag is
  /// off.
  void initOneLink() {
    _oneLinkSub ??= DeeplinkChannel.deeplinks.listen(
      _dispatchOneLink,
      onError: (Object e) => MonitoringServiceHelper.logWarning(
        'deeplink_onelink_stream_error',
        {'error': e.toString()},
      ),
    );
    // `getInitialDeeplink` is a `MethodChannel.invokeMethod` call — it can
    // throw `PlatformException`, `MissingPluginException`, or a Map cast
    // failure. Mirror the stream's `onError` so a cold-start failure surfaces
    // in Monitoring instead of becoming an unhandled async error.
    DeeplinkChannel.getInitialDeeplink().then(
      (raw) {
        if (raw != null) _dispatchOneLink(raw);
      },
      onError: (Object e) => MonitoringServiceHelper.logWarning(
        'deeplink_onelink_initial_failed',
        {'error': e.toString()},
      ),
    );
  }

  void _dispatchOneLink(Map<String, dynamic> raw) {
    _captureReferralAttribution(raw);
    final uri = mapOneLinkParams(raw);
    if (uri != null) dispatch(uri, source: DeeplinkSource.onelink);
  }

  @visibleForTesting
  void captureReferralAttributionForTest(Map<String, dynamic> raw) =>
      _captureReferralAttribution(raw);

  void _captureReferralAttribution(Map<String, dynamic> raw) {
    try {
      final attribution = ReferralAttribution.fromOneLinkParams(raw);
      if (attribution == null) return;
      unawaited(
        _persistAttribution(attribution).catchError((Object e) {
          MonitoringServiceHelper.logWarning(
            'referral_attribution_persist_failed',
            {'error': e.toString()},
          );
        }),
      );
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'referral_attribution_capture_failed',
        {'error': e.toString()},
      );
    }
  }

  Future<void> _persistAttribution(ReferralAttribution attribution) async {
    final existing = await ReferralAttributionStore.read();
    if (existing != null && existing.referrerId != attribution.referrerId) {
      MonitoringServiceHelper.logWarning(
        'referral_attribution_overwritten',
        {
          'previous_referrer_id': existing.referrerId,
          'new_referrer_id': attribution.referrerId,
          'previous_attempt_count': existing.attemptCount,
        },
      );
    }
    await ReferralAttributionStore.save(
      referrerId: attribution.referrerId,
      campaignId: attribution.campaignId,
    );
  }

  /// Dispatch a deeplink now. Parks it in the pending slot if the app isn't
  /// routable yet (no navigator context / not authenticated).
  Future<DeepLinkResult> dispatch(Uri uri, {required DeeplinkSource source}) =>
      _dispatch(uri, source: source, allowQueue: true);

  /// Drain the single pending slot.
  ///
  /// [allowRequeue] governs what happens when the link still can't be opened on
  /// the native shell (cohort runner, shell not yet the foreground surface):
  ///  - `true` (shell-resume drain) → the dispatch RE-QUEUES the link so a later
  ///    shell `onResume` retries it. This is the key to the warm/re-launch case:
  ///    the held link is never consumed until the host-backed handoff actually
  ///    lands, so a shell that (re)launches can't leave it pushed behind.
  ///  - `false` (fail-open drain, PartnerHome drain) → the dispatch falls through
  ///    to the Flutter surface (the shell isn't coming up), so the link still opens.
  Future<void> drainPending({bool allowRequeue = false}) async {
    // In-memory first (same-isolate fast path); fall back to the persisted slot,
    // which survives the app re-launch / fresh isolate a OneLink tap triggers (the
    // click spawns a new engine behind the shell, wiping the in-memory queue).
    final pending =
        GlobalState().pendingDeeplink ?? await _readPersistedPending();
    if (pending == null) return;
    GlobalState().pendingDeeplink = null;
    await _clearPersistedPending();
    await _dispatch(pending.uri,
        source: pending.source, allowQueue: allowRequeue);
  }

  // --- Pending-deeplink persistence -----------------------------------------
  // A OneLink tap while the app is backgrounded spawns a FRESH engine/isolate
  // (MainActivity is singleTop but sits behind the native shell), wiping the
  // in-memory pending slot. Mirroring the slot to SharedPreferences lets the
  // re-launched isolate's shell-onResume drain still find the link and open it.

  static const String _kPendingUri = 'deeplink_pending_uri';
  static const String _kPendingSource = 'deeplink_pending_source';
  static const String _kPendingTs = 'deeplink_pending_ts';

  /// A parked link older than this on read is stale (parked in a prior session
  /// that never drained) and is discarded rather than opened on a later launch.
  static const Duration _pendingTtl = Duration(minutes: 5);

  /// Parks [uri]/[source] in BOTH the in-memory slot (fast, same-isolate) and
  /// SharedPreferences (survives a re-launch). Best-effort persistence — a
  /// storage failure still leaves the in-memory slot set.
  Future<void> _queuePending(Uri uri, DeeplinkSource source) async {
    GlobalState().pendingDeeplink = (uri: uri, source: source);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingUri, uri.toString());
      await prefs.setString(_kPendingSource, source.name);
      await prefs.setInt(_kPendingTs, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'deeplink_persist_pending_failed',
        {'error': e.toString()},
      );
    }
  }

  Future<void> _clearPersistedPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPendingUri);
      await prefs.remove(_kPendingSource);
      await prefs.remove(_kPendingTs);
    } catch (_) {
      // Best-effort; a stale entry is bounded by [_pendingTtl] anyway.
    }
  }

  Future<({Uri uri, DeeplinkSource source})?> _readPersistedPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Re-read from disk: the link may have been written by a DIFFERENT isolate
      // (the pre-relaunch one), whose write this isolate's cache wouldn't reflect.
      await prefs.reload();
      final uriStr = prefs.getString(_kPendingUri);
      if (uriStr == null) return null;
      final ts = prefs.getInt(_kPendingTs) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - ts >
          _pendingTtl.inMilliseconds) {
        await _clearPersistedPending();
        return null;
      }
      final uri = Uri.tryParse(uriStr);
      if (uri == null) {
        await _clearPersistedPending();
        return null;
      }
      final sourceName = prefs.getString(_kPendingSource);
      final source = DeeplinkSource.values.firstWhere(
        (s) => s.name == sourceName,
        orElse: () => DeeplinkSource.notification,
      );
      return (uri: uri, source: source);
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'deeplink_read_persisted_pending_failed',
        {'error': e.toString()},
      );
      return null;
    }
  }

  /// Force-update gate hook: when [RegistrationNavigation]'s KMP-handoff gate
  /// keeps a runner on Flutter, the KMP shell never opens, so its onResume drain
  /// (and the online opener's `finally` drain) never runs — a link queued for this
  /// session would otherwise vanish with no signal. If one is pending, emit a
  /// `_track` breadcrumb (`dropped_force_update_block`) AND consume it (both slots)
  /// so the drop is counted exactly once and a stale link can't later mis-drain: a
  /// force-blocked runner must update (→ app restart) before any KMP surface exists
  /// to honor it. Clearing matters because the gate is re-entrant — without it, a
  /// refresh / re-login / repeat cold-start would re-read and re-log the same link.
  Future<void> reportPendingDroppedByForceUpdate() async {
    // Read the SAME way [drainPending] does — in-memory first, then persisted — so
    // a link that's only in the in-memory slot (persist failed, or the persisted
    // copy TTL-expired while the in-memory slot still holds it) isn't missed.
    final pending =
        GlobalState().pendingDeeplink ?? await _readPersistedPending();
    if (pending == null) return;
    _track(pending.uri, pending.source, DeepLinkResult.notHandled,
        'dropped_force_update_block');
    GlobalState().pendingDeeplink = null;
    await _clearPersistedPending();
  }

  Future<DeepLinkResult> _dispatch(
    Uri uri, {
    required DeeplinkSource source,
    required bool allowQueue,
  }) async {
    // Kill switch: behave as if the feature doesn't exist so the caller falls
    // back to the legacy notification-type switch.
    if (!_enabled) return DeepLinkResult.notHandled;

    // OneLink URL delivered directly (e.g. CleverTap `wzrk_dl`). AppsFlyer's
    // UDL SDK only resolves on OS-level taps; a push tap hands us the raw
    // short URL, so pull `deep_link_value` from the query ourselves — same
    // mapping the UDL stream path uses.
    // ponytail: hardcoded `onelink.me` host; widen to an RC allowlist if we
    // ever custom-brand the OneLink domain.
    if (uri.host.endsWith('onelink.me')) {
      final resolved = mapOneLinkParams(uri.queryParameters);
      if (resolved == null) return DeepLinkResult.notHandled;
      uri = resolved;
    }

    // Path is derived AFTER OneLink resolution so it reflects the resolved uri.
    final path = _normalisePath(uri.path);

    final context = GlobalState().navigatorKey.currentContext;
    // `mounted` guards the BuildContext across the deeplink-resolution await below.
    final user = context != null && context.mounted ? _userOf(context) : null;

    // Native (migrated) screens take precedence — but ONLY for an ACTIVE runner, so a
    // logged-out / onboarding-incomplete user is never dropped straight onto a native
    // job/shift surface (auth gate). If not routable yet (user == null), we fall through
    // to the queue/park logic below and the native link resolves on the PartnerHome drain
    // once the runner is active. No native paths exist yet, so this returns false today
    // and the legacy routing below runs unchanged; as a screen migrates, its value
    // registers on the KMP side and starts resolving here.
    if (user != null &&
        await bridge.handleResolvedDeeplink(path, uri.queryParameters)) {
      _track(uri, source, DeepLinkResult.handled, 'navigated_native');
      return DeepLinkResult.handled;
    }

    // Not routable yet (cold start / logged out / navigator gone). Park for the
    // PartnerHome drain — unless this already IS a drain, in which case drop it. This
    // also re-guards `context` after the native await above (the navigator could be gone).
    if (context == null || !context.mounted || user == null) {
      if (allowQueue) {
        await _queuePending(uri, source);
        _track(uri, source, DeepLinkResult.queued, 'queued_not_routable');
        return DeepLinkResult.queued;
      }
      _track(uri, source, DeepLinkResult.notHandled, 'dropped_not_routable');
      return DeepLinkResult.notHandled;
    }

    // Cohort hold: for an MQTT-cohort runner the native shell is the home surface. Only
    // open a deeplink once the shell is the RESUMED foreground surface, so the linked
    // screen lands ON TOP of it. During cold start (shell still launching) or a OneLink
    // re-launch, the shell comes up AFTER the deeplink and would otherwise cover it — so
    // hold the link and let the shell's onResume drain it (drainDeeplinks → drainPending).
    // Non-cohort runners (mqttConfig == null) skip this entirely — unchanged Flutter flow.
    if (user.mqttConfig != null) {
      final shellForeground = await bridge.isRootShellForeground();
      if (!context.mounted) return DeepLinkResult.notHandled;
      if (!shellForeground) {
        if (allowQueue) {
          await _queuePending(uri, source);
          _track(uri, source, DeepLinkResult.queued,
              'queued_cohort_shell_not_foreground');
          return DeepLinkResult.queued;
        }
        // A drain (allowQueue == false) while the shell still isn't foreground is the
        // fail-open path (shell never launched) — fall through to the Flutter handler so
        // the link opens on the Flutter surface the runner is actually on.
      }
    }

    final handler = _routes[path];
    if (handler == null) {
      _goHome(context);
      _track(uri, source, DeepLinkResult.handled, 'home_fallback_unknown_path');
      return DeepLinkResult.handled;
    }

    await handler(context);
    _track(uri, source, DeepLinkResult.handled, 'navigated');
    return DeepLinkResult.handled;
  }

  /// Maps the raw AppsFlyer UDL param map to a path-only deeplink [Uri].
  /// v1 consumes only `deep_link_value`; `deep_link_sub1..N` are reserved for a
  /// future query-param extension. Returns null when no usable value exists.
  Uri? mapOneLinkParams(Map<String, dynamic> raw) {
    final value = raw['deep_link_value'];
    if (value is! String || value.trim().isEmpty) {
      MonitoringServiceHelper.logWarning(
        'deeplink_onelink_no_value',
        {'keys': raw.keys.toList().toString()},
      );
      return null;
    }
    final path = _normalisePath(value);
    return Uri.parse('snabbitrunner:///$path');
  }

  // --- handlers / helpers ---------------------------------------------------

  String _normalisePath(String path) {
    var p = path.trim();
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  UserProfile? _userOf(BuildContext context) {
    try {
      return Provider.of<UserProfileProvider>(context, listen: false).user;
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'deeplink_user_provider_unavailable',
        {'error': e.toString()},
      );
      return null;
    }
  }

  /// Pushes [routeName]. If a native root-shell host is live (MQTT-cohort shell in
  /// front), routes it through the keep-host handoff so it's visible and back returns
  /// to the shell; otherwise a plain Flutter push (unchanged for non-cohort runners).
  Future<void> _push(BuildContext context, String routeName) async {
    if (await bridge.openDeeplinkViaHost(routeName)) return;
    if (!context.mounted) return;
    Navigator.of(context).pushNamed(routeName);
  }

  /// Navigate to Home. Deeplinks drain at PartnerHome, so the common fallback
  /// case is "already home" → no-op; otherwise reset the stack to Home.
  ///
  /// Reads `NavObserver.currentRoute` (kept current by the observer registered
  /// on `MaterialApp.navigatorObservers`) rather than `ModalRoute.of` on the
  /// root navigator's context — the latter walks up the widget tree looking
  /// for a `_ModalScopeStatus`, which only exists *below* the Navigator, so
  /// from the root context it always returns null and the guard never fires.
  void _goHome(BuildContext context) {
    if (NavObserver.currentRoute?.settings.name == PartnerHome.routeName) {
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil(PartnerHome.routeName, (route) => false);
  }

  Future<void> _openMonthlyEarnings(BuildContext context) async {
    // Webview-vs-native fork is derived from runner state, never the deeplink.
    if (_userOf(context)?.isRateCardV2Effective == true) {
      await _openWebviewPath(
          context, WebviewRoutes.payoutsMonthlySummary, 'Earnings');
    } else {
      await _push(context, PayoutHome.routeName);
    }
  }

  /// `referral-home` — mirrors the KMP shell's Profile menu
  /// (`ProfileRouteDecider.referAndEarn`) and the Flutter drawer: gated by the same
  /// RC flag (`expert_is_referrals_v2_enabled`, default off), v2 opens the referrals
  /// **webview** (`v1/referrals/home`, `entry_point=deeplink` attribution, title
  /// "Refer & earn"); v1 opens the native Flutter `ReferralsHome`. Both push
  /// mechanisms are host-aware ([_openWebview]/[_push]) so the screen is visible and
  /// back returns to the shell for cohort runners. The previous handler always pushed
  /// v1 `ReferralsHome`, ignoring the flag — that was the bug.
  Future<void> _openReferral(BuildContext context) async {
    final referralsV2 = RemoteConfigService.instance
        .getBool(RemoteConfigKeys.isReferralsV2Enabled, defaultValue: false);
    if (referralsV2) {
      await _openWebview(
        context,
        buildWebviewUrl(WebviewRoutes.referralsHome,
            query: const {'entry_point': 'deeplink'}),
        'Refer & earn',
        fetchLocation: false,
      );
      return;
    }
    await _push(context, ReferralsHome.routeName);
  }

  Future<void> _openWebviewPath(
      BuildContext context, String path, String title) async {
    await _openWebview(context, buildWebviewUrl(path), title,
        fetchLocation: false);
  }

  /// Seva/Merch open a user-profile-owned URL (never carried in the deeplink).
  /// Empty URL → Home fallback.
  Future<void> _openProfileWebview(
    BuildContext context,
    String? url,
    String title,
    String pathLabel,
  ) async {
    if (url == null || url.isEmpty) {
      _goHome(context);
      MonitoringServiceHelper.logWarning(
        'deeplink_home_fallback_empty_url',
        {'path': pathLabel},
      );
      return;
    }
    await _openWebview(context, url, title, fetchLocation: true);
  }

  /// Opens the webview via the shared [WebViewLauncher] (same https-only rule
  /// the drawer uses). An invalid / non-https URL falls back to Home instead of
  /// opening a blank/insecure page.
  Future<void> _openWebview(
    BuildContext context,
    String url,
    String title, {
    required bool fetchLocation,
  }) async {
    if (!WebViewLauncher.isOpenableHttps(url)) {
      _goHome(context);
      MonitoringServiceHelper.logWarning(
        'deeplink_home_fallback_invalid_url',
        {'url': url},
      );
      return;
    }
    // Native root-shell host in front → open the webview as a host-backed route
    // (via /app-web-view, whose page accepts this string-map arg shape) so it's
    // visible and back returns to the shell. Otherwise a plain Flutter push.
    final handled = await bridge.openDeeplinkViaHost(AppWebViewPage.routeName, {
      'url': url,
      'title': title,
      'fetchLocation': fetchLocation ? 'true' : 'false',
    });
    if (handled) return;
    if (!context.mounted) return;
    WebViewLauncher.open(
      context,
      url: url,
      title: title,
      fetchLocation: fetchLocation,
    );
  }

  Future<void> _openLoan(BuildContext context) async {
    try {
      // Loan is migrated to the native Profile-tab loan sheet. For an MQTT-cohort runner the
      // shell is the foreground surface: ask it to switch to Profile and open the native sheet
      // (it stays on the shell — no keep-host handoff). Non-cohort runners (no native shell)
      // fall through to the Flutter loan sheet — unchanged behaviour.
      if (await bridge.showLoanInShell()) return;
      if (!context.mounted) return;
      final loanProvider = Provider.of<LoanProvider>(context, listen: false);
      await LoanService.handleLoanAction(context, loanProvider, 'deeplink');
    } catch (e) {
      MonitoringServiceHelper.logError(
        'DEEPLINK_LOAN_FAILED',
        {'error': e.toString()},
      );
      if (context.mounted) _goHome(context);
    }
  }

  /// `language-home` — opens the migrated **native** Language screen, matching what
  /// the KMP shell's Profile menu does (`nav.navigate(LanguageDestination(...))`).
  /// Via the bridge's `openNativeDestination('language', …)`: for a cohort runner the
  /// cohort-hold gate has already brought the shell to the foreground, so the native
  /// Language screen renders ON TOP of the shell (back → shell); for a non-cohort
  /// runner it opens as a standalone native host. Falls back to the Flutter
  /// `LanguageHome` (host-aware) only if the native open fails (e.g. KMP not ready).
  Future<void> _openLanguage(BuildContext context) async {
    final currentLanguage = _userOf(context)?.languagePreference;
    final opened = await bridge.openNativeDestination(
      'language',
      {if (currentLanguage != null) 'currentLanguage': currentLanguage},
    );
    if (opened) return;
    if (!context.mounted) return;
    await _push(context, LanguageHome.routeName);
  }

  void _track(
    Uri uri,
    DeeplinkSource source,
    DeepLinkResult result,
    String reason,
  ) {
    // ClevertapSetup.logEvent is self-guarding; no extra try/catch needed.
    ClevertapSetup.logEvent(TrackingEvents.deeplinkOpened, {
      'path': _normalisePath(uri.path),
      'source': source.analyticsName,
      'result': result.name,
      'reason': reason,
    });
  }
}
