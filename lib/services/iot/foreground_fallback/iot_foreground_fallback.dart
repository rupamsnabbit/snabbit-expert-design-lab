import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/models/location_data.dart' as iot_models;
import 'package:snabbit_runner/services/database/database_factory.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/iot/config/config_service.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_collector.dart';
import 'package:snabbit_runner/services/iot/sender/sender.dart';

/// Returns the current Flutter app lifecycle state (resumed/paused/...).
typedef LifecycleStateProvider = AppLifecycleState? Function();

/// Returns whether the flutter_background_service isolate is currently alive.
typedef IsBgServiceRunning = Future<bool> Function();

/// Returns the atlas-iot endpoint URL. Injected so tests don't need to
/// construct GlobalState (which eagerly touches platform channels).
typedef IotEndpointProvider = String Function();

/// Foreground IoT fallback: when the background IoT service is dead and the
/// last successful atlas-iot ping is stale, the main isolate piggybacks
/// current_state's poll to insert a fresh location row and drain any unsent
/// IoT rows directly. Targets the ~83% of drift that is bg-service death,
/// scoped to when the app is foregrounded (~80% of dead-drift windows).
///
/// Kill-switched OFF by default; enable via Firebase Remote Config
/// (`iot_fg_fallback_enabled`).
///
/// Threading model: invoked fire-and-forget from `runnerAppCurrentState`
/// (lib/services/runner_http.dart). Reentrancy is suppressed by [_inFlight]
/// because `runnerAppCurrentState` is fired by multiple triggers (60s timer,
/// FCM handler, `fetchDataNow`) and overlapping fallback calls would waste
/// DB + network work.
class IotForegroundFallback {
  /// Reentrancy guard — set true on entry, cleared in finally. Static because
  /// the hook constructs a fresh instance per call.
  static bool _inFlight = false;

  final IDatabaseInterface _db;
  final Sender _sender;
  final IotDiagnosticsCollector _diagnostics;
  final ConfigService _config;
  // Injected as functions (rather than the Flutter / package singletons) so
  // tests can drive lifecycle + bg-service-alive state without a binding
  // or a real platform channel.
  final LifecycleStateProvider _getLifecycleState;
  final IsBgServiceRunning _isBgServiceRunning;
  final IotEndpointProvider _getEndpoint;

  IotForegroundFallback({
    IDatabaseInterface? database,
    Sender? sender,
    IotDiagnosticsCollector? diagnostics,
    ConfigService? config,
    LifecycleStateProvider? getLifecycleState,
    IsBgServiceRunning? isBgServiceRunning,
    IotEndpointProvider? getEndpoint,
  })  : _db = database ?? DatabaseFactory.getInstance(),
        _sender = sender ?? Sender(),
        _diagnostics = diagnostics ?? IotDiagnosticsCollector(),
        _config = config ?? ConfigService.instance,
        _getLifecycleState = getLifecycleState ??
            (() => WidgetsBinding.instance.lifecycleState),
        _isBgServiceRunning = isBgServiceRunning ??
            (() => FlutterBackgroundService().isRunning()),
        _getEndpoint = getEndpoint ??
            (() => GlobalState().atlasServerPath('api/v1/iot'));

  /// Clears the reentrancy guard. Tests only — production callers should
  /// never need this because [maybeSend] always clears it in `finally`.
  @visibleForTesting
  static void resetInFlightForTesting() {
    _inFlight = false;
  }

