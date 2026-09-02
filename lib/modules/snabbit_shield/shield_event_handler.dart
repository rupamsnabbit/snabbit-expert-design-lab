import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:safety_shield/safety_shield.dart';

import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

import 'snabbit_shield_config.dart';
import 'snabbit_shield_encryptor.dart';
import 'snabbit_shield_provider.dart';
import 'snabbit_shield_upload_queue.dart';
import 'sos_flow_coordinator.dart';

/// Routes plugin event streams to the upload queue, UI provider, analytics,
/// and monitoring services.
///
/// Follows the callback-injection coordinator pattern (same as
/// [SosFlowCoordinator]).
class ShieldEventHandler {
  // ── Dependencies (via constructor) ──────────────────
  final SafetyShield _shield;
  final SnabbitShieldProvider _shieldProvider;
  final SosFlowCoordinator _sosCoordinator;
  final void Function(String message) _log;
  final void Function(String message, dynamic error) _logError;
  final void Function(String eventName, [Map<String, dynamic> extra])
      _trackShieldEvent;
  final int? Function() _currentJobId;
  final ShieldTrigger? Function() _activeTrigger;
  final ShieldEncryptor? Function() _encryptor;
  final ShieldUploadQueue? Function() _uploadQueue;

  // ── Stream subscriptions ────────────────────────────
  StreamSubscription? _encryptedAudioSub;
  StreamSubscription? _sosTriggeredSub;
  StreamSubscription? _instrumentationSub;
  StreamSubscription? _recordingStateSub;
  StreamSubscription? _monitoringStateSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _permissionStatusSub;
  StreamSubscription? _accessibilityServiceSub;
  StreamSubscription? _notificationActionSub;

  /// True while [subscribe] has active listeners. Makes [subscribe]/[cancel]
  /// idempotent so a repeat or racing cancel can't hit the engine's
  /// "No active stream to cancel" path (2.4.15 EventChannel crash).
  bool _subscribed = false;

  ShieldEventHandler({
    required SafetyShield shield,
    required SnabbitShieldProvider shieldProvider,
    required SosFlowCoordinator sosCoordinator,
    required void Function(String message) log,
    required void Function(String message, dynamic error) logError,
    required void Function(String eventName, [Map<String, dynamic> extra])
        trackShieldEvent,
    required int? Function() currentJobId,
    required ShieldTrigger? Function() activeTrigger,
    required ShieldEncryptor? Function() encryptor,
    required ShieldUploadQueue? Function() uploadQueue,
  })  : _shield = shield,
        _shieldProvider = shieldProvider,
        _sosCoordinator = sosCoordinator,
        _log = log,
        _logError = logError,
        _trackShieldEvent = trackShieldEvent,
        _currentJobId = currentJobId,
        _activeTrigger = activeTrigger,
        _encryptor = encryptor,
        _uploadQueue = uploadQueue;

  // ── Public API ──────────────────────────────────────

  /// Subscribes to all plugin event streams.
  void subscribe() {
    if (_subscribed) return;
    _subscribed = true;
    _encryptedAudioSub = _shield.onEncryptedAudioReady.listen(
      _handleEncryptedAudio,
      onError: (e) => _logError('onEncryptedAudioReady stream error', e),
    );

    _sosTriggeredSub = _shield.onSoSTriggered.listen(
      _handleSoSTriggered,
      onError: (e) => _logError('onSoSTriggered stream error', e),
    );

    _recordingStateSub = _shield.onRecordingStateChanged.listen(
      _handleRecordingStateChanged,
      onError: (e) => _logError('onRecordingStateChanged stream error', e),
    );

    _monitoringStateSub = _shield.onMonitoringStateChanged.listen(
      _handleMonitoringStateChanged,
      onError: (e) => _logError('onMonitoringStateChanged stream error', e),
    );

    _errorSub = _shield.onError.listen(
      _handleError,
      onError: (e) => _logError('onError stream error', e),
    );

    _permissionStatusSub = _shield.onPermissionStatusChanged.listen(
      _handlePermissionStatusChanged,
      onError: (e) => _logError('onPermissionStatusChanged stream error', e),
    );

    _accessibilityServiceSub = _shield.onAccessibilityServiceStatus.listen(
      _handleAccessibilityServiceStatus,
      onError: (e) => _logError('onAccessibilityServiceStatus stream error', e),
    );

    _instrumentationSub = _shield.onInstrumentationEvent.listen(
      _handleInstrumentationEvent,
      onError: (e) => _logError('onInstrumentationEvent stream error', e),
    );

    _notificationActionSub = _shield.onNotificationAction.listen(
      _handleNotificationAction,
      onError: (e) => _logError('onNotificationAction stream error', e),
    );
  }

