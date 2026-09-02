import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:scout_flutter/scout_flutter.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'base_logs_interface.dart';
import 'monitoring_setup.dart';

/// base14 (Scout) monitoring service — an OpenTelemetry RUM sink that
/// **coexists** with [CoralogixMonitoringService] behind the same
/// [BasicLogsInterface] / [MonitoringSetupInterface] contract, so every
/// `MonitoringServiceHelper.log*` call (including KMP crash reports routed
/// through [KmpCrashReporterBridge]) fans out here automatically.
///
/// Enablement is a Remote Config kill-switch
/// ([RemoteConfigKeys.enableBase14MonitoringV2], default ON): the service is
/// always registered so it receives fan-out calls, but stays fully inert
/// (`_active == false` → every log no-ops) until [initializeService]
/// confirms the flag is on, an endpoint is configured, and
/// `ScoutFlutter.initialize` succeeds. Flipping the RC flag to `false` in
/// Firebase is the kill-switch — no binary push needed. This build reads the
/// **v2** key so older builds (frozen on the legacy
/// [RemoteConfigKeys.enableBase14Monitoring] key) are unaffected.
///
/// Uses the `scout_flutter` 0.1.23 public API (`ScoutFlutter` static class,
/// `ScoutFlutterConfig`) — the version the `^0.1.22` constraint resolves to.
///
/// Config sourcing: the enable kill-switch, endpoint, ingest token and
/// session sample rate are typed Remote Config keys; every other
/// `ScoutFlutterConfig` dial comes from the [RemoteConfigKeys.base14Config]
/// JSON blob (see [_buildConfig]). All are read **once** here at init —
/// changes land on the next cold start, not the running session.
class Base14MonitoringService
    implements MonitoringSetupInterface, BasicLogsInterface {
  static final Base14MonitoringService _instance =
      Base14MonitoringService._internal();

  factory Base14MonitoringService() {
    return _instance;
  }

  Base14MonitoringService._internal();

  /// True only after a successful `ScoutFlutter.initialize`. Guards every log so
  /// a disabled/unconfigured service never touches an uninitialised SDK.
  bool _active = false;

  /// User set before [initializeService] completed. Buffered so the first
  /// session on cold start for an already-logged-in runner still gets
  /// attributed once the SDK finishes initialising, instead of being dropped
  /// by the `_active` guard in [setUserData].
  UserProfile? _pendingUser;

  // Fallback ingest token — Remote Config ([RemoteConfigKeys.base14IngestToken])
  // is the source of truth; this compile-time value is used only when RC is
  // unavailable or the key is unset, so init still works offline/first-launch.
  // Single Scout tenant for prod + non-prod today; prod vs staging is signalled
  // by `serviceName` / `environment` labels, not by different tokens.
  // Publishable client-side RUM ingest key (aud: scout-rum-ingest), same shape
  // as the existing Coralogix `publicKey`. Empty resolved value → no
  // Authorization header.
  static const String _defaultIngestToken =
      'eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJPNnRfT1BVejc5ZHJNeVdfa1NJZE9DQXlaVVBULTFIb1JtWWQ1V1plT2F3In0.eyJleHAiOjIwOTc0NzkwMjUsImlhdCI6MTc4MjExOTAyNSwianRpIjoidHJsdGNjOjgwOGFhNzM0LTliMTctNzAxMC1hMjNkLTY5NDE5ODg5YWUwOCIsImlzcyI6Imh0dHBzOi8vaWQuYmFzZTE0LmlvL3JlYWxtcy9zbmFiYml0IiwiYXVkIjoic2NvdXQtcnVtLWluZ2VzdCIsInN1YiI6IjA2MmZlMjI3LTM0NWMtNDRmMi1iZmQ3LTBkYmZmMmNlZmIzOSIsInR5cCI6IkJlYXJlciIsImF6cCI6InNuYWJiaXQtcnVtLWFnZW50Iiwic2NvcGUiOiJlbWFpbCBvZmZsaW5lX2FjY2VzcyBwcm9maWxlIn0.VdBDMMzhMRRm0teahyDozsFiwMjpQ6OhERwSf7Ve7jIGOB-50wTMegL5Wc_nDD5pyzXphMG6KZ0GdS2bk7rsFX1lqdS1dv9pFtXjrjRFjGTLxrLLqCIz_wF5ECanMCNjTsCC5HYHVvH0rmaw8TbcUjJOKCmpNczZqzo28EYzTwWaqzR34VCihOZM37fn378Igq5e9XGhqNn_Zx0CjrU4CtHBuRczRLQ5Sdht5fhajdVztYW61rCkoxD4HoLzIAxmIEaim6IKR-8FE8UbOSiVwAUZwvg99GWbhWo4UPHAEhAgutGD_41ds44ef_dcGIokcZ5IW9cVOWbHdOo9fkYReA';

  @override
  Future<void> initializeService() async {
    // Idempotent — never double-init the SDK if this is ever called twice
    // (retry, future refactor). A second call after a successful init no-ops.
    if (_active) return;
    try {
      final rc = RemoteConfigService.instance;
      // Version-scoped kill-switch: this build (and later) read the v2 key so
      // enabling/tuning Base14 here never flips it on for older builds, which
      // are frozen on the legacy `expert_enable_base14_monitoring` key.
      final enabled = rc.getBool(
        RemoteConfigKeys.enableBase14MonitoringV2,
        defaultValue: true,
      );
      if (!enabled) {
        if (kDebugMode) {
          print('Base14 (Scout) disabled via Remote Config — skipping init');
        }
        return;
      }

      // Session sampling — RC-controllable so we can dial volume down after
      // rollout without a code push. Defaults to 100% while we're bootstrapping
      // the pipeline (Scout's own default is 1%, which is why the app didn't
      // appear in Applications on first attempt). Kept as its own typed key
      // rather than folded into the JSON blob for backward compatibility.
      final sampleRate = rc.getDouble(
        RemoteConfigKeys.base14SessionSampleRate,
        defaultValue: 100.0,
      );

      // serviceVersion is resolved here (async) and passed into the otherwise
      // synchronous config builder.
      final serviceVersion = await GlobalState().currentVersionCode();

      await ScoutFlutter.initialize(
        config: _buildConfig(rc, sampleRate, serviceVersion),
      );
      _active = true;
      if (kDebugMode) {
        print('Base14 (Scout) SDK initialized successfully');
      }
      // Flush a user set before init completed (already-logged-in cold start).
      final pending = _pendingUser;
      if (pending != null) {
        _pendingUser = null;
        await setUserData(pending);
      }
    } catch (e, st) {
      _active = false;
      if (kDebugMode) {
        print('Base14 (Scout) SDK initialization failed : $e');
      }
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Base14 (Scout) SDK initialization failed',
        fatal: false,
      );
    }
  }

  /// Reads Base14 config from Remote Config and builds the
  /// [ScoutFlutterConfig]. Identity (endpoint, ingest token) comes from typed
  /// RC keys with compile-time fallbacks; [sampleRate] and [serviceVersion]
  /// are resolved by the caller; every other dial comes from the
  /// [RemoteConfigKeys.base14Config] JSON blob. The field mapping itself lives
  /// in the pure [buildScoutConfig] so it is unit-testable without Firebase or
  /// Remote Config.
  ScoutFlutterConfig _buildConfig(
    RemoteConfigService rc,
    double sampleRate,
    String? serviceVersion,
  ) {
    // Debug builds always tag as staging even if pointed at prodEnv, so
    // local/dev/QA traffic never pollutes the prod service. Mirrors
    // CoralogixMonitoringService's environment tagging.
    final isProd = !kDebugMode && GlobalState().currentEnv == prodEnv;

    // Behavioural dials — one JSON blob, parsed defensively (see
    // [parseConfigBlob]): malformed JSON or a non-object payload → empty map →
    // every field falls back to its current default.
    final blob = parseConfigBlob(rc.getString(RemoteConfigKeys.base14Config));

    return buildScoutConfig(
      blob: blob,
      endpoint: rc.getString(
        RemoteConfigKeys.base14Endpoint,
        defaultValue: base14Endpoint,
      ),
      ingestToken: rc.getString(
        RemoteConfigKeys.base14IngestToken,
        defaultValue: _defaultIngestToken,
      ),
      sampleRate: sampleRate,
      serviceVersion: serviceVersion,
      isProd: isProd,
      debugLogging: kDebugMode,
    );
  }

  /// Decodes the raw [RemoteConfigKeys.base14Config] value into a map.
  /// Returns an empty map when the value is empty, malformed JSON, or a valid
  /// JSON value that isn't an object (array/number/etc.) — so a bad RC value
  /// can never hard-fail init; the caller just falls back to defaults.
  ///
  /// Pure and side-effect-free (surfaced only in debug), so it's unit-testable
  /// without Firebase / Remote Config.
  @visibleForTesting
  static Map<String, dynamic> parseConfigBlob(String raw) {
    if (raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      // Malformed JSON → fall back to defaults. Handled (not swallowed): a bad
      // RC blob must degrade gracefully, never hard-fail init. Surfaced in
      // debug builds only.
      if (kDebugMode) {
        print('Base14 (Scout) RC config parse failed: $e');
      }
    }
    return const {};
  }

  /// Pure builder — maps an already-parsed (possibly empty) Remote Config
  /// [blob] plus the resolved identity/transport values onto a
  /// [ScoutFlutterConfig]. No Firebase / RC / singleton access, so it is fully
  /// unit-testable. Every blob field is coerced defensively: a missing or
  /// wrong-typed value falls back to the current default.
  @visibleForTesting
  static ScoutFlutterConfig buildScoutConfig({
    required Map<String, dynamic> blob,
    required String endpoint,
    required String ingestToken,
    required double sampleRate,
    required String? serviceVersion,
    required bool isProd,
    required bool debugLogging,
  }) {
    // Identity — code-derived defaults; the blob may override, but the default
    // keeps prod/staging tagging honest when the key is absent.
    final serviceName = _str(blob['serviceName']) ??
        (isProd ? 'prod-expert-android' : 'staging-expert-android');
    final environmentTag =
        _str(blob['environment']) ?? (isProd ? 'production' : 'staging');

    return ScoutFlutterConfig(
      serviceName: serviceName,
      environment: environmentTag,
      endpoint: endpoint,
      serviceVersion: serviceVersion,
      headers:
          ingestToken.isEmpty ? null : {'Authorization': 'Bearer $ingestToken'},
      resourceAttributes: {'app': serviceName},
      // W3C traceparent injection so mobile RUM sessions stitch onto the
      // matching backend spans in Scout. Kept as suffix matches (SDK does
      // endsWith), covering every env's snabbit + maestroserve API.
      firstPartyHosts: _hosts(blob['firstPartyHosts']) ??
          const ['snabbit.com', 'maestroserve.com'],
      // Surface init/session/export lines in debug builds so we can tell
      // whether OTLP POSTs are landing or silently failing.
      debugLogging: debugLogging,
      // RC-controlled sample rate (scale 0-100, SDK clamps). See
      // RemoteConfigKeys.base14SessionSampleRate for the rollout lever.
      sessionSampleRate: sampleRate,

      // These three default to false so RC-absent behaviour == today:
      //  • enablePerformanceMetrics — master switch for frame/memory/CPU/vitals
      //    (all the high-volume metrics); off keeps ingest volume/cost down.
      //  • enableErrorTracking — do NOT let Scout wrap FlutterError.onError /
      //    PlatformDispatcher.onError; those single-slot globals are owned by
      //    our Crashlytics handler in main.dart, and our onError already fans
      //    out to Scout via MonitoringServiceHelper. Auto-wrapping is redundant
      //    and its ordering is fragile.
      //  • alwaysCaptureErrors — keeps sessionSampleRate the honest cost lever;
      //    true would let every error-level log bypass the dial (~1M/day fleet).
      //    Crashes stay authoritative in Crashlytics regardless.
      enablePerformanceMetrics:
          _asBool(blob['enablePerformanceMetrics'], false),
      enableErrorTracking: _asBool(blob['enableErrorTracking'], false),
      alwaysCaptureErrors: _asBool(blob['alwaysCaptureErrors'], false),

      // Metrics (dead unless enablePerformanceMetrics is also on, and gated by
      // the master switch above). Defaulted to the scout_flutter 0.1.23 SDK
      // defaults (all false) so flipping enablePerformanceMetrics:true via the
      // blob does NOT silently also turn memory/CPU on — those must be opted
      // into explicitly.
      enableFrameMetrics: _asBool(blob['enableFrameMetrics'], false),
      enableMemoryMetrics: _asBool(blob['enableMemoryMetrics'], false),
      enableCpuMetrics: _asBool(blob['enableCpuMetrics'], false),
      metricExportIntervalSeconds:
          anyValueToInt(blob['metricExportIntervalSeconds']) ?? 60,
      vitalsCollectionIntervalSeconds:
          anyValueToInt(blob['vitalsCollectionIntervalSeconds']) ?? 60,

      // Auto-instrumentation toggles (SDK defaults true).
      enableAutoTapTracking: _asBool(blob['enableAutoTapTracking'], true),
      enableLifecycleTracking: _asBool(blob['enableLifecycleTracking'], true),
      enableStartupTracking: _asBool(blob['enableStartupTracking'], true),
      enableConnectivityTracking:
          _asBool(blob['enableConnectivityTracking'], true),
      enableNetworkTracking: _asBool(blob['enableNetworkTracking'], true),
      enableLogging: _asBool(blob['enableLogging'], true),
      enableAnrDetection: _asBool(blob['enableAnrDetection'], true),
      enableLongTaskDetection: _asBool(blob['enableLongTaskDetection'], true),
      capturePrintStatements: _asBool(blob['capturePrintStatements'], false),

      // Thresholds / sessions (SDK defaults).
      longTaskThresholdMs: anyValueToInt(blob['longTaskThresholdMs']) ?? 100,
      anrThresholdMs: anyValueToInt(blob['anrThresholdMs']) ?? 5000,
      iosHangThresholdMs: anyValueToInt(blob['iosHangThresholdMs']) ?? 250,
      maxTombstoneBytes: anyValueToInt(blob['maxTombstoneBytes']) ?? 131072,
      sessionTimeoutMinutes: anyValueToInt(blob['sessionTimeoutMinutes']) ?? 30,
      maxSessionDurationMinutes:
          anyValueToInt(blob['maxSessionDurationMinutes']) ?? 60,

      // Offline buffer — failed batches persist to disk and replay on
      // reconnect. Deliberately PINNED to the pre-0.1.23 behaviour (enabled,
      // 5000/2000/5000 caps): scout_flutter 0.1.23 flipped its own defaults to
      // off / 0, so these are a version-pin to preserve what the app shipped
      // before this PR, NOT a mirror of the current SDK defaults. Don't
      // "simplify" them away as redundant — that would silently disable the
      // offline buffer.
      offlineBufferEnabled: _asBool(blob['offlineBufferEnabled'], true),
      offlineMaxTraceItems: anyValueToInt(blob['offlineMaxTraceItems']) ?? 5000,
      offlineMaxMetricItems:
          anyValueToInt(blob['offlineMaxMetricItems']) ?? 2000,
      offlineMaxLogItems: anyValueToInt(blob['offlineMaxLogItems']) ?? 5000,
      maxOfflineStorageMb: anyValueToInt(blob['maxOfflineStorageMb']) ?? 5,
    );
  }

  /// Coerces a Remote Config JSON value to bool. Accepts real bools,
  /// `1`/`0`, and `"true"`/`"1"` (case-insensitive); anything else (wrong
  /// type, null, garbage) returns [def]. Never throws — a bad field can't
  /// break the whole config parse.
  static bool _asBool(dynamic v, bool def) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      // Unrecognised string (typo/garbage) → safe default, not a silent false.
      return def;
    }
    return def;
  }

  /// Non-empty String or null — used for optional blob string overrides.
  static String? _str(dynamic v) => (v is String && v.isNotEmpty) ? v : null;

  /// A JSON list of hosts → `List<String>`, or null to fall back to the
  /// default. Non-list or empty payloads return null.
  static List<String>? _hosts(dynamic v) =>
      (v is List && v.isNotEmpty) ? v.map((e) => e.toString()).toList() : null;

  @override
  Future<void> setUserData(UserProfile user) async {
    if (!_active) {
      _pendingUser = user;
      return;
    }
    try {
      ScoutFlutter.setUser(
        id: user.id.toString(),
        attributes: _attrs({
          'name': user.name ?? '',
          'phone': user.phoneNumber,
          'country_code': user.countryCode,
          'gender': user.gender?.value?.name ?? '',
          'status': user.runnerStatus?.name ?? '',
          'language': user.languagePreference ?? '',
          'tier': user.tier?.name ?? '',
          'service_id': user.service?.id.toString() ?? '',
          'cluster_id': user.clusterId?.toString() ?? '',
          'region_id': user.regionId?.toString() ?? '',
        }),
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('Error updating Base14 user context: $e');
      }
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Base14 (Scout) setUser failed',
        fatal: false,
      );
    }
  }

  @override
  Future<void> logDebug(String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      ScoutFlutter.logDebug(message, attributes: _attrs(data));
    } catch (e) {
      _logFailure('debug', message, e);
    }
  }

  @override
  Future<void> logInfo(String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      ScoutFlutter.logInfo(message, attributes: _attrs(data));
    } catch (e) {
      _logFailure('info', message, e);
    }
  }

  @override
  Future<void> logWarning(String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      ScoutFlutter.logWarning(message, attributes: _attrs(data));
    } catch (e) {
      _logFailure('warning', message, e);
    }
  }

  @override
  Future<void> logError(String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      ScoutFlutter.logError(message, attributes: _attrs(data));
    } catch (e) {
      _logFailure('error', message, e);
    }
  }

  @override
  Future<void> logCriticalError(
      String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      // reportError already fans out to Scout as one logError + one
      // reportError, so we don't emit a separate logError up top (would send
      // the same critical to Scout three times). Also mirror to Crashlytics —
      // critical is our loudest severity and Firebase has the best alerting.
      await reportError(message, data, StackTrace.current.toString());
      FirebaseCrashlytics.instance.recordError(
        Exception(message),
        StackTrace.current,
        reason: 'critical: $message',
        information: [data.toString()],
        fatal: false,
      );
    } catch (e) {
      _logFailure('critical', message, e);
    }
  }

  @override
  Future<dynamic> reportError(
      String message, Map<String, dynamic>? data, String? stackTrace) async {
    if (!_active) return;
    try {
      // ScoutFlutter.reportError carries no attribute bag, so emit an error log
      // first to preserve the structured `data` (op/source/meta — including
      // KMP crash payloads) as queryable OTel attributes.
      ScoutFlutter.logError(message, attributes: _attrs(data));
      // Wrap in Exception so Scout attributes error.type as the exception class
      // (`_Exception`) instead of `String`, matching how the rest of the app
      // reports errors and keeping Scout's error fingerprinting useful.
      ScoutFlutter.reportError(
        Exception(message),
        (stackTrace != null && stackTrace.isNotEmpty)
            ? StackTrace.fromString(stackTrace)
            : null,
      );
    } catch (e) {
      _logFailure('reportError', message, e);
    }
  }

  /// Converts the interface's `Map<String, dynamic>` payload into the
  /// non-nullable `Map<String, Object>` Scout attributes expect. Nulls are
  /// dropped (KMP `meta` can contain them); non-primitive values are
  /// stringified so Scout's internal jsonEncode doesn't blow up and silently
  /// drop the whole log entry (e.g. an ApiResponse passed as an attribute).
  /// Long strings are truncated at [_maxAttrChars] so a stray big object
  /// doesn't balloon a single attribute into multi-KB of RUM payload.
  Map<String, Object> _attrs(Map<String, dynamic>? data) {
    final result = <String, Object>{};
    if (data == null) return result;
    data.forEach((key, value) {
      if (value == null) return;
      if (value is num || value is bool) {
        result[key] = value as Object;
        return;
      }
      final s = value is String ? value : value.toString();
      result[key] =
          s.length > _maxAttrChars ? '${s.substring(0, _maxAttrChars)}…' : s;
    });
    return result;
  }

  static const int _maxAttrChars = 500;

  void _logFailure(String level, String message, Object e) {
    if (kDebugMode) {
      print('Error sending $level log "$message" to Base14 because of: $e');
    }
  }
}
