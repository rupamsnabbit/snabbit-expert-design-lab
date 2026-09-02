import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:safety_shield/safety_shield.dart';

import 'package:snabbit_runner/modules/snabbit_shield/shield_deterrence_audio.dart';
import 'package:snabbit_runner/modules/snabbit_shield/snabbit_shield_provider.dart';
import 'package:snabbit_runner/modules/snabbit_shield/sos_flow_coordinator.dart';
import 'package:snabbit_runner/utils/enums.dart';

@GenerateMocks([SafetyShield, ShieldDeterrenceAudio])
import 'sos_flow_coordinator_test.mocks.dart';

// ── Network isolation ───────────────────────────────────────────────────────
//
// RunnerHttp.runnerSOS() calls HttpService().post() which uses Dio. Dio
// creates its own HttpClient and sets connectTimeout = 60 s on it *after*
// HttpOverrides.createHttpClient returns, bypassing a simple timeout tweak.
// The only reliable way to fail fast is to throw from openUrl itself so
// the exception surfaces as DioExceptionType.unknown, which HttpService's
// catch (e) block handles and re-throws. RunnerHttp's outer catch (e)
// then returns null immediately — allowing the snapshot-logic that follows
// to run in the test.
//
// Platform channel mocks are needed because GlobalState() eagerly creates
// an AudioPlayer (xyz.luan/audioplayers.global), and ChuckerDioInterceptor
// reads SharedPreferences on network error. Both are fire-and-forget awaitables
// whose MissingPluginExceptions would otherwise be reported as test failures.

class _FailFastHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FailFastHttpClient();
}

/// Minimal HttpClient that throws SocketException on every request method.
/// Implements only the members that Dart requires; stubs everything else.
class _FailFastHttpClient implements HttpClient {
  static Future<HttpClientRequest> _fail() =>
      Future.error(const SocketException('Unit tests: no network'));

  @override bool autoUncompress = true;
  @override Duration? connectionTimeout;
  @override Duration idleTimeout = const Duration(seconds: 15);
  @override int? maxConnectionsPerHost;
  @override String? userAgent;

  @override Future<HttpClientRequest> open(String m, String h, int p, String pa) => _fail();
  @override Future<HttpClientRequest> openUrl(String method, Uri url) => _fail();
  @override Future<HttpClientRequest> get(String h, int p, String pa) => _fail();
  @override Future<HttpClientRequest> getUrl(Uri url) => _fail();
  @override Future<HttpClientRequest> post(String h, int p, String pa) => _fail();
  @override Future<HttpClientRequest> postUrl(Uri url) => _fail();
  @override Future<HttpClientRequest> head(String h, int p, String pa) => _fail();
  @override Future<HttpClientRequest> headUrl(Uri url) => _fail();
  @override Future<HttpClientRequest> patch(String h, int p, String pa) => _fail();
  @override Future<HttpClientRequest> patchUrl(Uri url) => _fail();
  @override Future<HttpClientRequest> put(String h, int p, String pa) => _fail();
  @override Future<HttpClientRequest> putUrl(Uri url) => _fail();
  @override Future<HttpClientRequest> delete(String h, int p, String pa) => _fail();
  @override Future<HttpClientRequest> deleteUrl(Uri url) => _fail();