  /// Cancels all plugin event stream subscriptions. Idempotent — safe to call
  /// from any teardown path (dispose / re-init / disable) and more than once.
  void cancel() {
    if (!_subscribed) return;
    _subscribed = false;
    _safeCancel(_encryptedAudioSub, 'onEncryptedAudioReady');
    _safeCancel(_sosTriggeredSub, 'onSoSTriggered');
    _safeCancel(_instrumentationSub, 'onInstrumentationEvent');
    _safeCancel(_recordingStateSub, 'onRecordingStateChanged');
    _safeCancel(_monitoringStateSub, 'onMonitoringStateChanged');
    _safeCancel(_errorSub, 'onError');
    _safeCancel(_permissionStatusSub, 'onPermissionStatusChanged');
    _safeCancel(_accessibilityServiceSub, 'onAccessibilityServiceStatus');
    _safeCancel(_notificationActionSub, 'onNotificationAction');
    _encryptedAudioSub = null;
    _sosTriggeredSub = null;
    _instrumentationSub = null;
    _recordingStateSub = null;
    _monitoringStateSub = null;
    _errorSub = null;
    _permissionStatusSub = null;
    _accessibilityServiceSub = null;
    _notificationActionSub = null;
  }

  /// Cancels [sub] and records the async cancel error as a non-fatal. The
  /// Flutter engine throws PlatformException("No active stream to cancel")
  /// when a cancel races native stream teardown; contain it (never fatal) and
  /// tag [stream] so Crashlytics shows which channel raced.
  void _safeCancel(StreamSubscription<dynamic>? sub, String stream) {
    if (sub == null) return;
    unawaited(
      sub.cancel().catchError(
        (Object e, StackTrace st) => FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'shield event-channel cancel: $stream',
          fatal: false,
        ),
      ),
    );
  }

  // ── Handlers ────────────────────────────────────────

  Future<void> _handleEncryptedAudio(EncryptedAudioEvent event) async {
    _log('onEncryptedAudioReady — file=${event.filePath}, '
        'keyLen=${event.aesSecretKey.length}');

    final uploadQueue = _uploadQueue();
    // Snapshot jobId BEFORE any await — onWidgetChanged can null it out during
    // a yield point (file.readAsBytes etc.), causing a NullCheckError later.
    final jobId = _currentJobId();
    if (uploadQueue == null || jobId == null) {
      _log('SKIP encrypted audio — '
          'queue=${uploadQueue != null}, jobId=$jobId');
      MonitoringServiceHelper.logWarning(
        'shield_clip_dropped_no_job',
        {
          'reason': 'job_id_null_at_receipt',
          'queue_ready': uploadQueue != null,
          'file': event.filePath,
        },
      );
      _trackShieldEvent(TrackingEvents.expertShieldUploadDropped, {
        'reason': 'job_id_null_at_receipt',
      });
      return;
    }

    try {
      final file = File(event.filePath);
      if (!await file.exists()) {
        _log('ERROR encrypted audio file not found: ${event.filePath}');
        _logError('Encrypted audio file not found', event.filePath);
        return;
      }
      final encryptedBytes = await file.readAsBytes();
      _log('read ${encryptedBytes.length} encrypted bytes');

      final encryptor = _encryptor();
      if (encryptor == null) {
        _log('ERROR RSA encryptor not initialized');
        _logError('RSA encryptor not initialized', 'Cannot wrap AES key');
        return;
      }
      final wrappedKey = encryptor.wrapAesKey(event.aesSecretKey);
      _log('AES key wrapped (${wrappedKey.length} chars)');

      final metadata = ShieldEncryptionMetadata(
        encryptedKey: wrappedKey,
        iv: event.iv,
        authTag: event.authTag,
        isCompressed: true,
      );

      final duration = _getRecordingDuration();
      final isSos = _shieldProvider.isSOSMode;
      _log('enqueuing upload — jobId=$jobId, '
          'dur=${duration}s, sos=$isSos');
      await uploadQueue.enqueue(
        bookingId: jobId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        encryptedAudioBytes: encryptedBytes,
        encryptionMetadata: metadata,
        durationSeconds: duration,
        isSos: isSos,
      );
      _log('upload enqueued');

      await _shield.discardAESKey();

      try {
        await file.delete();
      } catch (e) {
        _log('delete encrypted file error: $e');
      }
    } catch (e, st) {
      _log('ERROR processing encrypted audio: $e');
      await MonitoringServiceHelper.logCriticalError(
        'SafetyShieldAdapter: Failed to process encrypted audio',
        {
          'error': e.toString(),
          'stack_trace': st.toString(),
          'job_id': _currentJobId(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Future<void> _handleSoSTriggered(SoSTriggeredEvent event) async {
    _log('onSoSTriggered — source=${event.source.name}, '
        'type=${event.triggerType.name}');

    final triggerType = event.triggerType.name != 'ml' ? 'non_ml' : 'ml';
    final apiSource = _mapSoSSourceToApi(event.source);
    await _sosCoordinator.initiateSosAndShowSheet(
      apiSource: apiSource,
      triggerType: triggerType,
    );
    if (event.source == SoSSource.manual) {
      _sosCoordinator.completeManualSosIfPending();
    }
  }

  void _handleRecordingStateChanged(RecordingStateEvent event) {
    _log('onRecordingStateChanged — ${event.state.name}');
    // IG-10: capture paused state before provider update so the recording
    // case can distinguish a resume from a fresh start.
    final wasPaused = _shieldProvider.isRecorderPaused;
    switch (event.state) {
      case RecordingState.idle:
        _shieldProvider.setRecordingState(isRecording: false);
        _shieldProvider.setShieldRecording(false);
      case RecordingState.recording:
        _shieldProvider.setRecordingState(isRecording: true);
        _shieldProvider.setShieldRecording(true);
        // IG-07 + IG-10: expertShieldStarted / expertShieldResumed fire here on
        // the real native RecordingState.recording confirmation, not on a timer.
        if (wasPaused) {
          _trackShieldEvent(TrackingEvents.expertShieldResumed, {
            'trigger': _activeTrigger()?.value ?? 'unknown',
            'mode': 'recording',
          });
        } else {
          _trackShieldEvent(TrackingEvents.expertShieldStarted, {
            'trigger': _activeTrigger()?.value ?? 'unknown',
            'mode': 'recording',
          });
        }
      case RecordingState.paused:
        _shieldProvider.setRecordingState(
            isRecording: false, isRecorderPaused: true);
        // IG-10: pause transitions were invisible to product analytics
        _trackShieldEvent(TrackingEvents.expertShieldPaused, {
          'reason': 'audio_interruption',
          'trigger': _activeTrigger()?.value ?? 'unknown',
          'mode': 'recording',
        });
    }
  }

  void _handleMonitoringStateChanged(MonitoringStateEvent event) {
    _log('onMonitoringStateChanged — ${event.state.name}');
    switch (event.state) {
      case MonitoringState.idle:
        _shieldProvider.setMonitoringOnly(false);
        _shieldProvider.setPaused(true);
      case MonitoringState.monitoringOnly:
        _shieldProvider.setMonitoringOnly(true);
        _shieldProvider.setPaused(false);
      case MonitoringState.active:
        _shieldProvider.setShieldRecording(true);
        _shieldProvider.setMonitoringOnly(false);
        _shieldProvider.setPaused(false);
    }
  }

  void _handleError(SafetyShieldError error) {
    _log('onError — code=${error.code.name}, '
        'message=${error.message}, details=${error.details}');
    _shieldProvider.setRecordingState(error: error.message);
    _trackShieldEvent(TrackingEvents.expertShieldError, {
      'error_code': error.code.name,
      'error_message': error.message,
      'error_details': error.details,
    });
    MonitoringServiceHelper.logError(
      'SafetyShield plugin error: ${error.code.name}',
      {
        'code': error.code.name,
        'message': error.message,
        'details': error.details,
        'job_id': _currentJobId(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    if (error.code == SafetyShieldErrorCode.modelLoadFailed ||
        error.code == SafetyShieldErrorCode.uncaughtException) {
      FirebaseCrashlytics.instance.recordError(
        Exception('SafetyShield ${error.code.name}: ${error.message}'),
        StackTrace.current,
        reason: error.details ?? 'Safety Shield error',
        fatal: false,
      );
    }
  }

  void _handlePermissionStatusChanged(PermissionStatusEvent event) {
    _log('onPermissionStatusChanged — '
        '${event.permission.name}=${event.status.name}');
    MonitoringServiceHelper.logInfo(
      'SafetyShield permission changed',
      {
        'permission': event.permission.name,
        'status': event.status.name,
        'job_id': _currentJobId(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    // IG-11: permission changes were routed only to Coralogix, never to
    // product analytics (Mixpanel/CleverTap).
    _trackShieldEvent(TrackingEvents.expertShieldPermissionChanged, {
      'permission': event.permission.name,
      'status': event.status.name,
      'context': 'runtime_change',
    });
  }

  void _handleAccessibilityServiceStatus(AccessibilityServiceEvent event) {
    _log('onAccessibilityServiceStatus — ${event.status.name}');
    MonitoringServiceHelper.logInfo(
      'SafetyShield accessibility service status',
      {
        'status': event.status.name,
        'job_id': _currentJobId(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ── Instrumentation forwarding (two-plane telemetry) ────────────────
  //
  // Plane 1 — Observability (Coralogix, via MonitoringServiceHelper.logInfo):
  //   full-fidelity operational + ML-signal telemetry for threshold validation.
  // Plane 2 — Product analytics (Mixpanel/CleverTap, via _trackShieldEvent):
  //   debounced milestone subset only — never the high-frequency signal stream.

  /// Maps native instrumentation event keys → CT/MP product analytics event names.
  /// Keys define the milestone subset forwarded to the product analytics plane.
  /// All other native events go to Coralogix only (via `shield_<key>` name).
  static const Map<String, String> _nativeToProductEvent = {
    TrackingEvents.nativeKeySosTriggered:
        TrackingEvents.expertShieldNativeSosTriggered,
    TrackingEvents.nativeKeySosResolved:
        TrackingEvents.expertShieldNativeSosResolved,
    TrackingEvents.nativeKeyRecordingState:
        TrackingEvents.expertShieldNativeRecordingState,
    TrackingEvents.nativeKeyMonitoringState:
        TrackingEvents.expertShieldNativeMonitoringState,
    TrackingEvents.nativeKeyBurstRecording:
        TrackingEvents.expertShieldNativeBurstRecording,
    TrackingEvents.nativeKeySessionLifecycle:
        TrackingEvents.expertShieldNativeSessionLifecycle,
    TrackingEvents.nativeKeyPluginLifecycle:
        TrackingEvents.expertShieldNativePluginLifecycle,
    // IG-11: permission_changed was absent from the product analytics plane
    TrackingEvents.nativeKeyPermissionChanged:
        TrackingEvents.expertShieldNativePermissionChanged,
  };

  /// High-frequency events throttled on the observability plane. `detection_signal`
  /// is already throttled plugin-side; `detection_evaluated` (partial match) is not.
  static const Set<String> _coralogixThrottledEvents = {'detection_evaluated'};
  static const int _coralogixThrottleMs = 1000;
  static const int _milestoneDebounceMs = 1000;

  final Map<String, int> _lastCoralogixEmitMs = {};
  final Map<String, int> _lastMilestoneEmitMs = {};

  void _handleInstrumentationEvent(InstrumentationEvent event) {
    _log('onInstrumentationEvent — ${event.eventName} ${event.properties}');

    // Plane 1 — Coralogix (full fidelity; high-freq events throttled).
    if (_shouldForwardToCoralogix(event.eventName)) {
      unawaited(MonitoringServiceHelper.logInfo('shield_${event.eventName}', {
        ...event.properties,
        'job_id': _currentJobId(),
        'native_ts': event.timestamp,
      }));
    }

    // Plane 2 — Mixpanel/CleverTap milestones (debounced).
    // Map lookup both identifies the milestone subset and provides the constant
    // event name — no string template, fully traceable via TrackingEvents.
    final productEvent = _nativeToProductEvent[event.eventName];
    if (productEvent != null && _shouldEmitMilestone(event.eventName)) {
      _trackShieldEvent(productEvent, {
        ...event.properties,
      });
    }
  }

  bool _shouldForwardToCoralogix(String eventName) {
    if (!_coralogixThrottledEvents.contains(eventName)) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastCoralogixEmitMs[eventName];
    if (last != null && now - last < _coralogixThrottleMs) return false;
    _lastCoralogixEmitMs[eventName] = now;
    return true;
  }

  bool _shouldEmitMilestone(String eventName) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastMilestoneEmitMs[eventName];
    if (last != null && now - last < _milestoneDebounceMs) return false;
    _lastMilestoneEmitMs[eventName] = now;
    return true;
  }

  Future<void> _handleNotificationAction(NotificationActionEvent event) =>
      _sosCoordinator.handleNotificationAction(event);

  // ── Helpers ─────────────────────────────────────────

  /// Returns recording duration based on current mode.
  int _getRecordingDuration() {
    if (_shieldProvider.isSOSMode) {
      return RemoteConfigService.instance
          .getInt(RemoteConfigKeys.shieldSosDurationSecs, defaultValue: 10);
    }
    if (_activeTrigger() == ShieldTrigger.manual) {
      return RemoteConfigService.instance
          .getInt(RemoteConfigKeys.shieldManualDurationSecs, defaultValue: 5);
    }
    return RemoteConfigService.instance
        .getInt(RemoteConfigKeys.shieldDurationSecs, defaultValue: 5);
  }

  /// Maps plugin [SoSSource] to the app [SosSource] enum's API string.
  String _mapSoSSourceToApi(SoSSource source) {
    switch (source) {
      case SoSSource.ml:
        return SosSource.ml.apiValue;
      case SoSSource.accelerometer:
        return SosSource.accelerometer.apiValue;
      case SoSSource.volumeButton:
        return SosSource.volumeButton.apiValue;
      case SoSSource.notificationButton:
        return SosSource.notificationButton.apiValue;
      case SoSSource.manual:
        return SosSource.manual.apiValue;
    }
  }
}
