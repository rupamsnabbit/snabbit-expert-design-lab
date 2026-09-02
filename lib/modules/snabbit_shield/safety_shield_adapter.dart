import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safety_shield/safety_shield.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/sos.dart';

import 'shield_battery_check.dart';
import 'shield_consent_provider.dart';
import 'shield_deterrence_audio.dart';
import 'shield_event_handler.dart';
import 'shield_rc_gates.dart';
import 'shield_start_stop_controller.dart';
import 'snabbit_shield_encryptor.dart';
import 'snabbit_shield_provider.dart';
import 'snabbit_shield_upload_queue.dart';
import 'shield_sos_push_store.dart';
import 'sos_flow_coordinator.dart';
import 'yamnet_classes.dart';
import 'shield_ui_prompts.dart';

/// Bridges the [SafetyShield] plugin facade to app-side infrastructure.
///
/// Single interaction point for Snabbit Shield:
/// subscribes to plugin event streams and routes them to the upload queue,
/// UI provider, analytics, and monitoring services.
class SafetyShieldAdapter {
  // ── Constants ───────────────────────────────────────
  static const _widgetJobInProgress = 'RUNNER_JOB_IN_PROGRESS';

  // ── Fields & Constructor ──────────────────────────

  final UserProfileProvider _userProfile;
  final ShieldUploadQueue? _uploadQueue;
  SharedPreferences? prefs;

  /// Exposed for the widget tree (ChangeNotifierProvider.value).
  final SnabbitShieldProvider shieldProvider = SnabbitShieldProvider();
  final ShieldConsentProvider consentProvider = ShieldConsentProvider();

  final SafetyShield _shield = SafetyShield.instance;
  final ShieldDeterrenceAudio _deterrence = ShieldDeterrenceAudio();

  /// Coordinates all SOS-related flows (initiate, confirm, deny, sync, deterrence).
  late final SosFlowCoordinator _sosCoordinator;

  /// Routes plugin event streams to upload queue, UI provider, analytics.
  late final ShieldEventHandler _eventHandler;

  /// Manages the start/stop gate chain and job lifecycle.
  late final ShieldStartStopController _startStopController;

  // RSA encryptor for wrapping AES keys before upload
  ShieldEncryptor? _encryptor;

  // ── Tracked Widget State ──────────────────────────

  void _updateContext(BuildContext context) {
    _sosCoordinator.lastContext = context;
  }

  /// Widget name from the previous `onWidgetChanged` call (job lifecycle).
  String? _prevWidgetName;

  /// Current widget name reported by the backend (e.g. RUNNER_JOB_IN_PROGRESS).
  String? _currentWidgetName;

  /// Active job id; null when no job is in progress.
  int? _currentJobId;

  /// Whether both partner and customer have shield enabled for the current job.
  bool _isShieldEnabled = false;

  /// Tracks previous visibility of the shield banner card.
  bool _wasCardVisible = false;

  /// Tracks previous low-storage + banner-visible state to debounce storage warning events.
  bool _wasStorageWarning = false;

  /// Set when the user opened accessibility settings; triggers manual start on resume.
  bool _pendingManualStartAfterPermission = false;

  /// Whether the native plugin has been initialized.
  bool _initialized = false;

  /// In-flight initialization future to coalesce concurrent `ensureInitialized` calls.
  Future<void>? _initializeFuture;

  /// Whether the backend has auto-start enabled for this job.
  bool _autoEnabled = false;
  bool? _cachedShouldEnableMlDetection;

  static const String _manualMonitoringActiveKey =
      'shield_manual_monitoring_active';

  SafetyShieldAdapter({
    required UserProfileProvider userProfile,
    ShieldUploadQueue? uploadQueue,
    this.prefs,
  })  : _userProfile = userProfile,
        _uploadQueue = uploadQueue {
    _sosCoordinator = SosFlowCoordinator(
      shield: _shield,
      shieldProvider: shieldProvider,
      deterrence: _deterrence,
      log: _log,
      logError: _logError,
      trackShieldEvent: _trackShieldEvent,
      currentJobId: () => _currentJobId,
      currentWidgetName: () => _currentWidgetName,
      startShield: (context, {required trigger}) =>
          _startStopController.startShield(context, trigger: trigger),
      stopShield: () => _startStopController.stopShield(),
      persistManualMonitoringFlag: _persistManualMonitoringFlag,
    );
    _startStopController = ShieldStartStopController(
      shield: _shield,
      shieldProvider: shieldProvider,
      consentProvider: consentProvider,
      sosCoordinator: _sosCoordinator,
      log: _log,
      logError: _logError,
      trackShieldEvent: _trackShieldEvent,
      shieldEventProps: _shieldEventProps,
      ensureInitialized: _ensureInitialized,
      currentJobId: () => _currentJobId,
      uploadQueue: () => _uploadQueue ?? GlobalState().shieldUploadQueue,
      encryptor: () => _encryptor,
      persistManualMonitoringFlag: _persistManualMonitoringFlag,
      setInitialized: (value) {
        if (!value) _eventHandler.cancel();
        _initialized = value;
      },
      userProfileUser: () => _userProfile.user,
    );
    _eventHandler = ShieldEventHandler(
      shield: _shield,
      shieldProvider: shieldProvider,
      sosCoordinator: _sosCoordinator,
      log: _log,
      logError: _logError,
      trackShieldEvent: _trackShieldEvent,
      currentJobId: () => _currentJobId,
      activeTrigger: () => _startStopController.activeTrigger,
      encryptor: () => _encryptor,
      uploadQueue: () => _uploadQueue ?? GlobalState().shieldUploadQueue,
    );
  }

