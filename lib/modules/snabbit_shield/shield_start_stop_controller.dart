// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safety_shield/safety_shield.dart';

import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

import 'shield_battery_check.dart';
import 'shield_consent_provider.dart';
import 'shield_rc_gates.dart';
import 'snabbit_shield_database.dart';
import 'snabbit_shield_encryptor.dart';
import 'snabbit_shield_provider.dart';
import 'snabbit_shield_upload_queue.dart';
import 'sos_flow_coordinator.dart';

/// Manages the start/stop gate chain and job lifecycle for Snabbit Shield.
///
/// Follows the callback-injection coordinator pattern (same as
/// [SosFlowCoordinator]).
class ShieldStartStopController {
  // ── Dependencies (via constructor) ──────────────────
  final SafetyShield _shield;
  final SnabbitShieldProvider _shieldProvider;
  final ShieldConsentProvider _consentProvider;
  final SosFlowCoordinator _sosCoordinator;
  final void Function(String message) _log;
  final void Function(String message, dynamic error) _logError;
  final void Function(String eventName, [Map<String, dynamic> extra])
      _trackShieldEvent;
  final Map<String, dynamic> Function() _shieldEventProps;
  final Future<bool> Function()
      _ensureInitialized;
  final int? Function() _currentJobId;
  final ShieldUploadQueue? Function() _uploadQueue;
  final ShieldEncryptor? Function() _encryptor;
  final void Function(bool active) _persistManualMonitoringFlag;
  final void Function(bool value) _setInitialized;
  final UserProfile? Function() _userProfileUser;

  // ── Mutable State ───────────────────────────────────

  /// Reentrance guard for [startShield].
  bool _startShieldInProgress = false;

  /// How recording was started. Read by the event handler to determine
  /// recording duration.
  ShieldTrigger? activeTrigger;

  ShieldStartStopController({
    required SafetyShield shield,
    required SnabbitShieldProvider shieldProvider,
    required ShieldConsentProvider consentProvider,
    required SosFlowCoordinator sosCoordinator,
    required void Function(String message) log,
    required void Function(String message, dynamic error) logError,
    required void Function(String eventName, [Map<String, dynamic> extra])
        trackShieldEvent,
    required Map<String, dynamic> Function() shieldEventProps,
    required Future<bool> Function()
        ensureInitialized,
    required int? Function() currentJobId,
    required ShieldUploadQueue? Function() uploadQueue,
    required ShieldEncryptor? Function() encryptor,
    required void Function(bool active) persistManualMonitoringFlag,
    required void Function(bool value) setInitialized,
    required UserProfile? Function() userProfileUser,
  })  : _shield = shield,
        _shieldProvider = shieldProvider,
        _consentProvider = consentProvider,
        _sosCoordinator = sosCoordinator,
        _log = log,
        _logError = logError,
        _trackShieldEvent = trackShieldEvent,
        _shieldEventProps = shieldEventProps,
        _ensureInitialized = ensureInitialized,
        _currentJobId = currentJobId,
        _uploadQueue = uploadQueue,
        _encryptor = encryptor,
        _persistManualMonitoringFlag = persistManualMonitoringFlag,
        _setInitialized = setInitialized,
        _userProfileUser = userProfileUser;

  // ── Public API ──────────────────────────────────────

  /// Wraps [onJobStarted] in try-catch so [startShield] always runs,
  /// even when the plugin is not yet initialized.
  Future<void> onJobStartedAndAutoStart(BuildContext context) async {
    try {
      await _shield.onJobStarted();
    } catch (e) {
      _log('onJobStarted() error (pre-init): $e');
      _trackShieldEvent(TrackingEvents.expertShieldError, {
        'error': 'job_started_failed',
        'trigger': 'auto',
        'detail': e.toString(),
      });
    }
    if (!context.mounted) return;
    await _shieldProvider.updateStorageStatus();
    if (!context.mounted) return;
    await startShield(context, trigger: ShieldTrigger.auto);
    // Sync active SOS state on job start (cold-start recovery)
    if (context.mounted) {
      await _sosCoordinator.syncActiveSosState(context);
    }
  }

