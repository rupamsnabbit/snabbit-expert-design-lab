import 'package:flutter/foundation.dart';

import 'shield_storage_check.dart';

/// Provider state captured at the moment an SOS alert triggers.
/// Read by [SosFlowCoordinator] after SOS resolves to restore UI state.
class PreSosSnapshot {
  final bool wasShieldRecording;
  final bool wasMonitoringAcknowledged;
  // true when only accelerometer was running before SoS (no monitoring/recording)
  final bool wasAccelerometerOnly;
  // true when ML monitoring was running before SoS but no recording (MONITORING_ONLY state)
  final bool wasMonitoringOnly;
  const PreSosSnapshot({
    required this.wasShieldRecording,
    required this.wasMonitoringAcknowledged,
    required this.wasAccelerometerOnly,
    required this.wasMonitoringOnly,
  });
}

/// Thin reactive state holder for Snabbit Shield.
///
/// Holds all UI-observable state and notifies listeners on change.
/// Business logic lives in [SafetyShieldAdapter] (orchestration / gates)
/// and the native [SafetyShield] plugin (recording / upload pipeline).
class SnabbitShieldProvider extends ChangeNotifier {
  // ── State fields ──────────────────────────────────────
  bool _isShieldRecording = false;
  bool _isRecording = false;
  int _elapsedSeconds = 0;
  double _amplitude = 0.0;
  bool _isPaused = false;
  bool _isRecorderPaused = false;
  String? _error;
  bool _isLowStorage = false;
  bool _isSOSMode = false;
  bool _monitoringAcknowledged = false;
  bool _isStartingMonitoring = false;
  PreSosSnapshot? _preSosSnapshot;
  // tracks whether shield is in accelerometer-only mode (no monitoring/recording)
  bool _isAccelerometerOnly = false;
  // tracks whether shield is in ML-monitoring-only mode (no recording)
  bool _isMonitoringOnly = false;

  // ── Public getters (for UI) ───────────────────────────
  bool get isShieldRecording => _isShieldRecording;
  bool get isRecording => _isRecording;
  int get elapsedSeconds => _elapsedSeconds;
  double get amplitude => _amplitude;
  bool get isPaused => _isPaused;

  /// True when the system interrupted the recorder (e.g. phone call, media).
  bool get isRecorderPaused => _isRecorderPaused;
  String? get error => _error;

  /// True when device storage is below the configured threshold.
  bool get isLowStorage => _isLowStorage;

  /// True when the shield is operating in SOS elevated-frequency mode.
  bool get isSOSMode => _isSOSMode;

  /// True when the user has explicitly acknowledged monitoring (tapped Start Monitoring).
  /// Auto-started recording does NOT set this — the card stays in "Start Monitoring" state.
  bool get monitoringAcknowledged => _monitoringAcknowledged;

  /// True while the user has tapped Activate and we are starting monitoring (e.g. show Kavach Lottie).
  bool get isStartingMonitoring => _isStartingMonitoring;

  /// Snapshot captured when SOS triggered; null outside of active SOS flow.
  PreSosSnapshot? get preSosSnapshot => _preSosSnapshot;

  /// True when shield is in accelerometer-only mode (no mic/monitoring).
  bool get isAccelerometerOnly => _isAccelerometerOnly;

  /// True when shield is in ML-monitoring-only mode (no recording).
  bool get isMonitoringOnly => _isMonitoringOnly;

  // ── Public setters (for UI interaction) ────────────────
  set monitoringAcknowledged(bool value) {
    _monitoringAcknowledged = value;
    notifyListeners();
  }

  /// Set by the controller when user taps Activate; cleared when recording starts or after timeout.
  void setStartingMonitoring(bool value) {
    if (_isStartingMonitoring != value) {
      _isStartingMonitoring = value;
      notifyListeners();
    }
  }

  // ── State updates (called by recorder / controller) ────
  void setShieldRecording(bool value) {
    // Accelerometer-only mode keeps the FGS alive with no audio recording.
    // Recording-idle events must not flip isActive=false while that mode is on.
    if (!value && _isAccelerometerOnly) return;
    _isShieldRecording = value;
    if (value) _isStartingMonitoring = false;
    notifyListeners();
  }

  void setRecordingState({
    bool? isRecording,
    bool? isRecorderPaused,
    int? elapsedSeconds,
    double? amplitude,
    String? error,
  }) {
    if (isRecording != null) _isRecording = isRecording;
    if (isRecorderPaused != null) _isRecorderPaused = isRecorderPaused;
    if (elapsedSeconds != null) _elapsedSeconds = elapsedSeconds;
    if (amplitude != null) _amplitude = amplitude;
    if (error != null) _error = error;
    notifyListeners();
  }

  /// Clears any previous error so a new start attempt shows fresh state.
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void setPaused(bool value) {
    _isPaused = value;
    notifyListeners();
  }

  void setSOSMode(bool value) {
    _isSOSMode = value;
    notifyListeners();
  }

  void setLowStorage(bool value) {
    if (value != _isLowStorage) {
      _isLowStorage = value;
      notifyListeners();
    }
  }

  /// Set from call sites after startAccelerometerOnly() succeeds or when that mode ends.
  /// Not UI-observable — internal tracking only, so no notifyListeners.
  void setAccelerometerActive(bool value) {
    _isAccelerometerOnly = value;
  }

  /// Set from call sites after startMonitoringOnly() succeeds or when recording starts.
  /// Not UI-observable — internal tracking only, so no notifyListeners.
  void setMonitoringOnly(bool value) {
    _isMonitoringOnly = value;
  }

  /// Captures current state as the pre-SOS baseline. Idempotent — first call wins.
  void capturePreSosState() {
    _preSosSnapshot ??= PreSosSnapshot(
      wasShieldRecording: _isShieldRecording,
      wasMonitoringAcknowledged: _monitoringAcknowledged,
      wasAccelerometerOnly: _isAccelerometerOnly,
      wasMonitoringOnly: _isMonitoringOnly,
    );
  }

  void clearPreSosState() {
    _preSosSnapshot = null;
  }

  /// Resets all state to defaults. Called by the shield adapter on stop.
  void reset() {
    _isShieldRecording = false;
    _isRecording = false;
    _isRecorderPaused = false;
    _isPaused = false;
    _elapsedSeconds = 0;
    _amplitude = 0.0;
    _error = null;
    _isSOSMode = false;
    _monitoringAcknowledged = false;
    _isStartingMonitoring = false;
    _isAccelerometerOnly = false;
    _isMonitoringOnly = false;
    _preSosSnapshot = null;
    notifyListeners();
  }

  // ── Convenience ────────────────────────────────────────

  /// Checks device storage and updates the UI-observable [isLowStorage] flag.
  Future<void> updateStorageStatus() async {
    setLowStorage(await checkShieldStorageLow());
  }

}