  // ── Public Getters / Setters ──────────────────────

  set sosProvider(SOSProvider? provider) =>
      _sosCoordinator.sosProvider = provider;

  /// Whether the shield card should be visible in the UI.
  bool get isCardVisible =>
      _isShieldEnabled && _currentWidgetName == _widgetJobInProgress;

  // ── Initialization ────────────────────────────────

  /// Initialize the plugin and subscribe to event streams.
  ///
  /// NOTE: Call only from job-start or user-triggered flows, not on passive page load.
  Future<void> initialize() async {
    await _ensureInitialized();
  }

  /// Ensures the plugin is initialized. Mic permission is no longer gated here;
  /// it is enforced natively per-operation (Layer 1b requires mic, Layer 1a does not).
  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    if (_initializeFuture != null) {
      await _initializeFuture;
      return _initialized;
    }

    final completer = Completer<void>();
    _initializeFuture = completer.future;
    try {
      _log('initialize() called');

      // Load RSA encryptor for AES key wrapping
      try {
        final pem =
            await rootBundle.loadString('assets/keys/shield_public_key.pem');
        _encryptor = ShieldEncryptor.fromPem(pem);
        _log('RSA encryptor loaded');
      } catch (e) {
        _log('ERROR loading RSA public key: $e');
        await MonitoringServiceHelper.logCriticalError(
          'SafetyShieldAdapter: Failed to load RSA public key',
          {
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Initialize plugin with config
      final mlDetectionEnabled = await _resolveMlDetectionEnabled();
      final rcService = RemoteConfigService.instance;
      final isRcAvailable = rcService.isInitialized && rcService.remoteConfig != null;
      if (!isRcAvailable) {
        _trackShieldEvent(TrackingEvents.expertShieldRcFallback, {
          'reason': 'rc_unavailable',
        });
      }
      final config = _buildConfig(mlDetectionEnabledOverride: mlDetectionEnabled);
      _log('initializing plugin — '
          'recDur=${config.recordingDurationSec}s, '
          'recInt=${config.recordingIntervalSec}s, '
          'db=${config.dbSpikeThreshold}, '
          'yamnet=${config.yamnetConfidenceThreshold}, '
          'ml=${config.mlDetectionEnabled}');
      bool initSuccess = false;
      try {
        await _shield.initialize(config);
        _log('plugin initialized');
        initSuccess = true;
      } catch (e) {
        _log('ERROR initializing plugin: $e');
        MonitoringServiceHelper.logError(
          'SafetyShieldAdapter: Plugin init failed',
          {
            'error': e.toString(),
            'job_id': _currentJobId,
            'timestamp': DateTime.now().toIso8601String(),
            'ml_detection_enabled': config.mlDetectionEnabled,
          },
        );

        // Graceful fallback: if native ML init fails, retry with ML disabled
        // so non-ML safety features continue to work.
        if (config.mlDetectionEnabled) {
          final fallbackConfig = _buildConfig(mlDetectionEnabledOverride: false);
          try {
            await _shield.initialize(fallbackConfig);
            _log('plugin initialized with ML disabled fallback');
            initSuccess = true;
            MonitoringServiceHelper.logError(
              'SafetyShieldAdapter: Plugin init recovered with ML disabled',
              {
                'original_error': e.toString(),
                'job_id': _currentJobId,
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          } catch (fallbackError) {
            _log(
                'ERROR initializing plugin with ML disabled fallback: $fallbackError');
            MonitoringServiceHelper.logError(
              'SafetyShieldAdapter: ML-disabled fallback init failed',
              {
                'error': fallbackError.toString(),
                'job_id': _currentJobId,
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          }
        }
      }

      if (!initSuccess) {
        completer.complete();
        _initializeFuture = null;
        return false;
      }

      _eventHandler.subscribe();
      _log('event streams subscribed');

      try {
        await _shield.notifyStreamsReady();
        _log('native notified streams ready');
      } catch (e) {
        _log('ERROR notifying streams ready: $e');
      }

      _initialized = true;
      completer.complete();
      _initializeFuture = null;
      return true;
    } catch (_) {
      completer.complete();
      _initializeFuture = null;
      return false;
    }
  }

  // ── Public API ────────────────────────────────────

  /// Called from didChangeDependencies. Detects job start/end, triggers
  /// auto-start or stop, and shows consent sheet opportunistically.
  void onWidgetChanged(
    BuildContext context, {
    required String? widgetName,
    required Map<String, dynamic>? widgetData,
  }) {
    _updateContext(context);
    _log('onWidgetChanged — widget=$widgetName, '
        'prev=$_prevWidgetName, jobId=${widgetData?['job_id']}');
    _currentWidgetName = widgetName;
    final partnerShieldEnabled = _userProfile.user?.safetyShieldEnabled == true;
    final customerConsentGiven =
        widgetData?['snabbit_shield_consent_enabled'] == true;
    final autoEnabled = widgetData?['snabbit_shield_auto_enabled'] == true;
    final wasShieldEnabled = _isShieldEnabled;
    _isShieldEnabled = partnerShieldEnabled && customerConsentGiven;
    _autoEnabled = autoEnabled;
    // anyValueToInt handles int / double / String from JSON safely.
    // A direct `as int?` cast throws TypeError if the server returns 12345.0.
    final int? incomingJobId = anyValueToInt(widgetData?['job_id']);
    // Capture the outgoing job_id BEFORE overwriting, so stop events carry it.
    final int? outgoingJobId = _currentJobId;
    _currentJobId = incomingJobId;

    // If shield was just disabled, stop any active recording
    if (wasShieldEnabled && !_isShieldEnabled && (shieldProvider.isShieldRecording || shieldProvider.isMonitoringOnly)) {
      _trackShieldEvent(TrackingEvents.expertShieldStopped, {
        'reason': 'shield_disabled',
        'job_id': outgoingJobId,
        'trigger': 'shield_config_changed',
        'mode': shieldProvider.isRecording
            ? 'recording'
            : shieldProvider.isMonitoringOnly
                ? 'monitoring_only'
                : 'accelerometer_only',
      });
      _persistManualMonitoringFlag(false);
      _startStopController.stopShield();
      _prevWidgetName = widgetName;
      return;
    }

    // Lifecycle: detect job start / end
    final bool isJobInProgress = widgetName == _widgetJobInProgress;
    final bool wasJobInProgress = _prevWidgetName == _widgetJobInProgress;

    if (isJobInProgress && !wasJobInProgress) {
      _log(
          'JOB STARTED — enabled=$_isShieldEnabled, jobId=$_currentJobId, autoEnabled=$_autoEnabled');

      if (_isShieldEnabled && _autoEnabled && _currentJobId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          unawaited(_startStopController.onJobStartedAndAutoStart(context));
        });
      } else {
        unawaited(() async {
          // Init first — service must be running before onJobStarted() so isJobActive is set
          final initOk = await _ensureInitialized();
          if (!initOk) return;
          try {
            await _shield.onJobStarted();
          } catch (e) {
            _log('onJobStarted() error: $e');
          }
          // Layer 1a — accelerometer + FGS, no mic needed
          try {
            await _shield.startAccelerometerOnly();
            shieldProvider.setAccelerometerActive(true);
          } catch (e) {
            _log('Layer 1a start error: $e');
          }
          // Layer 1b — requires customer consent (_isShieldEnabled) + runner consent + mic.
          // RC-gated: monitoringOnly kill-switch (default off).
          if (_isShieldEnabled && ShieldRcGates.monitoringOnlyEnabled()) {
            try {
              var micStatus =
                  await _shield.checkPermission(SafetyPermission.microphone);
              final hasRunnerConsent =
                  !consentProvider.needsConsent(_userProfile.user);
              if (hasRunnerConsent) {
                if (micStatus == SafetyPermissionStatus.denied) {
                  micStatus = await _shield.requestPermission(SafetyPermission.microphone);
                }
                if (micStatus == SafetyPermissionStatus.granted) {
                  await _shield.startMonitoringOnly();
                  shieldProvider.setMonitoringOnly(true);
                  shieldProvider.setAccelerometerActive(false);
                }
              }
            } on PlatformException catch (e) {
              _log('Layer 1b start skipped (${e.code})');
            } catch (e) {
              _logError('Layer 1b start error', e);
            }
          }
        }());
        // Sync SOS state on job start — independent of Layer 1a result
        // Covers cold-start recovery when shield is enabled but not auto-started
        if (_isShieldEnabled && _currentJobId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;
            final wasManual = await _wasManualMonitoringActive();
            if (wasManual && !shieldProvider.isShieldRecording) {
              shieldProvider.monitoringAcknowledged = true;
              await _startStopController.startShield(context,
                  trigger: ShieldTrigger.manual);
            }
            if (context.mounted) {
              unawaited(_sosCoordinator.syncActiveSosState(context));
            }
          });
        }
      }
    } else if (!isJobInProgress && wasJobInProgress) {
      _startStopController.onJobEnded(
        pendingManualStartAfterPermission: () =>
            _pendingManualStartAfterPermission,
        clearPendingManualStart: () =>
            _pendingManualStartAfterPermission = false,
      );
    } else if (isJobInProgress &&
        _currentJobId != null &&
        !(shieldProvider.isSOSMode || _sosCoordinator.pendingSosId != null)) {
      final notOperational = !shieldProvider.isShieldRecording &&
          !shieldProvider.isMonitoringOnly &&
          !shieldProvider.isAccelerometerOnly;
      final shieldJustEnabled = !wasShieldEnabled && _isShieldEnabled;
      if (notOperational) {
        // Job in progress but shield is not operational (failed/missed start or
        // process restart) → ensure it starts at its expected state.
        _log('ENSURE OPERATIONAL — shield down mid-job');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          unawaited(_ensureExpectedShieldState(context));
        });
      } else if (shieldJustEnabled && _autoEnabled) {
        // Consent/auto arrived mid-job while a lower layer runs → upgrade.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          unawaited(_startStopController.onJobStartedAndAutoStart(context));
        });
      }
    }

    // Clear stale manual-monitoring flag if no job is active.
    // Skip on cold start (_prevWidgetName == null) so the flag
    // survives until the job screen loads and can read it.
    if (!isJobInProgress && _prevWidgetName != null) {
      _persistManualMonitoringFlag(false);
    }

    _prevWidgetName = widgetName;

    // Track banner visibility transition
    final nowVisible = isCardVisible;
    if (nowVisible && !_wasCardVisible) {
      _trackShieldEvent(TrackingEvents.expertShieldBannerVisible);
    } else if (!nowVisible && _wasCardVisible) {
      _trackShieldEvent(TrackingEvents.expertShieldBannerHidden);
    }
    _wasCardVisible = nowVisible;

    // Track storage warning only on state CHANGE (low → not-low or not-low → low)
    final isStorageWarning = nowVisible && shieldProvider.isLowStorage;
    if (isStorageWarning && !_wasStorageWarning) {
      _trackShieldEvent(TrackingEvents.expertShieldStorageWarning);
    }
    _wasStorageWarning = isStorageWarning;

    // Opportunistic consent check
    if (consentProvider.canShowOnWidget(widgetName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          unawaited(consentProvider.showConsentIfNeeded(
              context, _userProfile.user,
              eventProps: _shieldEventProps()));
        }
      });
    }
  }

  /// Battery + storage checks on app resume.
  Future<void> onAppResumed(BuildContext context) async {
    _updateContext(context);
    _log('onAppResumed — widget=$_currentWidgetName, '
        'active=${shieldProvider.isShieldRecording}, jobId=$_currentJobId, pendingManualStartAfterPermission=$_pendingManualStartAfterPermission');
    if (_currentWidgetName == _widgetJobInProgress && _currentJobId != null) {
      if (shieldProvider.isShieldRecording && context.mounted) {
        await checkShieldBattery(context, eventProps: _shieldEventProps());
        // Re-check mic permission — OS may have revoked it while the app was
        // backgrounded (manual revocation in Settings, or FGS killed on Android).
        // checkPermission is a live OS query, not a cached value.
        if (context.mounted) {
          final micStatus =
              await _shield.checkPermission(SafetyPermission.microphone);
          if (micStatus != SafetyPermissionStatus.granted) {
            _trackShieldEvent(TrackingEvents.expertShieldError, {
              'error': 'mic_permission_revoked',
              'trigger': 'resume',
            });
            MonitoringServiceHelper.logWarning(
              'SafetyShieldAdapter: mic permission revoked mid-session — resetting shield',
              {
                'job_id': _currentJobId,
                'mic_status': micStatus.name,
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
            // Skip reinit if SOS is active — tail still runs for drain + sync.
            if (!(shieldProvider.isSOSMode || _sosCoordinator.pendingSosId != null)) {
              // Cancel existing event subscriptions before resetting init state.
              // Without this, a subsequent ensureInitialized() call creates a
              // second set of subscriptions on the same streams, causing
              // duplicated audio uploads and double SOS triggers.
              _eventHandler.cancel();
              _initialized = false;
              shieldProvider.reset();
              await _startStopController.startShield(context,
                  trigger: ShieldTrigger.auto);
            }
          }
        }
      } else if (shieldProvider.isMonitoringOnly && context.mounted) {
        await checkShieldBattery(context, eventProps: _shieldEventProps());
        if (context.mounted) {
          final micStatus =
              await _shield.checkPermission(SafetyPermission.microphone);
          if (micStatus != SafetyPermissionStatus.granted) {
            _trackShieldEvent(TrackingEvents.expertShieldError, {
              'error': 'mic_permission_revoked',
              'trigger': 'resume',
              'mode': 'monitoring_only',
            });
            MonitoringServiceHelper.logWarning(
              'SafetyShieldAdapter: mic permission revoked in monitoring-only mode',
              {
                'job_id': _currentJobId,
                'mic_status': micStatus.name,
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
            // Skip reinit if SOS is active — tail still runs for drain + sync.
            if (!(shieldProvider.isSOSMode || _sosCoordinator.pendingSosId != null)) {
              // Downgrade MONITORING_ONLY → ACCELEROMETER_ONLY without ending the job.
              // Native stops audio capture and transitions the state machine; the event
              // handler updates provider state via the emitted state events.
              await _shield.downgradeToAccelerometer();
            }
          } else if (context.mounted) {
            // Mic still granted — reconcile to expected: upgrade to
            // MONITORING+RECORDING only if enabled (auto/manual); otherwise stay
            // MONITORING_ONLY (§5 — no unsolicited upgrade).
            await _ensureExpectedShieldState(context);
          }
        }
      } else if (_pendingManualStartAfterPermission &&
          _isShieldEnabled &&
          context.mounted) {
        _pendingManualStartAfterPermission = false;
        await _startStopController.startShield(context,
            trigger: ShieldTrigger.manual);
      } else if (context.mounted) {
        // Cold start / not-yet-running on resume → restore to expected state
        // (present+enabled → MONITORING+RECORDING; present+not-enabled →
        // MONITORING_ONLY; not-present → ACCELEROMETER_ONLY). Idempotent, SOS-guarded.
        await _ensureExpectedShieldState(context);
      }
    }
    if (_currentWidgetName == _widgetJobInProgress && context.mounted) {
      await shieldProvider.updateStorageStatus();
    }
    // Drain any SoS push that arrived while the adapter was unavailable, then
    // reconcile with the backend (the source of truth) for app-kill recovery.
    await _drainPendingSosPush();
    if (context.mounted) {
      unawaited(_sosCoordinator.syncActiveSosState(context));
    }
  }

  /// Ensures the native shield matches the expected state for the current job,
  /// starting/restoring it when below. Idempotent, SOS-guarded, never
  /// downgrades or stops (§17).
  ///
  /// Expected: present (consent) + enabled (auto OR manual activation) →
  /// MONITORING+RECORDING; present + not-enabled → MONITORING_ONLY;
  /// not-present → ACCELEROMETER_ONLY.
  Future<void> _ensureExpectedShieldState(BuildContext context) async {
    if (_currentJobId == null || !context.mounted) return;
    // Never touch layers during an active SOS.
    if (shieldProvider.isSOSMode || _sosCoordinator.pendingSosId != null) return;
    final initOk = await _ensureInitialized();
    if (!initOk || !context.mounted) return;
    final native = await _shield.getShieldState();
    if (native == SafetyState.sosPending ||
        native == SafetyState.sosConfirmed) {
      return;
    }
    if (!context.mounted) return;

    final present = _isShieldEnabled;
    final wasManual = present ? await _wasManualMonitoringActive() : false;
    if (!context.mounted) return;
    final enabled = present && (_autoEnabled || wasManual);

    if (enabled) {
      // present + enabled → MONITORING+RECORDING
      if (native != SafetyState.monitoring) {
        if (wasManual) shieldProvider.monitoringAcknowledged = true;
        await _startStopController.startShield(context,
            trigger: wasManual ? ShieldTrigger.manual : ShieldTrigger.auto);
      }
    } else if (present) {
      // present + not-enabled → MONITORING_ONLY (never auto-upgrade to recording)
      if (native != SafetyState.monitoring &&
          native != SafetyState.monitoringOnly) {
        await _restoreMonitoringOnly(context);
      }
    } else {
      // not-present → ACCELEROMETER_ONLY floor
      if (native == SafetyState.idle) {
        await _restoreAccelerometerOnly(context);
      }
    }
  }

  /// Starts Layer 1a (accelerometer + FGS) to restore/ensure the accel floor.
  Future<void> _restoreAccelerometerOnly(BuildContext context) async {
    try {
      await _shield.onJobStarted();
      await _shield.startAccelerometerOnly();
      shieldProvider.setAccelerometerActive(true);
    } catch (e) {
      _logError('restore accelerometer-only failed', e);
    }
  }

  /// Restores Layer 1b (monitoring-only) on the accel floor when mic is granted.
  Future<void> _restoreMonitoringOnly(BuildContext context) async {
    await _restoreAccelerometerOnly(context);
    if (!context.mounted) return;
    try {
      final mic = await _shield.checkPermission(SafetyPermission.microphone);
      if (mic == SafetyPermissionStatus.granted &&
          ShieldRcGates.monitoringOnlyEnabled()) {
        await _shield.startMonitoringOnly();
        shieldProvider.setMonitoringOnly(true);
        shieldProvider.setAccelerometerActive(false);
      }
    } on PlatformException catch (e) {
      _log('restore monitoring-only skipped (${e.code})');
    } catch (e) {
      _logError('restore monitoring-only failed', e);
    }
  }

  /// Forwards a SoS push action that was persisted while the adapter was not
  /// available (pre-mount / background isolate). Backend reconciliation remains
  /// the source of truth; this just avoids dropping a known action.
  Future<void> _drainPendingSosPush() async {
    final pending = await ShieldSosPushStore.drain();
    if (pending == null) return;
    _log('Draining pending SoS push: ${pending.action}');
    _trackShieldEvent(TrackingEvents.expertShieldSosPushDrained, {
      'sos_id': pending.sosId,
      'action': pending.action,
    });
    try {
      await handleSOSNotification(action: pending.action, sosId: pending.sosId);
    } catch (e) {
      _logError('drainPendingSosPush failed', e);
    }
  }

  /// Called when user taps "Start Monitoring" on the shield card.
  Future<void> onStartMonitoringTapped(BuildContext context) async {
    _log('onStartMonitoringTapped — jobId=$_currentJobId, '
        'enabled=$_isShieldEnabled, active=${shieldProvider.isRecording}');
    _trackShieldEvent(TrackingEvents.expertShieldBannerCta);
    if (_currentJobId == null || !_isShieldEnabled) return;

    // Initialize only on explicit user action; allow prompting for mic permission.
    final initOk = await _ensureInitialized();
    if (!initOk) return;

    if (isAccessibilityEnabledForCluster(_userProfile)) {
      final shouldContinue = await maybeShowAccessibilityDialog(
        context,
        shield: _shield,
        prefs: prefs,
        log: _log,
        trackShieldEvent: _trackShieldEvent,
        setPendingManualStart: (v) => _pendingManualStartAfterPermission = v,
      );
      if (!shouldContinue) return;
    }

    if (!context.mounted) return;
    final confirmed = await maybeShowActivationSheet(context,
        source: ShieldTrigger.manual.value,
        prefs: prefs,
        trackShieldEvent: _trackShieldEvent);
    if (!confirmed) return;
    // isRecording is true only when RecordingState.recording fires (actual audio
    // capture). isShieldRecording is also true in MONITORING_ONLY (set by
    // MonitoringState.active on MONITORING_ONLY entry), which would incorrectly
    // skip startShield and block the MONITORING_ONLY → MONITORING+RECORDING upgrade.
    if (!shieldProvider.isRecording ||
        _startStopController.activeTrigger == ShieldTrigger.auto) {
      _log('User tapped Start Monitoring — starting shield (manual)');
      await _startStopController.startShield(context,
          trigger: ShieldTrigger.manual);
    }
    // activeTrigger is set to manual inside startShield() only on successful native start
    if (_startStopController.activeTrigger == ShieldTrigger.manual) {
      shieldProvider.monitoringAcknowledged = true;
    }
  }

  /// Called when SOS is confirmed by the API (SOS slider).
  Future<void> onSOSTriggered(BuildContext context) async {
    _log('onSOSTriggered — active=${shieldProvider.isShieldRecording}, '
        'jobId=$_currentJobId, consent=${_userProfile.user?.consentGiven}');
    if (_userProfile.user?.consentGiven != true) return;

    final initOk = await _ensureInitialized();
    if (!initOk) return;

    if (!shieldProvider.isShieldRecording && _currentJobId != null) {
      await _startStopController.startShield(context,
          trigger: ShieldTrigger.sos);
    }

    if (shieldProvider.isShieldRecording) {
      try {
        await _shield.triggerManualSoS();
      } catch (e) {
        _log('SoS trigger error: $e');
        _logError('SoS triggerManualSoS failed', e);
      }
      try {
        await _shield.confirmSoS();
      } catch (e) {
        _log('SoS confirm error: $e');
        _logError('SoS confirmSoS failed', e);
      }
      shieldProvider.setSOSMode(true);
      _trackShieldEvent(TrackingEvents.expertShieldSosConfirmed, {
        'action_type': 'sos_slider',
      });
      _sosCoordinator.startDeterrence();
    }
  }

  /// Public helper to directly trigger manual SOS recording via the plugin.
  Future<void> triggerManualSosOnly(BuildContext context) =>
      _sosCoordinator.triggerManualSosOnly(
        context,
        ensureInitialized: _ensureInitialized,
      );

  Future<void> showSosBottomSheet() => _sosCoordinator.initiateSosAndShowSheet(
        apiSource: 'safety_shield_adapter',
        triggerType: 'non_ml',
      );

  /// CleverTap + Mixpanel with standard shield super-properties (for UI that
  /// cannot inject coordinator callbacks, e.g. SOS active screen).
  void logShieldEvent(String eventName,
      [Map<String, dynamic> extra = const {}]) {
    _trackShieldEvent(eventName, extra);
  }

  /// Called from SOSActiveScreen when the user taps "I am safe, end SOS".
  Future<void> deescalateSos() => _sosCoordinator.deescalateSos();

  /// Called when the app moves to background — signals the SOS coordinator
  /// to suppress the alert sheet auto-deny if the OS dismisses it.
  void onAppPaused() => _sosCoordinator.onAppPaused();

  /// Called when the user declares a false alarm.
  void onFalseAlarm() => unawaited(_sosCoordinator.onFalseAlarm());

  /// Handles an SOS push notification received from the backend.
  Future<void> handleSOSNotification({
    required String action,
    required int sosId,
  }) =>
      _sosCoordinator.handleSosNotification(action: action, sosId: sosId);

  /// Stops the plugin and cleans up all subscriptions.
  ///
  /// stopShield() sends stopRecording() to native asynchronously. Cancelling
  /// event subscriptions immediately after would drop the final in-flight
  /// recording clip. Chain cancel() and shutdown() after stopShield completes
  /// so the last clip can be encrypted and enqueued before streams close.
  void dispose() {
    _log('dispose()');
    _sosCoordinator.dispose();
    _startStopController
        .stopShield()
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((_) {})
        .then((_) {
      _eventHandler.cancel();
      unawaited(
          _shield.shutdown().catchError((e) => _log('shutdown() error: $e')));
    });
  }

  // ── Config ────────────────────────────────────────

  /// Builds native plugin config from Remote Config (falls back to defaults).
  SafetyShieldConfig _buildConfig({bool? mlDetectionEnabledOverride}) {
    final rc = RemoteConfigService.instance;
    return SafetyShieldConfig(
      recordingDurationSec:
          rc.getInt(RemoteConfigKeys.shieldDurationSecs, defaultValue: 5),
      recordingIntervalSec:
          rc.getInt(RemoteConfigKeys.shieldPauseSecs, defaultValue: 5),
      dbSpikeThreshold: rc.getDouble(RemoteConfigKeys.shieldDbSpikeThreshold,
          defaultValue: 15.0),
      accelerometerMagnitudeG: rc.getDouble(
          RemoteConfigKeys.shieldAccelerometerMagnitudeG,
          // Recommended fallback: ~2.7 G is the experimentally optimal shake
          // threshold (total magnitude incl. gravity). RC overrides at runtime.
          defaultValue: 2.7),
      accelerometerWindowSec: rc.getDouble(
          RemoteConfigKeys.shieldAccelerometerWindowSec,
          defaultValue: 1.5),
      accelerometerCooldownSec: rc.getInt(
          RemoteConfigKeys.shieldAccelerometerCooldownSec,
          defaultValue: 5),
      accelerometerLpfAlpha: rc.getDouble(
          RemoteConfigKeys.shieldAccelerometerLpfAlpha,
          defaultValue: 0.888),
      accelerometerFreefallThresholdG: rc.getDouble(
          RemoteConfigKeys.shieldAccelerometerFreefallThresholdG,
          defaultValue: 0.4),
      accelerometerFreefallMinMs: rc.getInt(
          RemoteConfigKeys.shieldAccelerometerFreefallMinMs,
          defaultValue: 30),
      accelerometerDropSuppressMs: rc.getInt(
          RemoteConfigKeys.shieldAccelerometerDropSuppressMs,
          defaultValue: 500),
      yamnetConfidenceThreshold: rc.getDouble(
          RemoteConfigKeys.shieldYamnetConfidenceThreshold,
          // Fallback mirrors the safe prod value (0.5). A low bar re-floods, so
          // this default must never regress below prod. RC overrides.
          defaultValue: 0.5),
      // RC-driven (expert_shield_yamnet_target_classes) so the distress class
      // list can be tuned without an app release. Falls back to a safe
      // high-severity set if RC is absent/invalid — a remote failure must never
      // re-open the false-positive flood (the wide 17-class list did).
      yamnetTargetClasses: _resolveYamnetTargetClasses(),
      // Fallback mirrors the safe prod value (3). A wide topK re-floods (a true
      // class ranked 4th+ is almost never a real event). RC overrides.
      yamnetTopK: rc.getInt(RemoteConfigKeys.shieldYamnetTopK, defaultValue: 3),
      vadConfidenceThreshold: rc.getDouble(
          RemoteConfigKeys.shieldVadConfidenceThreshold,
          // Fallback mirrors the strict prod value (0.8) so an RC failure keeps
          // the voice gate tight rather than loosening it. RC overrides.
          defaultValue: 0.8),
      mlDetectionEnabled: mlDetectionEnabledOverride ??
          rc.getBool(RemoteConfigKeys.shieldMlDetectionEnabled,
              defaultValue: false),
      yamnetModelPath: 'assets/ml-models/yamnet.tflite',
      vadModelPath: 'assets/ml-models/silero_vad.onnx',
      yamnetLabelsPath: 'assets/ml-models/yamnet_labels.txt',
      volumeClickCount:
          rc.getInt(RemoteConfigKeys.shieldVolumeClickCount, defaultValue: 3),
      volumeClickWindowSec: rc.getDouble(
          RemoteConfigKeys.shieldVolumeClickWindowSec,
          defaultValue: 1.5),
      monitoringDurationSec:
          rc.getInt(RemoteConfigKeys.shieldManualDurationSecs, defaultValue: 5),
      monitoringIntervalSec:
          rc.getInt(RemoteConfigKeys.shieldManualPauseSecs, defaultValue: 5),
      sosRecordingDurationSec:
          rc.getInt(RemoteConfigKeys.shieldSosDurationSecs, defaultValue: 10),
      sosRecordingIntervalSec:
          rc.getInt(RemoteConfigKeys.shieldSosPauseSecs, defaultValue: 1),
      sosPendingDurationSec: rc.getInt(
          RemoteConfigKeys.shieldSosPendingDurationSecs,
          defaultValue: 5),
      sosPendingIntervalSec: rc.getInt(
          RemoteConfigKeys.shieldSosPendingIntervalSecs,
          defaultValue: 5),
      debugMode: false,
      // Full per-evaluation ML signal telemetry for threshold validation.
      // High-volume — enable only for the pilot cohort via Remote Config.
      diagnosticsMode: rc.getBool(
          RemoteConfigKeys.shieldDiagnosticsEnabled,
          defaultValue: false),
    );
  }

  /// Safe high-severity distress classes used when Remote Config supplies no
  /// valid list. Deliberately narrow: genuine emergencies only, no everyday
  /// impact/percussive sounds. A remote failure falls back here, never to the
  /// old wide list. ("Scream" also matches "Screaming"; "Shout" also matches
  /// "Children shouting" via the plugin's substring match.)
  static const List<String> _safeYamnetTargetClasses = [
    'Screaming',
    'Scream',
    'Shout',
    'Gunshot, gunfire',
    'Machine gun',
    'Explosion',
  ];

  /// Resolves the YAMNet target class list from Remote Config, validated against
  /// the [YamnetClass] enum. Unknown entries are dropped (typo/injection-safe —
  /// an over-broad or malformed label could otherwise match everything and
  /// flood). Falls back to [_safeYamnetTargetClasses] if RC yields nothing valid.
  List<String> _resolveYamnetTargetClasses() {
    final raw = RemoteConfigService.instance.getStringList(
      RemoteConfigKeys.shieldYamnetTargetClasses,
      defaultValue: const [],
    );
    if (raw.isEmpty) return _safeYamnetTargetClasses;

    final validLabels = YamnetClass.values.map((c) => c.label).toSet();
    final valid = raw.where(validLabels.contains).toList();
    final dropped = raw.where((c) => !validLabels.contains(c)).toList();
    if (dropped.isNotEmpty) {
      MonitoringServiceHelper.logWarning(
        'SafetyShieldAdapter: dropped unknown YAMNet target classes from RC',
        {
          'dropped': dropped,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
    // RC present but no valid entries → don't run wide-open; use the safe set.
    return valid.isEmpty ? _safeYamnetTargetClasses : valid;
  }

  Future<bool> _resolveMlDetectionEnabled() async {
    if (_cachedShouldEnableMlDetection != null) {
      return _cachedShouldEnableMlDetection!;
    }

    final rcEnabled = RemoteConfigService.instance.getBool(
        RemoteConfigKeys.shieldMlDetectionEnabled,
        defaultValue: false);
    if (!rcEnabled) {
      _cachedShouldEnableMlDetection = false;
      return false;
    }

    // LiteRT has been unstable on some Android emulators. Disable ML there
    // to protect recording/monitoring flows from native runtime crashes.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.isPhysicalDevice == false) {
          _cachedShouldEnableMlDetection = false;
          _log('ML detection disabled on emulator for stability');
          return false;
        }
      } catch (e) {
        // If device introspection fails, default to enabled so behavior stays
        // aligned with remote config.
        _log(
            'Device info check failed, keeping ML setting from remote config: $e');
      }
    }

    _cachedShouldEnableMlDetection = true;
    return true;
  }

  // ── Helpers ───────────────────────────────────────

  Future<bool> _wasManualMonitoringActive() async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getBool(_manualMonitoringActiveKey) ?? false;
  }

  void _persistManualMonitoringFlag(bool active) {
    final p = prefs;
    if (p != null) {
      active
          ? p.setBool(_manualMonitoringActiveKey, true)
          : p.remove(_manualMonitoringActiveKey);
    } else {
      SharedPreferences.getInstance().then((p) {
        active
            ? p.setBool(_manualMonitoringActiveKey, true)
            : p.remove(_manualMonitoringActiveKey);
      });
    }
  }

  Map<String, dynamic> _shieldEventProps() {
    final user = _userProfile.user;
    return {
      'runner_id': user?.id,
      'cluster_id': user?.clusterId,
      'region_id': user?.regionId,
      'job_id': _currentJobId,
      'consent_given': user?.consentGiven == true ? 'Y' : 'N',
      'storage_limit': shieldProvider.isLowStorage ? 'fail' : 'pass',
      'shield_state': shieldProvider.isSOSMode
          ? 'sos'
          : shieldProvider.isRecording
              ? 'recording'
              : shieldProvider.isMonitoringOnly
                  ? 'monitoring_only'
                  : shieldProvider.isAccelerometerOnly
                      ? 'accelerometer_only'
                      : 'inactive',
      'time': DateTime.now().toIso8601String(),
    };
  }

  void _trackShieldEvent(String eventName,
      [Map<String, dynamic> extra = const {}]) {
    final props = {..._shieldEventProps(), ...extra};
    // Single forward — the central catalog fans this to Mixpanel + CleverTap.
    MixpanelSetup.logEvent(eventName, props);
  }

  /// Logs plugin event stream errors to monitoring service.
  void _logError(String message, dynamic error) {
    _log('###### ERROR: $message — $error');
    MonitoringServiceHelper.logError(
      'SafetyShieldAdapter: $message',
      {
        'error': error?.toString(),
        'job_id': _currentJobId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Debug-only log. Compiled out of release builds.
  void _log(String message) {
    if (kDebugMode) debugPrint('###### [Shield]: $message');
  }
}
