import 'package:flutter_test/flutter_test.dart';
import 'package:scout_flutter/scout_flutter.dart';
import 'package:snabbit_runner/services/monitoring/base14_monitoring_service.dart';

/// Tests the pure config builder that maps the Remote Config JSON blob onto a
/// [ScoutFlutterConfig]. The builder is deliberately free of Firebase / Remote
/// Config / singletons so it can be exercised directly. Focus is the defensive
/// coercion: a missing or wrong-typed field must fall back to the current
/// default, and blob overrides must win when present and well-typed.
void main() {
  ScoutFlutterConfig build(
    Map<String, dynamic> blob, {
    String endpoint = 'https://otel.example.com/otlp',
    String ingestToken = 'token-123',
    double sampleRate = 100.0,
    String? serviceVersion = '42',
    bool isProd = false,
    bool debugLogging = false,
  }) {
    return Base14MonitoringService.buildScoutConfig(
      blob: blob,
      endpoint: endpoint,
      ingestToken: ingestToken,
      sampleRate: sampleRate,
      serviceVersion: serviceVersion,
      isProd: isProd,
      debugLogging: debugLogging,
    );
  }

  group('buildScoutConfig — identity & transport', () {
    test('empty blob, non-prod → staging identity + passed transport', () {
      final c = build(const {});

      expect(c.serviceName, 'staging-expert-android');
      expect(c.environment, 'staging');
      expect(c.endpoint, 'https://otel.example.com/otlp');
      expect(c.serviceVersion, '42');
      expect(c.resourceAttributes, {'app': 'staging-expert-android'});
      expect(c.headers, {'Authorization': 'Bearer token-123'});
      expect(
        c.firstPartyHosts,
        containsAll(<String>['snabbit.com', 'maestroserve.com']),
      );
    });

    test('empty blob, prod → prod identity labels', () {
      final c = build(const {}, isProd: true);

      expect(c.serviceName, 'prod-expert-android');
      expect(c.environment, 'production');
    });

    test('blob overrides serviceName / environment / firstPartyHosts', () {
      final c = build(const {
        'serviceName': 'custom-service',
        'environment': 'canary',
        'firstPartyHosts': ['a.com', 'b.com'],
      });

      expect(c.serviceName, 'custom-service');
      expect(c.environment, 'canary');
      expect(c.resourceAttributes, {'app': 'custom-service'});
      expect(c.firstPartyHosts, ['a.com', 'b.com']);
    });

    test('empty ingest token → no Authorization header', () {
      final c = build(const {}, ingestToken: '');
      expect(c.headers, isNull);
    });

    test('debugLogging is passed through', () {
      expect(build(const {}, debugLogging: true).debugLogging, isTrue);
      expect(build(const {}).debugLogging, isFalse);
    });
  });

  group('buildScoutConfig — defaults when blob is empty', () {
    late ScoutFlutterConfig c;
    setUp(() => c = build(const {}));

    test('the three load-bearing off-switches stay false', () {
      expect(c.enablePerformanceMetrics, isFalse);
      expect(c.enableErrorTracking, isFalse);
      expect(c.alwaysCaptureErrors, isFalse);
    });

    test('auto-instrumentation toggles default true', () {
      expect(c.enableAutoTapTracking, isTrue);
      expect(c.enableLifecycleTracking, isTrue);
      expect(c.enableStartupTracking, isTrue);
      expect(c.enableConnectivityTracking, isTrue);
      expect(c.enableNetworkTracking, isTrue);
      expect(c.enableLogging, isTrue);
      expect(c.enableAnrDetection, isTrue);
      expect(c.enableLongTaskDetection, isTrue);
      expect(c.capturePrintStatements, isFalse);
    });

    test('metrics + thresholds + sessions + offline defaults', () {
      // Memory/CPU default false (matches scout_flutter 0.1.23 SDK default):
      // enabling perf metrics via the blob must not auto-enable them.
      expect(c.enableFrameMetrics, isFalse);
      expect(c.enableMemoryMetrics, isFalse);
      expect(c.enableCpuMetrics, isFalse);
      expect(c.longTaskThresholdMs, 100);
      expect(c.anrThresholdMs, 5000);
      expect(c.sessionTimeoutMinutes, 30);
      expect(c.maxSessionDurationMinutes, 60);
      expect(c.offlineBufferEnabled, isTrue);
      expect(c.offlineMaxTraceItems, 5000);
      expect(c.maxOfflineStorageMb, 5);
    });
  });

  group('buildScoutConfig — well-typed blob overrides apply', () {
    test('flips bools and numbers from their defaults', () {
      final c = build(const {
        'enablePerformanceMetrics': true,
        'enableErrorTracking': true,
        'alwaysCaptureErrors': true,
        'enableNetworkTracking': false,
        'enableLogging': false,
        'offlineBufferEnabled': false,
        'longTaskThresholdMs': 250,
        'anrThresholdMs': 3000,
        'sessionTimeoutMinutes': 15,
        'maxOfflineStorageMb': 20,
      });

      expect(c.enablePerformanceMetrics, isTrue);
      expect(c.enableErrorTracking, isTrue);
      expect(c.alwaysCaptureErrors, isTrue);
      expect(c.enableNetworkTracking, isFalse);
      expect(c.enableLogging, isFalse);
      expect(c.offlineBufferEnabled, isFalse);
      expect(c.longTaskThresholdMs, 250);
      expect(c.anrThresholdMs, 3000);
      expect(c.sessionTimeoutMinutes, 15);
      expect(c.maxOfflineStorageMb, 20);
    });
  });

  group('buildScoutConfig — wrong-typed fields fall back to defaults', () {
    test('bad types do not throw and keep each default', () {
      final c = build(const {
        'enableNetworkTracking': 'nonsense', // not a bool-ish string
        'longTaskThresholdMs': 'abc', // unparseable int
        'firstPartyHosts': 'not-a-list', // not a list
        'serviceName': 123, // not a string
      });

      expect(c.enableNetworkTracking, isTrue); // default
      expect(c.longTaskThresholdMs, 100); // default
      expect(
        c.firstPartyHosts,
        containsAll(<String>['snabbit.com', 'maestroserve.com']),
      );
      expect(c.serviceName, 'staging-expert-android'); // default
    });

    test('empty list / empty string overrides fall back to defaults', () {
      final c = build(const {
        'firstPartyHosts': <String>[],
        'serviceName': '',
      });

      expect(
        c.firstPartyHosts,
        containsAll(<String>['snabbit.com', 'maestroserve.com']),
      );
      expect(c.serviceName, 'staging-expert-android');
    });
  });

  group('_asBool coercion (via enableNetworkTracking, default true)', () {
    // enableNetworkTracking defaults to true, so a falsey coercion is a clear
    // signal the value was honoured rather than defaulted.
    bool net(dynamic v) =>
        build({'enableNetworkTracking': v}).enableNetworkTracking;

    test('real bools pass through', () {
      expect(net(true), isTrue);
      expect(net(false), isFalse);
    });

    test('numbers: non-zero true, zero false', () {
      expect(net(1), isTrue);
      expect(net(0), isFalse);
    });

    test('strings: true/1 (any case) → true, false/0 → false', () {
      expect(net('true'), isTrue);
      expect(net('TRUE'), isTrue);
      expect(net('1'), isTrue);
      expect(net('false'), isFalse);
      expect(net('0'), isFalse);
    });

    test('unrecognised string → falls back to the default (true here)', () {
      expect(net('nope'), isTrue);
    });

    test('unknown type → falls back to the default (true here)', () {
      expect(net(null), isTrue);
      expect(net(const {'x': 1}), isTrue);
    });
  });

  group('parseConfigBlob — defensive decode', () {
    test('empty string → empty map', () {
      expect(Base14MonitoringService.parseConfigBlob(''), isEmpty);
    });

    test('valid JSON object → decoded map', () {
      final m =
          Base14MonitoringService.parseConfigBlob('{"enableLogging": false}');
      expect(m, {'enableLogging': false});
    });

    test('malformed JSON → empty map (no throw)', () {
      // parseConfigBlob is pure/side-effect-free, so malformed input degrades
      // to an empty map without touching Firebase or throwing.
      expect(
          Base14MonitoringService.parseConfigBlob('{not valid json'), isEmpty);
    });

    test('valid JSON but not an object (array/number) → empty map', () {
      expect(Base14MonitoringService.parseConfigBlob('[1,2,3]'), isEmpty);
      expect(Base14MonitoringService.parseConfigBlob('42'), isEmpty);
    });
  });
}