  /// Gate chain: job → init → consent → battery → storage → permissions → start.
  Future<void> startShield(
    BuildContext context, {
    required ShieldTrigger trigger,
  }) async {
    if (_startShieldInProgress) {
      _log('_startShield already in progress — skipping ($trigger)');
      return;
    }
    _startShieldInProgress = true;
    _log('startShield | trigger=$trigger jobId=${_currentJobId()}');
    try {
      // Gate 0: Job ID
      _log('Gate0:job | id=${_currentJobId()} → ${_currentJobId() == null ? "BLOCK" : "pass"}');
      if (_currentJobId() == null) return;
      // Restore isMonitoringOnly from native on cold-start — stream events don't re-fire on reconnect.
      final nativeState = await _shield.getShieldState();
      if (nativeState == SafetyState.monitoringOnly && !_shieldProvider.isMonitoringOnly) {
        _shieldProvider.setMonitoringOnly(true);
      }
      // Unified desync check — always verify native state matches provider
      final actualState = await _shield.getRecordingState();
      if (_shieldProvider.isShieldRecording && actualState == RecordingState.idle) {
        // Provider thinks active but native is idle — reset
        _log('State desync — provider active but native idle. Resetting.');
        MonitoringServiceHelper.logWarning(
          'SafetyShieldAdapter: State desync — provider active but native idle',
          {
            'job_id': _currentJobId(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        _shieldProvider.reset();
      } else if (!_shieldProvider.isShieldRecording &&
          !_shieldProvider.isMonitoringOnly &&
          actualState != RecordingState.idle) {
        _log(
            'State desync — provider idle but native ${actualState.name}. Syncing.');
        _shieldProvider.setRecordingState(
          isRecording: actualState == RecordingState.recording,
        );
        _shieldProvider.setShieldRecording(true);
        activeTrigger = trigger;
        // Don't return — fall through so manual/sos triggers can start monitoring.
        // Gates below are idempotent safety checks that won't re-prompt.
      }
      _shieldProvider.clearError();

      // Gate 0: Initialize plugin.
      _log('Gate0:init');
      final initOk = await _ensureInitialized();
      _log('Gate0:init | result=${initOk ? "pass" : "BLOCK"}');
      if (!initOk) {
        _trackShieldEvent(TrackingEvents.expertShieldError, {
          'error': 'init_failed',
          'trigger': trigger.value,
        });
        return;
      }

      // Retry onJobStarted() now that the plugin is initialized so the native
      // side knows a job is active (e.g. enables volume-button SoS).
      if (_currentJobId() != null) {
        try {
          await _shield.onJobStarted();
        } catch (e) {
          _log('onJobStarted() retry after init error: $e');
        }
        // Layer 1a — accel + FGS + SoS button; idempotent, no mic needed
        try {
          final wasAccelOnly = _shieldProvider.isAccelerometerOnly;
          await _shield.startAccelerometerOnly();
          _shieldProvider.setAccelerometerActive(true);
          if (!wasAccelOnly) {
            _trackShieldEvent(TrackingEvents.expertShieldDegradedModeActive, {
              'trigger': trigger.value,
              'mode': 'accelerometer_only',
              'shield_state': 'accelerometer_only',
            });
          }
        } catch (e) {
          _log('Layer 1a start error: $e');
        }
      }

      // Layer 1b — upgrade to ML monitoring when mic is available (RC-gated).
      _log('Gate1b:monitoringOnly | trigger=$trigger');
      if (!ShieldRcGates.monitoringOnlyEnabled()) {
        _log('Gate1b:monitoringOnly | gated off by remote config');
        return;
      }

      // Gate 1: Consent
      _log('Gate1:consent');
      final hasConsent = await _consentProvider.ensureConsent(
          context, _userProfileUser(),
          eventProps: _shieldEventProps());
      _log('Gate1:consent | result=${hasConsent ? "pass" : "BLOCK"}');
      if (!hasConsent || !context.mounted) {
        if (!hasConsent) {
          _trackShieldEvent(TrackingEvents.expertShieldError, {
            'error': 'consent_denied',
            'trigger': trigger.value,
          });
        }
        return;
      }

      try {
        var micStatus =
        await _shield.checkPermission(SafetyPermission.microphone);
        if (micStatus != SafetyPermissionStatus.granted &&
            trigger != ShieldTrigger.auto) {
          await _shield.requestPermission(SafetyPermission.microphone);
          micStatus =
          await _shield.checkPermission(SafetyPermission.microphone);
        }
        if (micStatus != SafetyPermissionStatus.granted) {
          _log('Gate1b:monitoringOnly | skipped (mic denied)');
        } else {
          final wasMonitoringOnly = _shieldProvider.isMonitoringOnly;
          await _shield.startMonitoringOnly();
          _shieldProvider.setMonitoringOnly(true);
          _shieldProvider.setAccelerometerActive(false);
          _log('Gate1b:monitoringOnly | started');
          if (!wasMonitoringOnly) {
            _trackShieldEvent(TrackingEvents.expertShieldStarted, {
              'trigger': trigger.value,
              'mode': 'monitoring_only',
              'shield_state': 'monitoring_only',
              'mic_available': true,
            });
          }
        }
      } on PlatformException catch (e) {
        _logError('Gate1b:monitoringOnly failed', e);
      } catch (e) {
        _logError('Gate1b:monitoringOnly failed', e);
      }

      // Gate 2: Battery
      _log('Gate2:battery');
      final batteryResult =
          await checkShieldBattery(context, eventProps: _shieldEventProps());
      _log('Gate2:battery | result=$batteryResult → ${batteryResult == BatteryCheckResult.blocked ? "BLOCK" : "pass"}');
      if (batteryResult == BatteryCheckResult.blocked || !context.mounted) {
        if (batteryResult == BatteryCheckResult.blocked) {
          _trackShieldEvent(TrackingEvents.expertShieldError, {
            'error': 'battery_too_low',
            'trigger': trigger.value,
          });
        }
        return;
      }

      // RC gate: recording/monitoring tier. When off, stop at the monitoring
      // layer (1b if enabled, else 1a) — no clips, no full monitoring. SoS still
      // functions from the lower layer (recording-free by native design).
      if (!ShieldRcGates.recordingEnabled()) {
        _log('GateRC:recording | gated off by remote config');
        return;
      }

      // Gate 3: Storage
      _log('Gate3:storage | checking...');
      await _shieldProvider.updateStorageStatus();
      _log('Gate3:storage | lowStorage=${_shieldProvider.isLowStorage} → ${_shieldProvider.isLowStorage ? "BLOCK" : "pass"}');
      if (_shieldProvider.isLowStorage || !context.mounted) {
        if (_shieldProvider.isLowStorage) {
          _trackShieldEvent(TrackingEvents.expertShieldError, {
            'error': 'storage_insufficient',
            'trigger': trigger.value,
          });
          _trackShieldEvent(TrackingEvents.expertShieldStorageFull, {
            'trigger': trigger.value,
          });
        }
        return;
      }

      // Gate 5: Encryptor
      _log('Gate5:encryptor | null=${_encryptor() == null} → ${_encryptor() == null ? "BLOCK" : "pass"}');
      if (_encryptor() == null) {
        _trackShieldEvent(TrackingEvents.expertShieldError, {
          'error': 'encryptor_failed',
          'trigger': trigger.value,
        });
        return;
      }

      // Gate 6: Upload queue
      _log('Gate6:uploadQueue | checking...');
      var uploadQueue = _uploadQueue();
      if (uploadQueue == null) {
        // main.dart init may have failed — try lazy init
        _log('Gate6:uploadQueue | null — attempting lazy init');
        try {
          await ShieldDatabase.instance.initialize();
          uploadQueue = ShieldUploadQueue(db: ShieldDatabase.instance);
          uploadQueue.start();
          GlobalState().shieldUploadQueue = uploadQueue;
          _log('Gate6:uploadQueue | lazily initialized → pass');
        } catch (e) {
          _log('Gate6:uploadQueue | lazy init failed: $e → BLOCK');
        }
      }
      if (uploadQueue == null) {
        _log('Gate6:uploadQueue | null → BLOCK');
        _trackShieldEvent(TrackingEvents.expertShieldError, {
          'error': 'upload_queue_null',
          'trigger': trigger.value,
        });
        return;
      }
      _log('Gate6:uploadQueue | pass');

      // All gates passed — start recording and monitoring with recovery.
      // started tracks whether any attempt succeeded so activeTrigger is
      // only written on success (prevents stale trigger on failed starts).
      var started = false;
      try {
        await _startRecordingAndMonitoring(trigger);
        started = true;
      } on PlatformException catch (e) {
        if (e.code == 'serviceNotRunning') {
          _log('serviceNotRunning — re-initializing plugin and retrying');
          _logError('serviceNotRunning during start', e);
          _setInitialized(false);
          final reinitOk =
              await _ensureInitialized();
          if (reinitOk) {
            if (_currentJobId() != null) {
              try {
                await _shield.onJobStarted();
              } catch (e) {
                _log('onJobStarted() in serviceNotRunning recovery: $e');
              }
              try {
                await _shield.startAccelerometerOnly();
                _shieldProvider.setAccelerometerActive(true);
              } catch (e) {
                _log('startAccelerometerOnly() in serviceNotRunning recovery: $e');
              }
            }
            try {
              await _startRecordingAndMonitoring(trigger);
              started = true;
            } catch (retryError) {
              _log('retry after re-init failed: $retryError');
              _logError('startRecordingAndMonitoring retry failed', retryError);
              // IG-09: retry-after-reinit failure was invisible to product analytics
              _trackShieldEvent(TrackingEvents.expertShieldError, {
                'error': 'reinit_retry_failed',
                'error_message': retryError.toString(),
                'trigger': trigger.value,
              });
            }
          } else {
            _log('re-initialization failed — cannot recover');
            // IG-09: re-init failure was invisible to product analytics
            _trackShieldEvent(TrackingEvents.expertShieldError, {
              'error': 'reinit_failed',
              'trigger': trigger.value,
            });
          }
        } else {
          _log('PlatformException during start: ${e.code} — ${e.message}');
          _logError('startRecordingAndMonitoring PlatformException', e);
          // IG-08: non-serviceNotRunning PlatformException path was invisible to product analytics
          _trackShieldEvent(TrackingEvents.expertShieldError, {
            'error': 'start_failed',
            'error_type': 'platform_exception',
            'error_code': e.code,
            'trigger': trigger.value,
          });
        }
      } catch (e) {
        _log('startRecordingAndMonitoring error: $e');
        _logError('startRecordingAndMonitoring failed', e);
        // IG-08: generic exception path was invisible to product analytics
        _trackShieldEvent(TrackingEvents.expertShieldError, {
          'error': 'start_failed',
          'error_type': 'generic_exception',
          'error_message': e.toString(),
          'trigger': trigger.value,
        });
      }

      // IG-07: activeTrigger written only on success so ShieldEventHandler
      // reads the correct trigger when expertShieldStarted fires natively.
      if (started) {
        activeTrigger = trigger;
        if (trigger == ShieldTrigger.manual) {
          _persistManualMonitoringFlag(true);
        }
      }
      // expertShieldStarted is intentionally NOT fired here.
      // It is fired in ShieldEventHandler._handleRecordingStateChanged when
      // RecordingState.recording is received from the native side.
    } finally {
      _startShieldInProgress = false;
    }
  }

  /// Stops monitoring and recording, resets provider state.
  Future<void> stopShield() async {
    _log('_stopShield()');
    // Independent try per call so a stopMonitoring failure cannot skip
    // stopRecording. Expected idempotent codes (serviceNotRunning / invalidState)
    // stay at debug level — those were the source of 137K Coralogix noise.
    // Unexpected errors (platform bugs, unknown codes) are surfaced so real
    // failures are not silently swallowed.
    await _stopShieldGuard(execute: () async {
      await _shield.stopMonitoring();
    }, service: "Monitoring");

    await _stopShieldGuard(execute: () async {
      await _shield.stopRecording();
    }, service: "Recording");

    _shieldProvider.reset();
    _shieldProvider.setAccelerometerActive(false);
    _setInitialized(false);
  }

  Future<void> _stopShieldGuard({required Future<void> Function() execute, required String service}) async {
    try {
      await execute();
    } on PlatformException catch (e) {
      if (e.code == 'serviceNotRunning' || e.code == 'invalidState') {
        _log('stop$service expected no-op (${e.code})');
      } else {
        _logError('stop$service unexpected error (${e.code})', e);
      }
    } catch (e) {
      _logError('stop$service failed', e);
    }
  }

  /// Cleans up shield state when a job ends.
  Future<void> onJobEnded({
    required bool Function() pendingManualStartAfterPermission,
    required void Function() clearPendingManualStart,
  }) async {
    _log('JOB ENDED — active=${_shieldProvider.isShieldRecording}');
    _sosCoordinator.cancelDeterrence();
    clearPendingManualStart();
    if (_shieldProvider.isShieldRecording || _shieldProvider.isMonitoringOnly) {
      _trackShieldEvent(TrackingEvents.expertShieldStopped, {
        'reason': 'job_ended',
        'trigger': activeTrigger?.value ?? 'unknown',
        'mode': _shieldProvider.isRecording
            ? 'recording'
            : _shieldProvider.isMonitoringOnly
                ? 'monitoring_only'
                : 'accelerometer_only',
      });
    }
    activeTrigger = null;
    _persistManualMonitoringFlag(false);
    _shieldProvider.setAccelerometerActive(false);
    await stopShield();
    try {
      await _shield.onJobEnded();
    } catch (e) {
      _log('onJobEnded (ignored): $e');
    }
    _setInitialized(false);
  }

  // ── Private Helpers ─────────────────────────────────

  /// Starts recording (if not already) and monitoring (for manual/sos triggers).
  /// Throws on failure — caller handles recovery.
  Future<void> _startRecordingAndMonitoring(ShieldTrigger trigger) async {
    if (!_shieldProvider.isRecording) {
      _log('startRecording() called');
      await _shield.startRecording();
    }
    // MONITORING_ONLY→MONITORING was handled by startRecording above;
    // isShieldRecording is event-stream driven and may not have arrived yet —
    // also guard on isMonitoringOnly (synchronously set) so the redundant
    // startMonitoring() call is skipped on the manual-activation upgrade path.
    if (_shieldProvider.isShieldRecording || _shieldProvider.isMonitoringOnly) return;
    // Start monitoring for ALL triggers (including auto) so the ML pipeline and
    // accelerometer detection run on auto-started shifts, not only manual/SOS.
    // ML inference itself is gated natively by mlDetectionEnabled, which is
    // cohort-controlled via Remote Config — so this does not turn ML on by
    // itself; it ensures monitoring is active wherever ML is permitted.
    _log('starting monitoring ($trigger)');
    await _shield.startMonitoring();
  }
}
