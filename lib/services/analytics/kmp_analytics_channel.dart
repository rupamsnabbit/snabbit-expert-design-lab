import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Dart facade for the KMP analytics module.
///
/// Per-method calls go over `com.snabbit.runner/analytics` (MethodChannel).
/// No EventChannels in v1 — there's no conversion-data / deep-link surface
/// to push back to Dart. See `docs/KMP_ANALYTICS_MODULE_LLD.md` §11, §12.
///
/// **Routing lives in KMP.** Every `track` crosses the MethodChannel; the
/// KMP-side `AnalyticsRouteTable` decides which providers receive it.
/// `identify`, `reset`, and `setUserProperty` are unrouted — they fan to
/// every registered provider (identity/profile is not routed).
///
/// All methods are best-effort: KMP-side `runCatching` wrapping means the
/// invocation will always complete, and any failure inside the channel is
/// swallowed with a debug-only log so a misconfigured analytics layer
/// cannot crash the caller. Mirror of the KMP failure-isolation rule
/// (§10).
class KmpAnalyticsChannel {
  KmpAnalyticsChannel._();
  static final instance = KmpAnalyticsChannel._();

  static const _method = MethodChannel('com.snabbit.runner/analytics');

  /// Dart-side super-property store. Merged into every [track] payload
  /// before the MethodChannel hop, so the props reach every provider the
  /// route table fans the event out to — not just Mixpanel. Call-site
  /// props win on conflict. Lives here (not in [MixpanelSetup]) because
  /// every facade — vendor-named or not — routes through `track`.
  static final Map<String, Object?> _superProps = {};

  /// Fire an event. Every event crosses; the KMP route table decides which
  /// providers receive it. Registered super-properties are merged in first;
  /// call-site props override on key conflict.
  Future<void> track({
    required String name,
    Map<String, Object?> props = const {},
    List<String>? targets,
  }) {
    final merged = <String, Object?>{..._superProps, ...props};
    return _method.invokeMethod<void>('track', {
      'name': name,
      'props': merged,
      if (targets != null) 'targets': targets,
    }).catchError((e) => _logFailure('track', e));
  }

  /// Register cross-event super-properties. Later calls win on conflict.
  ///
  /// Kept in the Dart store (merged into [track] for Dart-origin events) AND
  /// forwarded across the channel to the KMP tracker's own store, so
  /// KMP/CMP-originated events — which never pass through the Dart merge —
  /// also pick them up. Best-effort: the channel hop is fire-and-forget.
  ///
  /// Forwards the **full accumulated store**, not just this call's delta, so
  /// the hop is self-correcting: a single dropped channel call is repaired by
  /// the next register (the KMP store re-converges) instead of drifting
  /// permanently missing a key.
  void registerSuperProperties(Map<String, Object?> props) {
    _superProps.addAll(props);
    _method.invokeMethod<void>('registerSuperProperties', {
      'props': Map<String, Object?>.from(_superProps),
    }).catchError((e) => _logFailure('registerSuperProperties', e));
  }

  /// Drop all super-properties on both sides (Dart store + KMP tracker). Call
  /// on forced logout (403) so one user's props can't ride onto the next
  /// session's events.
  Future<void> clearSuperProperties() {
    _superProps.clear();
    return _method
        .invokeMethod<void>('clearSuperProperties')
        .catchError((e) => _logFailure('clearSuperProperties', e));
  }

  /// Test-only: clear the super-property store between tests.
  static void resetSuperPropsForTest() => _superProps.clear();

  /// CleverTap push (custom rendering): tell CleverTap a push was tapped and
  /// register the FCM token. The app draws the notification itself. The
  /// "viewed" impression is fired natively by SnabbitPushService — Dart
  /// background isolate has no MethodChannel, so we don't try.
  Future<void> ctPushClicked(Map<String, Object?> data) =>
      _method.invokeMethod<void>('ctPushClicked', {'props': data}).catchError(
          (e) => _logFailure('ctPushClicked', e));

  Future<void> registerCleverTapToken(String token) => _method
      .invokeMethod<void>('ctRegisterToken', {'token': token}).catchError(
          (e) => _logFailure('ctRegisterToken', e));

  /// Set/switch the user profile (CleverTap `onUserLogin`). Unrouted.
  Future<void> setCustomer(Map<String, Object?> profile) => _method
          .invokeMethod<void>('onUserLogin', {'profile': profile}).catchError(
        (e) => _logFailure('onUserLogin', e),
      );

  /// Associate the device with a backend user. Null clears identity.
  Future<void> identify({required String? userId}) =>
      _method.invokeMethod<void>('identify', {'userId': userId}).catchError(
        (e) => _logFailure('identify', e),
      );

  /// Clear device-scope identity across all registered KMP providers.
  Future<void> reset() => _method
      .invokeMethod<void>('reset')
      .catchError((e) => _logFailure('reset', e));

  /// Set a persistent user property (Mixpanel `people.set`). Unrouted —
  /// fans to every provider; providers without the concept (AppsFlyer)
  /// no-op.
  Future<void> setUserProperty({
    required String key,
    required Object? value,
  }) =>
      _method.invokeMethod<void>('setUserProperty', {
        'key': key,
        'value': value,
      }).catchError((e) => _logFailure('setUserProperty', e));

  /// Batch variant — one MethodChannel hop, one `people.set(JSONObject)`
  /// on the native SDK. Preferred for profile writes that touch >1 key
  /// (e.g. login) so the channel doesn't serialise N round-trips.
  Future<void> setUserProperties(Map<String, Object?> props) => _method
      .invokeMethod<void>('setUserProperties', {'props': props}).catchError(
          (e) => _logFailure('setUserProperties', e));

  /// Records the *kind* of failure (PlatformException code or runtime
  /// type) but never the exception message — a `PlatformException.toString()`
  /// echoes `details`, which a future plugin change could populate with
  /// the original method args. Those args carry merged event props that
  /// may include PII (phone, name). Defense-in-depth: don't emit them
  /// anywhere.
  ///
  /// `kDebugMode` keeps the debug print for local-dev fast feedback;
  /// `MonitoringServiceHelper.logError` forwards the same sanitized tag
  /// to Coralogix so prod incidents are visible. The monitoring call is
  /// fire-and-forget with `.catchError` — an observability glitch must
  /// not surface as an unhandled async error in the analytics caller,
  /// which explicitly opts into never-throws semantics.
  static void _logFailure(String op, Object e) {
    final tag = e is PlatformException
        ? 'PlatformException(${e.code})'
        : e.runtimeType.toString();
    if (kDebugMode) debugPrint('analytics.$op failed: $tag');
    MonitoringServiceHelper.logError('kmp_analytics_channel_error', {
      'op': op,
      'error': tag,
    }).catchError((_) {});
  }
}
