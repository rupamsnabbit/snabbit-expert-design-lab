import 'package:flutter_test/flutter_test.dart';

import 'package:snabbit_runner/modules/snabbit_shield/snabbit_shield_provider.dart';

void main() {
  // ── PreSosSnapshot ──────────────────────────────────────────────────────────

  group('PreSosSnapshot', () {
    test('stores all four fields correctly', () {
      const snapshot = PreSosSnapshot(
        wasShieldRecording: true,
        wasMonitoringAcknowledged: false,
        wasAccelerometerOnly: true,
        wasMonitoringOnly: false,
      );

      expect(snapshot.wasShieldRecording, isTrue);
      expect(snapshot.wasMonitoringAcknowledged, isFalse);
      expect(snapshot.wasAccelerometerOnly, isTrue);
      expect(snapshot.wasMonitoringOnly, isFalse);
    });
  });

  // ── SnabbitShieldProvider ───────────────────────────────────────────────────

  late SnabbitShieldProvider provider;
  setUp(() => provider = SnabbitShieldProvider());

  // ── capturePreSosState ──────────────────────────────────────────────────────

  group('SnabbitShieldProvider.capturePreSosState', () {
    test('captures isShieldRecording and monitoringAcknowledged at call time', () {
      provider.setShieldRecording(true);
      provider.monitoringAcknowledged = true;

      provider.capturePreSosState();

      expect(provider.preSosSnapshot?.wasShieldRecording, isTrue);
      expect(provider.preSosSnapshot?.wasMonitoringAcknowledged, isTrue);
    });

    test('captures false when all fields are at default', () {
      provider.capturePreSosState();

      expect(provider.preSosSnapshot?.wasShieldRecording, isFalse);
      expect(provider.preSosSnapshot?.wasMonitoringAcknowledged, isFalse);
      expect(provider.preSosSnapshot?.wasAccelerometerOnly, isFalse);
      expect(provider.preSosSnapshot?.wasMonitoringOnly, isFalse);
    });

    test('captures wasAccelerometerOnly=true when shield is in accelerometer-only mode', () {
      provider.setAccelerometerActive(true);

      provider.capturePreSosState();

      expect(provider.preSosSnapshot?.wasAccelerometerOnly, isTrue);
    });

    test('captures wasMonitoringOnly=true when shield is in monitoring-only mode', () {
      provider.setMonitoringOnly(true);

      provider.capturePreSosState();

      expect(provider.preSosSnapshot?.wasMonitoringOnly, isTrue);
    });

    test('is idempotent — second call does not overwrite first capture', () {
      provider.setShieldRecording(true);
      provider.capturePreSosState(); // wasShieldRecording=true

      provider.setShieldRecording(false);
      provider.capturePreSosState(); // must NOT overwrite

      expect(provider.preSosSnapshot?.wasShieldRecording, isTrue);
    });
  });

  // ── clearPreSosState ────────────────────────────────────────────────────────

  group('SnabbitShieldProvider.clearPreSosState', () {
    test('sets preSosSnapshot to null', () {
      provider.capturePreSosState();
      expect(provider.preSosSnapshot, isNotNull);

      provider.clearPreSosState();

      expect(provider.preSosSnapshot, isNull);
    });
  });

  // ── setShieldRecording ──────────────────────────────────────────────────────

  group('SnabbitShieldProvider.setShieldRecording', () {
    test('setting false is a no-op when isAccelerometerOnly is true', () {
      provider.setShieldRecording(true);
      provider.setAccelerometerActive(true);

      provider.setShieldRecording(false);

      expect(provider.isShieldRecording, isTrue);
    });

    test('setting false works normally when isAccelerometerOnly is false', () {
      provider.setShieldRecording(true);

      provider.setShieldRecording(false);

      expect(provider.isShieldRecording, isFalse);
    });

    test('setting true clears isStartingMonitoring', () {
      provider.setStartingMonitoring(true);

      provider.setShieldRecording(true);

      expect(provider.isStartingMonitoring, isFalse);
    });

    test('setting false does not clear isStartingMonitoring', () {
      provider.setStartingMonitoring(true);

      provider.setShieldRecording(false);

      expect(provider.isStartingMonitoring, isTrue);
    });
  });

  // ── setMonitoringOnly ───────────────────────────────────────────────────────

  group('SnabbitShieldProvider.setMonitoringOnly', () {
    test('sets isMonitoringOnly to true', () {
      provider.setMonitoringOnly(true);

      expect(provider.isMonitoringOnly, isTrue);
    });

    test('sets isMonitoringOnly to false', () {
      provider.setMonitoringOnly(true);
      provider.setMonitoringOnly(false);

      expect(provider.isMonitoringOnly, isFalse);
    });
  });

  // ── setAccelerometerActive ──────────────────────────────────────────────────

  group('SnabbitShieldProvider.setAccelerometerActive', () {
    test('sets isAccelerometerOnly to true', () {
      provider.setAccelerometerActive(true);

      expect(provider.isAccelerometerOnly, isTrue);
    });

    test('sets isAccelerometerOnly to false', () {
      provider.setAccelerometerActive(true);
      provider.setAccelerometerActive(false);

      expect(provider.isAccelerometerOnly, isFalse);
    });
  });

  // ── reset ───────────────────────────────────────────────────────────────────

  group('SnabbitShieldProvider.reset', () {
    test('resets all state fields to defaults', () {
      provider.setShieldRecording(true);
      provider.setRecordingState(isRecording: true, elapsedSeconds: 10, amplitude: 0.5);
      provider.setPaused(true);
      provider.setSOSMode(true);
      provider.monitoringAcknowledged = true;
      provider.setStartingMonitoring(true);
      provider.setAccelerometerActive(true);
      provider.setMonitoringOnly(true);
      provider.capturePreSosState();

      provider.reset();

      expect(provider.isShieldRecording, isFalse);
      expect(provider.isRecording, isFalse);
      expect(provider.elapsedSeconds, 0);
      expect(provider.amplitude, 0.0);
      expect(provider.isPaused, isFalse);
      expect(provider.isSOSMode, isFalse);
      expect(provider.monitoringAcknowledged, isFalse);
      expect(provider.isStartingMonitoring, isFalse);
      expect(provider.isAccelerometerOnly, isFalse);
      expect(provider.isMonitoringOnly, isFalse);
      expect(provider.preSosSnapshot, isNull);
    });
  });
}
