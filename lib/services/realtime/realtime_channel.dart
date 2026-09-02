import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Dart client for the KMP realtime bridge — the `com.snabbit.runner/realtime`
/// MethodChannel owned natively by `RealtimePlugin` (WS4).
///
/// Mirrors [RunnerStateChannel]: every invoke is best-effort and
/// swallows-and-logs (the *kind* of failure only, never the message — an
/// `mqtt_config` object or a state envelope may carry PII) so a bridge hiccup
/// never disturbs the login or polling paths.
///
/// Cohort/kill-switch gating lives at the call sites (see
/// `RegistrationNavigation.openKMPStackForMqttCohort`), not here — these are
/// thin transport wrappers.
class RealtimeChannel {
  RealtimeChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.snabbit.runner/realtime');

  /// Push the raw `mqtt_config` after a `runners/me`. Returns true iff realtime
  /// is enabled for this runner (config present + `mqtt_kmp_enabled != false`,
  /// decided natively). A null config clears the persisted config (polling
  /// cohort). Callers should `await` this and only [start] when it returns true.
  static Future<bool> pushConfig(Map<String, dynamic>? mqttConfig) async {
    try {
      final enabled = await _channel.invokeMethod<bool>('pushConfig', {
        'mqttConfigJson': mqttConfig == null ? null : jsonEncode(mqttConfig),
      });
      return enabled ?? false;
    } catch (e) {
      _logFailure('pushConfig', e);
      return false;
    }
  }

  /// Start the foreground service on the enrolled path (login / app-open).
  static Future<void> start() => _invoke('start');

  /// Foreground FCM hand-off — re-signal the engine to reconnect/reconcile.
  static Future<void> wake() => _invoke('wake');

  /// Logout teardown — stop the engine + foreground service.
  static Future<void> stop() => _invoke('stop');

  /// Logout — drop the persisted last-known-good config.
  static Future<void> clearConfig() => _invoke('clearConfig');

  /// Push the app-side MQTT kill-switch (`expert_mqtt_enabled`) + the
  /// `current_state` poll cadence (feature #1). Persisted natively (read on the
  /// cold-boot path) and, if the engine is already running, flips it live —
  /// MQTT ⇄ poll-only. Best-effort; a bridge failure never disturbs the caller.
  ///
  /// [connectTimeoutSeconds] (feature #2): if MQTT doesn't connect within this
  /// window of engine start, the engine falls to current_state polling (or, when
  /// offline, an error state).
  ///
  /// [postActionTimeoutSeconds] (feature #4): after a runner action, if no newer
  /// MQTT snapshot lands within this window, the engine fetches current_state
  /// once as a safety net.
  ///
  /// Note: only the on/off flip is applied live. Changes to
  /// [pollIntervalSeconds] / [connectTimeoutSeconds] / [postActionTimeoutSeconds]
  /// are persisted but take effect on the next engine start (a running loop keeps
  /// its cadence).
  static Future<void> setMqttEnabled(
    bool enabled,
    int pollIntervalSeconds,
    int connectTimeoutSeconds,
    int postActionTimeoutSeconds, {
    bool healthAnalyticsEnabled = true,
  }) async {
    try {
      await _channel.invokeMethod<void>('setMqttEnabled', {
        'mqttEnabled': enabled,
        'pollIntervalSeconds': pollIntervalSeconds,
        'connectTimeoutSeconds': connectTimeoutSeconds,
        'postActionTimeoutSeconds': postActionTimeoutSeconds,
        'healthAnalyticsEnabled': healthAnalyticsEnabled,
      });
    } catch (e) {
      _logFailure('setMqttEnabled', e);
    }
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (e) {
      _logFailure(method, e);
    }
  }

  /// Records the failure *kind* only (never the message — defense-in-depth
  /// against PII surfacing via `PlatformException.details`), mirroring
  /// [RunnerStateChannel].
  static void _logFailure(String op, Object e) {
    final tag = e is PlatformException
        ? 'PlatformException(${e.code})'
        : e.runtimeType.toString();
    MonitoringServiceHelper.logError('realtime_channel_error', {
      'op': op,
      'error': tag,
    }).catchError((_) {});
  }
}