  @override void close({bool force = false}) {}
  @override void addCredentials(Uri u, String r, HttpClientCredentials c) {}
  @override void addProxyCredentials(String h, int p, String r, HttpClientCredentials c) {}
  @override set authenticate(Future<bool> Function(Uri, String, String?)? f) {}
  @override set authenticateProxy(Future<bool> Function(String, int, String, String?)? f) {}
  @override set badCertificateCallback(bool Function(X509Certificate, String, int)? cb) {}
  @override set findProxy(String Function(Uri)? f) {}
  @override set connectionFactory(
      Future<ConnectionTask<Socket>> Function(Uri, String?, int?)? f) {}
  @override set keyLog(Function(String line)? callback) {}
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // audioplayers global channel — GlobalAudioScope.ensureInitialized calls 'init' here
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);

    // audioplayers per-instance channel — AudioPlayer() fires 'create' here.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), (_) async => null);

    // SharedPreferences — ChuckerDioInterceptor.onError reads and writes prefs.
    // 'setValue' must return true (bool) — MethodChannelSharedPreferencesStore
    // force-unwraps the result with !, causing NPE if null is returned.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/shared_preferences'),
            (call) async =>
                call.method == 'getAll' ? <String, Object>{} : true);

    // Coralogix — MonitoringServiceHelper tries to log errors here
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('cx_flutter_plugin'), (_) async => null);

    HttpOverrides.global = _FailFastHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  late MockSafetyShield mockShield;
  late MockShieldDeterrenceAudio mockDeterrence;
  late SnabbitShieldProvider provider;
  late SosFlowCoordinator coordinator;
  late bool stopShieldCalled;

  setUp(() {
    mockShield = MockSafetyShield();
    mockDeterrence = MockShieldDeterrenceAudio();
    provider = SnabbitShieldProvider();
    stopShieldCalled = false;

    when(mockShield.deescalateSoS()).thenAnswer((_) async {});
    when(mockShield.denySoS()).thenAnswer((_) async {});
    when(mockDeterrence.cancel()).thenAnswer((_) {});

    coordinator = SosFlowCoordinator(
      shield: mockShield,
      shieldProvider: provider,
      deterrence: mockDeterrence,
      log: (_) {},
      logError: (_, __) {},
      trackShieldEvent: (String _, [dynamic __]) {},
      currentJobId: () => 1,
      currentWidgetName: () => 'RUNNER_JOB_IN_PROGRESS',
      startShield: (BuildContext _, {required ShieldTrigger trigger}) async {},
      stopShield: () async { stopShieldCalled = true; },
      persistManualMonitoringFlag: (bool active) {  },
    );
  });

  // ── deescalateSos ───────────────────────────────────────────────────────────

  group('SosFlowCoordinator.deescalateSos', () {
    test('snapshot null — SOS mode cleared, monitoringAcknowledged unchanged, stopShield not called',
        () async {
      // preSosSnapshot is null by default — no capturePreSosState call

      await coordinator.deescalateSos();

      expect(provider.isSOSMode, isFalse);
      expect(provider.monitoringAcknowledged, isFalse);
      expect(stopShieldCalled, isFalse);
    });

    test('wasShieldRecording=true — stopShield not called', () async {
      provider.setShieldRecording(true);
      provider.capturePreSosState(); // wasShieldRecording=true

      await coordinator.deescalateSos();

      expect(stopShieldCalled, isFalse);
    });

    test('wasShieldRecording=false, isShieldRecording=false — stopShield not called',
        () async {
      // isShieldRecording is false by default
      provider.capturePreSosState(); // wasShieldRecording=false

      await coordinator.deescalateSos();

      expect(stopShieldCalled, isFalse);
    });

    test('wasShieldRecording=false, isShieldRecording=true — stopShield called', () async {
      provider.capturePreSosState();        // wasShieldRecording=false
      provider.setShieldRecording(true);    // recording started during the SOS window

      await coordinator.deescalateSos();

      expect(stopShieldCalled, isTrue);
    });

    test('wasAccelerometerOnly=true, isShieldRecording=true — stopShield not called', () async {
      // Shield was in accel-only mode before SOS; SOS upgraded it to recording.
      // Deescalate must not stop — shield was already running before the SOS.
      provider.setAccelerometerActive(true);
      provider.capturePreSosState(); // wasAccelerometerOnly=true, wasShieldRecording=false
      provider.setShieldRecording(true);

      await coordinator.deescalateSos();

      expect(stopShieldCalled, isFalse);
    });

    test('wasMonitoringOnly=true, isShieldRecording=true — stopShield not called', () async {
      // Shield was in MONITORING_ONLY before SOS; SOS permanently upgraded to MONITORING.
      // Deescalate must not stop — monitoring was already running before the SOS.
      provider.setMonitoringOnly(true);
      provider.capturePreSosState(); // wasMonitoringOnly=true, wasShieldRecording=false
      provider.setShieldRecording(true);

      await coordinator.deescalateSos();

      expect(stopShieldCalled, isFalse);
    });

    test('wasMonitoringOnly=true — isMonitoringOnly cleared after deescalate', () async {
      // After MONITORING_ONLY → MONITORING upgrade, the stale isMonitoringOnly flag
      // must be cleared so the UI reflects the new permanent MONITORING state.
      provider.setMonitoringOnly(true);
      provider.capturePreSosState();

      await coordinator.deescalateSos();

      expect(provider.isMonitoringOnly, isFalse);
    });

    test('wasMonitoringOnly=false — isMonitoringOnly left unchanged', () async {
      provider.capturePreSosState(); // wasMonitoringOnly=false

      await coordinator.deescalateSos();

      expect(provider.isMonitoringOnly, isFalse);
    });

    test('monitoringAcknowledged restored from snapshot', () async {
      provider.monitoringAcknowledged = true;
      provider.capturePreSosState(); // wasMonitoringAcknowledged=true
      provider.monitoringAcknowledged = false; // changed during SOS

      await coordinator.deescalateSos();

      expect(provider.monitoringAcknowledged, isTrue);
    });

    test('SOS mode is cleared regardless of snapshot presence', () async {
      provider.setSOSMode(true);
      provider.capturePreSosState();

      await coordinator.deescalateSos();

      expect(provider.isSOSMode, isFalse);
    });
  });

  // ── onFalseAlarm ────────────────────────────────────────────────────────────

  group('SosFlowCoordinator.onFalseAlarm', () {
    test(
        'guard false — isShieldRecording=false — snapshot untouched, stopShield not called',
        () async {
      provider.setSOSMode(true);
      // isShieldRecording is false by default → guard (isShieldRecording && isSOSMode) fails
      provider.capturePreSosState();
      provider.monitoringAcknowledged = true;

      await coordinator.onFalseAlarm();

      // restore never ran — monitoringAcknowledged still holds its pre-call value
      expect(provider.monitoringAcknowledged, isTrue);
      expect(stopShieldCalled, isFalse);
    });

    test(
        'guard false — isSOSMode=false — snapshot untouched, stopShield not called',
        () async {
      provider.setShieldRecording(true);
      // isSOSMode is false by default → guard fails
      provider.capturePreSosState();
      provider.monitoringAcknowledged = true;

      await coordinator.onFalseAlarm();

      expect(provider.monitoringAcknowledged, isTrue);
      expect(stopShieldCalled, isFalse);
    });

    test('snapshot null — monitoringAcknowledged unchanged, stopShield not called',
        () async {
      provider.setShieldRecording(true);
      provider.setSOSMode(true);
      // preSosSnapshot is null — no capturePreSosState call

      await coordinator.onFalseAlarm();

      expect(provider.monitoringAcknowledged, isFalse);
      expect(stopShieldCalled, isFalse);
    });

    test('snapshot exists — monitoringAcknowledged restored, stopShield never called',
        () async {
      // Capture pre-SOS with wasShieldRecording=false, wasMonitoringAcknowledged=true
      provider.monitoringAcknowledged = true;
      provider.capturePreSosState();
      // Simulate recording started during SOS (isShieldRecording=true, wasShieldRecording=false)
      provider.setShieldRecording(true);
      provider.setSOSMode(true);
      provider.monitoringAcknowledged = false; // changed during SOS

      await coordinator.onFalseAlarm();

      expect(provider.monitoringAcknowledged, isTrue); // restored from snapshot
      // onFalseAlarm intentionally omits _stopShield per §10.6 — shield stops only on job checkout
      expect(stopShieldCalled, isFalse);
    });

    test('wasMonitoringOnly=true origin — monitoringAcknowledged restored correctly',
        () async {
      // Snapshot was captured while shield was in MONITORING_ONLY mode
      provider.setMonitoringOnly(true);
      provider.monitoringAcknowledged = true;
      provider.capturePreSosState(); // wasMonitoringOnly=true, wasMonitoringAcknowledged=true
      provider.setShieldRecording(true);
      provider.setSOSMode(true);
      provider.monitoringAcknowledged = false;

      await coordinator.onFalseAlarm();

      expect(provider.monitoringAcknowledged, isTrue);
      expect(stopShieldCalled, isFalse);
    });

    test('SOS mode cleared after false alarm resolves', () async {
      provider.setShieldRecording(true);
      provider.setSOSMode(true);
      provider.capturePreSosState();

      await coordinator.onFalseAlarm();

      expect(provider.isSOSMode, isFalse);
    });
  });
}
