// Unit tests for IotForegroundFallback.
//
// Covers the gate predicates (kill-switch, foreground, staleness, bg-alive,
// reentrancy) and the happy/error paths of the insert + drain step.
//
// `WidgetsBinding` lifecycle and `FlutterBackgroundService.isRunning` are
// passed in as functions so we don't need a real binding or platform channel.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/iot/config/config_service.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_collector.dart';
import 'package:snabbit_runner/services/iot/foreground_fallback/iot_foreground_fallback.dart';
import 'package:snabbit_runner/services/iot/sender/sender.dart';

import 'iot_foreground_fallback_test.mocks.dart';

@GenerateMocks([
  IDatabaseInterface,
  Sender,
  IotDiagnosticsCollector,
  ConfigService,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IotForegroundFallback.maybeSend', () {
    late MockIDatabaseInterface mockDb;
    late MockSender mockSender;
    late MockIotDiagnosticsCollector mockDiagnostics;
    late MockConfigService mockConfig;

    const userId = 'user-123';
    const lastSendKey = 'iot_last_send_success_ms';

    /// Builds a fallback with the supplied overrides; lifecycle defaults to
    /// resumed and isRunning defaults to false so most tests exercise the
    /// "all gates pass" path unless they override.
    IotForegroundFallback build({
      AppLifecycleState lifecycle = AppLifecycleState.resumed,
      Future<bool> Function()? isBgServiceRunning,
    }) {
      return IotForegroundFallback(
        database: mockDb,
        sender: mockSender,
        diagnostics: mockDiagnostics,
        config: mockConfig,
        getLifecycleState: () => lifecycle,
        isBgServiceRunning: isBgServiceRunning ?? () async => false,
        getEndpoint: () => 'https://test-iot.example.com/api/v1/iot',
      );
    }

    setUp(() {
      IotForegroundFallback.resetInFlightForTesting();
      mockDb = MockIDatabaseInterface();
      mockSender = MockSender();
      mockDiagnostics = MockIotDiagnosticsCollector();
      mockConfig = MockConfigService();

      // Default config: enabled with 5 min threshold. Individual tests can
      // override via additional when(...) calls before invoking maybeSend.
      when(mockConfig.initialize()).thenAnswer((_) async {});
      when(mockConfig.fgFallbackEnabled).thenReturn(true);
      when(mockConfig.fgFallbackStalenessThresholdSeconds).thenReturn(300);

      // Default diagnostic emits succeed silently.
      when(mockDiagnostics.logDiagnostic(any, any))
          .thenAnswer((_) async {});

      // Default Sender returns "0 rows sent" unless overridden.
      when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);

      // Default DB insert returns row id 1.
      when(mockDb.insert(any, any)).thenAnswer((_) async => 1);

      SharedPreferences.setMockInitialValues({});
    });

    test('empty userId → no work, no diagnostic', () async {
      await build().maybeSend(null, '');

      verifyZeroInteractions(mockConfig);
      verifyZeroInteractions(mockSender);
      verifyZeroInteractions(mockDb);
      verifyZeroInteractions(mockDiagnostics);
    });

    test('kill switch off → returns silently, no Sender call', () async {
      when(mockConfig.fgFallbackEnabled).thenReturn(false);

      await build().maybeSend(null, userId);

      verify(mockConfig.initialize()).called(1);
      verifyNever(mockSender.sendAllData(any, any));
      verifyNever(mockDiagnostics.logDiagnostic(any, any));
    });

    test('ConfigService.initialize throws → SKIPPED(config_init_failed)',
        () async {
      when(mockConfig.initialize()).thenThrow(Exception('boom'));

      await build().maybeSend(null, userId);

      final captured = verify(mockDiagnostics.logDiagnostic(
              'IOT_FG_FALLBACK_SKIPPED', captureAny))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['reason'], 'config_init_failed');
      verifyNever(mockSender.sendAllData(any, any));
    });

    test('lifecycle provider throws → silent skip', () async {
      final fb = IotForegroundFallback(
        database: mockDb,
        sender: mockSender,
        diagnostics: mockDiagnostics,
        config: mockConfig,
        getLifecycleState: () => throw Exception('binding torn down'),
        isBgServiceRunning: () async => false,
        getEndpoint: () => 'https://test-iot.example.com/api/v1/iot',
      );

      await fb.maybeSend(null, userId);

      verifyNever(mockSender.sendAllData(any, any));
      verifyNever(mockDiagnostics.logDiagnostic(any, any));
    });

    test('unexpected throw in inner gate → caught, SKIPPED(unexpected_error)',
        () async {
      // fgFallbackEnabled is read after a successful initialize() and is not
      // individually wrapped, so a throw here exercises maybeSend's top-level
      // never-reject catch.
      when(mockConfig.fgFallbackEnabled).thenThrow(Exception('weird'));

      await build().maybeSend(null, userId);

      final captured = verify(mockDiagnostics.logDiagnostic(
              'IOT_FG_FALLBACK_SKIPPED', captureAny))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['reason'], 'unexpected_error');
    });

    test('not foregrounded → silent skip', () async {
      await build(lifecycle: AppLifecycleState.paused).maybeSend(null, userId);

      verifyNever(mockSender.sendAllData(any, any));
      verifyNever(mockDiagnostics.logDiagnostic(any, any));
    });

    test('no send history (lastSendMs == 0) → SKIPPED(no_send_history)',
        () async {
      // No prefs value seeded → defaults to 0.
      await build().maybeSend(null, userId);

      final captured = verify(
              mockDiagnostics.logDiagnostic('IOT_FG_FALLBACK_SKIPPED', captureAny))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['reason'], 'no_send_history');
      expect(captured['staleness_ms'], 0);
      verifyNever(mockSender.sendAllData(any, any));
    });

    test('not stale (staleness < threshold) → silent skip', () async {
      // Last send was 1 second ago — well under 300s threshold.
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - 1000,
      });

      await build().maybeSend(null, userId);

      verifyNever(mockSender.sendAllData(any, any));
      verifyNever(mockDiagnostics.logDiagnostic(any, any));
    });

    test('isRunning throws → SKIPPED(is_running_check_failed)', () async {
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000),
      });

      await build(isBgServiceRunning: () async => throw Exception('plat'))
          .maybeSend(null, userId);

      final captured = verify(
              mockDiagnostics.logDiagnostic('IOT_FG_FALLBACK_SKIPPED', captureAny))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['reason'], 'is_running_check_failed');
      verifyNever(mockSender.sendAllData(any, any));
    });

    test('bg service alive → SKIPPED(bg_alive)', () async {
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000),
      });

      await build(isBgServiceRunning: () async => true)
          .maybeSend(null, userId);

      final captured = verify(
              mockDiagnostics.logDiagnostic('IOT_FG_FALLBACK_SKIPPED', captureAny))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['reason'], 'bg_alive');
      verifyNever(mockSender.sendAllData(any, any));
    });

    test('happy path with fresh Position → insert + send + PING_SENT',
        () async {
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000),
      });
      when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 3);

      final position = Position(
        latitude: 19.0760,
        longitude: 72.8777,
        timestamp: DateTime.now(),
        accuracy: 10.5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: false,
      );

      await build().maybeSend(position, userId);

      // Inserted into DB — and the fg-fallback singleton carries a non-null
      // collection_cycle_id equal to the GPS fix time (same as collected_at).
      final insertedMap = verify(mockDb.insert(
        DatabaseTables.location,
        captureAny,
      )).captured.single as Map<String, dynamic>;
      final fixMs = position.timestamp.millisecondsSinceEpoch;
      expect(insertedMap['collection_cycle_id'], fixMs);
      expect(insertedMap['collection_cycle_id'], insertedMap['collected_at']);
      // Drained via Sender
      verify(mockSender.sendAllData(userId, any)).called(1);
      // PING_SENT diagnostic emitted with rows_sent: 3 and had_fresh_position: true
      final captured = verify(
              mockDiagnostics.logDiagnostic('IOT_FG_FALLBACK_PING_SENT', captureAny))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['rows_sent'], 3);
      expect(captured['had_fresh_position'], true);
      expect(captured['user_id'], userId);
      expect(captured['staleness_ms'], greaterThan(0));
    });

    test('happy path with null Position → no insert, drain only, PING_SENT',
        () async {
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000),
      });
      when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 1);

      await build().maybeSend(null, userId);

      verifyNever(mockDb.insert(any, any));
      verify(mockSender.sendAllData(userId, any)).called(1);
      final captured = verify(
              mockDiagnostics.logDiagnostic('IOT_FG_FALLBACK_PING_SENT', captureAny))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['had_fresh_position'], false);
      expect(captured['rows_sent'], 1);
    });

    test('insert fails → INSERT_FAILED event AND drain still attempted',
        () async {
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000),
      });
      when(mockDb.insert(any, any)).thenThrow(Exception('db boom'));
      when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 2);

      final position = Position(
        latitude: 19.0760,
        longitude: 72.8777,
        timestamp: DateTime.now(),
        accuracy: 10.5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: false,
      );

      await build().maybeSend(position, userId);

      // Insert was attempted
      verify(mockDb.insert(any, any)).called(1);
      // Distinct event (NOT SKIPPED) so analytics don't read the whole op as
      // skipped; flags that the drain still ran.
      final captured = verify(mockDiagnostics.logDiagnostic(
              'IOT_FG_FALLBACK_INSERT_FAILED', captureAny))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['continued_to_drain'], true);
      // No SKIPPED event emitted for this poll.
      verifyNever(
          mockDiagnostics.logDiagnostic('IOT_FG_FALLBACK_SKIPPED', any));
      // Sender still called (drain backlog regardless)
      verify(mockSender.sendAllData(userId, any)).called(1);
    });

    test('drain returns 0 (nothing to send) → no PING_SENT', () async {
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000),
      });
      when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);

      await build().maybeSend(null, userId);

      verify(mockSender.sendAllData(userId, any)).called(1);
      verifyNever(
          mockDiagnostics.logDiagnostic('IOT_FG_FALLBACK_PING_SENT', any));
    });

    test('Sender throws → SKIPPED(send_failed)', () async {
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000),
      });
      when(mockSender.sendAllData(any, any))
          .thenThrow(Exception('network down'));

      await build().maybeSend(null, userId);

      final captured = verify(mockDiagnostics.logDiagnostic(
              'IOT_FG_FALLBACK_SKIPPED', captureAny))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['reason'], 'send_failed');
      expect(captured['error'], contains('network down'));
    });

    test('reentrancy: concurrent calls → second short-circuits', () async {
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000),
      });
      // Make sendAllData slow so the first call holds _inFlight.
      when(mockSender.sendAllData(any, any)).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 1;
      });

      final fb = build();
      final first = fb.maybeSend(null, userId);
      // Second call fires while first is mid-flight; should no-op.
      await fb.maybeSend(null, userId);
      await first;

      // Only one drain — the second call was suppressed by the guard.
      verify(mockSender.sendAllData(any, any)).called(1);
    });

    test('Position with null sub-fields (heading/speed) → insert succeeds',
        () async {
      // Geolocator's Position requires non-null doubles, so "null sub-fields"
      // are surfaced as 0 in practice. This test confirms an all-zeros
      // Position still inserts cleanly (no nulls, no field-access errors).
      SharedPreferences.setMockInitialValues({
        lastSendKey: DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000),
      });
      when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 1);

      final position = Position(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: false,
      );

      await build().maybeSend(position, userId);

      verify(mockDb.insert(DatabaseTables.location, any)).called(1);
      verify(mockDiagnostics.logDiagnostic(
              'IOT_FG_FALLBACK_PING_SENT', any))
          .called(1);
    });
  });
}