  /// Attempt a fallback IoT ping if all gates pass.
  ///
  /// Gates (short-circuit on first failure):
  ///   1. Empty userId.
  ///   2. Reentrancy.
  ///   3. Config init failure (treated as kill-switch off).
  ///   4. Kill-switch (`fgFallbackEnabled` RC flag).
  ///   5. App not foregrounded.
  ///   6. `iot_last_send_success_ms` younger than the staleness threshold.
  ///   7. Background service reports it is running.
  ///
  /// On pass, inserts [freshPosition] (if non-null) into the IoT DB so it
  /// flushes in the next step, then calls Sender.sendAllData to POST every
  /// unsent row. Atlas-iot dedupes any races with a reviving bg service.
  Future<void> maybeSend(Position? freshPosition, String userId) async {
    if (userId.isEmpty) return;

    if (_inFlight) return;
    _inFlight = true;
    try {
      await _maybeSendInner(freshPosition, userId);
    } catch (e, st) {
      // Contract: maybeSend never rejects. The hook in runnerAppCurrentState
      // calls this fire-and-forget (unawaited), so an escaped throw here would
      // become an unhandled async error. Catch + log instead. Every gate below
      // already guards itself, so reaching this is a "should never happen".
      await _logSkip('unexpected_error', 0, error: e, stack: st);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _maybeSendInner(Position? freshPosition, String userId) async {
    // Config: defensive init so a config-load failure can never turn the
    // fallback ON. Default is OFF.
    try {
      await _config.initialize();
    } catch (e) {
      // Distinguish "feature broken because config keeps failing" from
      // "feature correctly disabled by RC" in analytics.
      await _logSkip('config_init_failed', 0, error: e);
      return;
    }
    if (!_config.fgFallbackEnabled) return;

    // Foreground gate (cheap, in-memory). Silent skip — high call volume
    // would otherwise flood cx_rum with no-op events. Wrapped because the
    // default provider reads WidgetsBinding.instance, which can throw during a
    // binding-teardown race; if we can't determine lifecycle, skip.
    AppLifecycleState? lifecycle;
    try {
      lifecycle = _getLifecycleState();
    } catch (_) {
      return;
    }
    if (lifecycle != AppLifecycleState.resumed) {
      return;
    }

    // Staleness gate: read last-send timestamp; if no IoT history, skip
    // explicitly so analytics can see the fresh-install / never-uploaded
    // case as `no_send_history` rather than a 56-year staleness number.
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      await prefs.reload();
    } catch (e) {
      await _logSkip('prefs_read_failed', 0, error: e);
      return;
    }
    final lastSendMs = prefs.getInt('iot_last_send_success_ms') ?? 0;
    if (lastSendMs == 0) {
      await _logSkip('no_send_history', 0);
      return;
    }
    final stalenessMs = DateTime.now().millisecondsSinceEpoch - lastSendMs;
    final thresholdMs = _config.fgFallbackStalenessThresholdSeconds * 1000;
    if (stalenessMs < thresholdMs) return; // silent — high call volume

    // Bg-service-alive gate. If isRunning throws, default to skip (safer
    // than firing blindly when we can't observe state).
    bool bgRunning;
    try {
      bgRunning = await _isBgServiceRunning();
    } catch (e) {
      await _logSkip('is_running_check_failed', stalenessMs, error: e);
      return;
    }
    if (bgRunning) {
      await _logSkip('bg_alive', stalenessMs);
      return;
    }

    // Insert the fresh fix (if any) inline rather than reusing
    // LocationCollector.collect — keeps bg-collection metrics
    // (IOT_LOCATION_RETRIEVED_SUCCESSFULLY etc.) uncontaminated by fg-path
    // emits.
    bool hadFresh = false;
    if (freshPosition != null) {
      try {
        // Real GPS-fix time, not insert time. The gates (config init,
        // prefs.reload, isRunning platform call) between the fix and here add
        // latency, so DateTime.now() would be seconds late. NB: the bg
        // LocationCollector uses DateTime.now(); this is intentionally more
        // accurate. Position.timestamp is non-nullable.
        final fixMs = freshPosition.timestamp.millisecondsSinceEpoch;
        await _db.insert(
          DatabaseTables.location,
          iot_models.LocationData(
            userId: userId,
            lat: freshPosition.latitude,
            long: freshPosition.longitude,
            accuracy: freshPosition.accuracy,
            alt: freshPosition.altitude,
            altAccuracy: freshPosition.altitudeAccuracy,
            heading: freshPosition.heading,
            headingAccuracy: freshPosition.headingAccuracy,
            speed: freshPosition.speed,
            speedAccuracy: freshPosition.speedAccuracy,
            isMocked: freshPosition.isMocked,
            collectedAt: fixMs,
            // This fg-fallback insert is a single location with no co-collected
            // battery/device-state siblings, so it forms its own singleton
            // group. Stamp it with the fix time (rather than leaving it null) so
            // every row the backend receives carries a non-null
            // collection_cycle_id and its grouping logic stays uniform.
            collectionCycleId: fixMs,
          ).toMap(),
        );
        hadFresh = true;
      } catch (e) {
        // Distinct event (not _logSkip) so IOT_FG_FALLBACK_SKIPPED keeps
        // meaning "the whole operation was skipped" — here we continue to the
        // drain below, so a SKIPPED event would mislead analytics.
        await _logInsertFailed(stalenessMs, e);
        // Fall through and still attempt the drain — there may be older
        // unsent rows in the DB worth flushing even if this insert failed.
      }
    }

    // Drain: Sender.sendAllData reads unsent battery + location +
    // device_state, batches into one POST, and deletes successfully-sent
    // rows. This mirrors exactly what the bg sender does.
    try {
      final endpoint = _getEndpoint();
      final sent = await _sender.sendAllData(userId, endpoint);
      // Only emit when something actually shipped. Sender.sendAllData returns 0
      // without hitting the network when there's nothing unsent — emitting then
      // would create misleading "PING_SENT rows_sent:0" noise every poll while
      // the bg service is dead but there's no backlog. A real send (>0) also
      // stamps iot_last_send_success_ms via IotHttp, advancing staleness so we
      // don't re-fire next cycle.
      if (sent > 0) {
        await _diagnostics.logDiagnostic('IOT_FG_FALLBACK_PING_SENT', {
          'rows_sent': sent,
          'staleness_ms': stalenessMs,
          'had_fresh_position': hadFresh,
          'user_id': userId,
        });
      }
    } catch (e, st) {
      await _logSkip('send_failed', stalenessMs, error: e, stack: st);
    }
  }

  Future<void> _logInsertFailed(int stalenessMs, Object error) async {
    try {
      await _diagnostics.logDiagnostic('IOT_FG_FALLBACK_INSERT_FAILED', {
        'staleness_ms': stalenessMs,
        'continued_to_drain': true,
        'error': error.toString(),
      });
    } catch (_) {
      // Never block the fallback flow on a diagnostic emit failure.
    }
  }

  Future<void> _logSkip(
    String reason,
    int stalenessMs, {
    Object? error,
    StackTrace? stack,
  }) async {
    try {
      await _diagnostics.logDiagnostic('IOT_FG_FALLBACK_SKIPPED', {
        'reason': reason,
        'staleness_ms': stalenessMs,
        if (error != null) 'error': error.toString(),
        if (stack != null) 'stacktrace': stack.toString(),
      });
    } catch (_) {
      // Never block the fallback flow on a diagnostic emit failure.
    }
  }
}
