import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Bidirectional bridge for the runner profile (`runners/me`) + period-leave. Mirrors
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/ProfileSyncPlugin.kt` and
/// lands in the KMP `RunnerProfileStore` / `PeriodLeaveStore` that the Compose
/// Multiplatform Profile + Earnings/Refer surfaces read.
///
/// While the app is still mostly Flutter, Dart owns the single `runners/me` (and
/// `period_leave/availability`) fetch and pushes the result — KMP does NOT fetch it
/// itself (that would double the API load).
///
///  - Dart → KMP: [pushProfile] mirrors the raw `runners/me` body (KMP decodes it);
///    [pushProfileError] surfaces a fetch failure so the native Profile screen shows its
///    error state immediately; [pushPeriodLeave] mirrors the period-leave body.
///  - KMP → Dart: [bindRefreshHandler] installs a handler that Compose fires via
///    `RunnerProfileStore.requestRefresh()` (Profile pull-to-refresh / retry) to ask Dart
///    to re-fetch + re-push now. The handler's completion replies on the channel, which
///    completes the *suspending* KMP request (so the spinner clears when Dart is done).
///
/// Every push is best-effort — a channel failure is swallowed and logged (sanitized: the
/// `runners/me` body carries PII, so only the failure *kind* is recorded, never details),
/// mirroring `RunnerStateChannel`.
class ProfileSyncChannel {
  ProfileSyncChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.snabbit.runner/profile_sync');

  /// Pushes the raw `runners/me` JSON body to KMP. Never throws.
  static Future<void> pushProfile(String json) {
    return _channel.invokeMethod<void>('pushProfile', <String, Object?>{
      'json': json,
    }).catchError((e) => _logFailure('pushProfile', e));
  }

  /// Tells KMP the `runners/me` fetch failed (so it shows the error state, unless it
  /// already has content). [message] is a non-PII code, never the exception detail.
  static Future<void> pushProfileError(String? message) {
    return _channel.invokeMethod<void>('pushProfileError', <String, Object?>{
      'message': message,
    }).catchError((e) => _logFailure('pushProfileError', e));
  }

  /// Pushes the raw `period_leave/availability` JSON body to KMP. Never throws.
  static Future<void> pushPeriodLeave(String json) {
    return _channel.invokeMethod<void>('pushPeriodLeave', <String, Object?>{
      'json': json,
    }).catchError((e) => _logFailure('pushPeriodLeave', e));
  }

  /// Wire the `requestRefresh` handler KMP fires when the Profile tab pulls-to-refresh
  /// (or retries after an error). Call once (e.g. from `RunnerRtDataProvider`). The
  /// handler should re-fetch + re-push; its completion replies success to KMP. A handler
  /// throw is swallowed + logged so a Dart-side bug never breaks the channel.
  static void bindRefreshHandler(Future<void> Function() handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'requestRefresh') {
        try {
          await handler();
        } catch (e) {
          _logFailure('requestRefresh', e);
        }
        return null;
      }
      throw MissingPluginException('No handler for ${call.method}');
    });
  }

  /// Records the *kind* of failure (PlatformException code or runtime type) but never the
  /// exception message — the `runners/me` body carries PII (name, phone, PAN, bank).
  static void _logFailure(String op, Object e) {
    final tag = e is PlatformException
        ? 'PlatformException(${e.code})'
        : e.runtimeType.toString();
    MonitoringServiceHelper.logError('profile_sync_channel_error', {
      'op': op,
      'error': tag,
    }).catchError((_) {});
  }
}
