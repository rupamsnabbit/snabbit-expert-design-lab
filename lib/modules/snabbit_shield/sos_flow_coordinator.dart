import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safety_shield/safety_shield.dart';

import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/sos.dart';

import 'shield_deterrence_audio.dart';
import 'snabbit_shield_provider.dart';
import 'ui/shield_alert_bottom_sheet.dart';
import 'ui/sos_active_screen.dart';

/// Encapsulates the SOS flow: initiate, alert sheet, confirm/deny, sync,
/// deterrence, and navigation to the SOS active screen.
///
/// Extracted from [SafetyShieldAdapter] to reduce its size and isolate
/// the SOS concern into a single, testable unit.
class SosFlowCoordinator {
  // ── Constants ────────────────────────────────────────
  static const _widgetJobInProgress = 'RUNNER_JOB_IN_PROGRESS';
  static const _emojiDanger = Text('😰', style: TextStyle(fontSize: 26));
  static const _emojiSafe = Text('😊', style: TextStyle(fontSize: 26));

  // ── Dependencies ────────────────────────────────────
  final SafetyShield _shield;
  final SnabbitShieldProvider _shieldProvider;
  final ShieldDeterrenceAudio _deterrence;
  final void Function(String message) _log;
  final void Function(String message, dynamic error) _logError;
  final void Function(String eventName, [Map<String, dynamic> extra])
      _trackShieldEvent;
  final int? Function() _currentJobId;
  final String? Function() _currentWidgetName;
  final Future<void> Function(BuildContext context,
      {required ShieldTrigger trigger}) _startShield;
  final Future<void> Function() _stopShield;
  final void Function(bool active) _persistManualMonitoringFlag;

  SOSProvider? sosProvider;

  // ── Mutable State ───────────────────────────────────

  /// SOS id returned by the initiate API while the alert sheet is showing.
  int? _pendingSosId;
  int? get pendingSosId => _pendingSosId;

  /// SOS id after the runner confirms (used for false alarm and deescalate API calls).
  int? _confirmedSosId;

  /// Reentrance guard — prevents concurrent SOS initiation (ML + accelerometer simultaneous triggers).
  bool _sosInProgress = false;

  /// Prevents double Navigator.push of SOSActiveScreen on rapid double-confirm.
  bool _sosScreenPushed = false;

  /// Set when a notification/sync resolves the SOS before the user interacts with the sheet.
  bool _sosResolvedExternally = false;

  /// Set by [onAppPaused] while the SOS alert sheet is visible.
  /// Suppresses the [whenComplete] auto-deny so the runner is re-prompted on resume.
  bool _appWasBackgrounded = false;

  /// Reentrance guard for `_syncActiveSosState`.
  bool _isSyncingActiveSos = false;

  /// Set when a native SoS fires while the app is backgrounded and the sheet is
  /// intentionally skipped. Lets _handleSyncInitiated re-show the sheet on resume
  /// despite _pendingSosId already being set from the initiate API call.
  bool _pendingSosMissedForBackground = false;

  /// Completer signalled when the manual-SOS bottom sheet flow finishes.
  Completer<void>? _pendingManualSosCompleter;

  /// Source that triggered the active SOS (accel/ml/manual/volume/backend_sync).
  /// Set on initiation, cleared on resolution (deescalate/deny).
  String? _activeSosSource;

  /// Most recent mounted BuildContext for showing bottom sheets / navigating.
  BuildContext? lastContext;

  SosFlowCoordinator({
    required SafetyShield shield,
    required SnabbitShieldProvider shieldProvider,
    required ShieldDeterrenceAudio deterrence,
    required void Function(String message) log,
    required void Function(String message, dynamic error) logError,
    required void Function(String eventName, [Map<String, dynamic> extra])
        trackShieldEvent,
    required int? Function() currentJobId,
    required String? Function() currentWidgetName,
    required Future<void> Function(BuildContext context,
            {required ShieldTrigger trigger})
        startShield,
    required Future<void> Function() stopShield,
    required void Function(bool active) persistManualMonitoringFlag,
  })  : _shield = shield,
        _shieldProvider = shieldProvider,
        _deterrence = deterrence,
        _log = log,
        _logError = logError,
        _trackShieldEvent = trackShieldEvent,
        _currentJobId = currentJobId,
        _currentWidgetName = currentWidgetName,
        _startShield = startShield,
        _stopShield = stopShield,
        _persistManualMonitoringFlag = persistManualMonitoringFlag;

  // ── Public API ──────────────────────────────────────

  /// Called from the SOS triggered event stream.
  Future<void> initiateSosAndShowSheet({
    required String apiSource,
    required String triggerType,
  }) async {
    if (_sosInProgress) {
      _log('initiateSosAndShowSheet: concurrent trigger overridden '
          '(source=$apiSource, type=$triggerType, activeSosId=$_pendingSosId)');
      _trackShieldEvent(TrackingEvents.expertShieldSosConcurrentOverridden, {
        'source': apiSource,
        'trigger_type': triggerType,
        'active_sos_id': _pendingSosId,
      });
      return;
    }
    _sosInProgress = true;
    try {
      await _initiateSosAndShowSheetInternal(
          apiSource: apiSource, triggerType: triggerType);
    } finally {
      _sosInProgress = false;
    }
  }

  Future<void> _initiateSosAndShowSheetInternal({
    required String apiSource,
    required String triggerType,
  }) async {
    // This SOS starts unresolved; a concurrent notification deny/confirm/sync
    // flips this true, which the pre-show guard below uses to skip a stale sheet.
    _sosResolvedExternally = false;
    _shieldProvider.capturePreSosState();
    // Consent present (monitoring/recording layer active) → native upgrades to
    // MONITORING+RECORDING at SoS initiation; reflect it on the Kavach card now and
    // persist. Accelerometer-only (no consent) → API/alert only, no activation.
    if (_shieldProvider.isMonitoringOnly || _shieldProvider.isShieldRecording) {
      _shieldProvider.monitoringAcknowledged = true;
      _persistManualMonitoringFlag(true);
    }
    _activeSosSource = apiSource;
    final data = <String, dynamic>{
      'source': apiSource,
      'trigger_type': triggerType,
      if (_currentJobId() != null) 'job_id': _currentJobId(),
    };
    int? sosId;
    try {
      final initiateResponse = await RunnerHttp.runnerSOSInitiate(data: data);
      _log('initiateResponse status=${initiateResponse?.statusCode}');
      if (initiateResponse?.statusCode == 200) {
        sosId = anyValueToInt(initiateResponse?.data?['sos_id']);
        _pendingSosId = sosId;
        _log('SOS initiated — sosId=$sosId');
      } else {
        _log('SOS initiate failed — status=${initiateResponse?.statusCode}');
        MonitoringServiceHelper.logError(
          'SosFlowCoordinator: SOS initiate failed',
          {
            'status_code': initiateResponse?.statusCode,
            'job_id': _currentJobId(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e, st) {
      _log('SOS initiate exception: $e');
      MonitoringServiceHelper.logError(
        'SosFlowCoordinator: SOS initiate exception',
        {
          'error': e.toString(),
          'stack_trace': st.toString(),
          'job_id': _currentJobId(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }

    if (sosId != null) {
      _trackShieldEvent(TrackingEvents.expertShieldSosInitiated, {
        'source': apiSource,
        'trigger_type': triggerType,
        'sos_id': sosId,
      });
    } else {
      _trackShieldEvent(TrackingEvents.expertShieldSosInitiateFailed, {
        'source': apiSource,
        'trigger_type': triggerType,
        'job_id': _currentJobId(),
      });
    }

    final context = lastContext;
    if (context == null || !context.mounted) {
      _log('WARNING: SOS bottom sheet skipped — '
          'context=${context == null ? "null" : "not mounted"}');
      MonitoringServiceHelper.logError(
        'SosFlowCoordinator: SOS sheet skipped — context unavailable',
        {
          'source': apiSource,
          'trigger_type': triggerType,
          'sos_id': sosId,
          'context_null': context == null,
        },
      );
      _trackShieldEvent(TrackingEvents.expertShieldSosSheetSkipped, {
        'source': apiSource,
        'trigger_type': triggerType,
        'sos_id': sosId,
        'context_null': context == null,
      });
      return;
    }

    // Don't push a sheet onto a backgrounded app — syncActiveSosState re-shows on resume
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _log('SOS bottom sheet skipped — app not in foreground');
      _pendingSosMissedForBackground = true;
      return;
    }

    // A fast notification deny/confirm can resolve this SOS while the initiate
    // API is still in flight — skip showing a now-stale sheet for a resolved SOS.
    if (_sosResolvedExternally) {
      _log('SOS bottom sheet skipped — resolved by a concurrent notification action');
      return;
    }

    try {
      await _showSosAlertSheet(context, sosId);
    } catch (e, st) {
      _log('ERROR showing SOS alert sheet: $e');
      MonitoringServiceHelper.logError(
        'SosFlowCoordinator: SOS alert sheet failed to show',
        {
          'error': e.toString(),
          'stack_trace': st.toString(),
          'source': apiSource,
          'sos_id': sosId,
        },
      );
    }
  }

  /// Handles a notification action from FGS buttons.
  Future<void> handleNotificationAction(NotificationActionEvent event) async {
    _log(
        'onNotificationAction — action=${event.action}, source=${event.source}');
    switch (event.action) {
      case 'confirm':
        await _handleNotificationConfirm(event);
      case 'deny':
        await _handleNotificationDeny(event);
      case 'end_sos':
        await deescalateSos();
        // Pop the SOSActiveScreen ONLY if it was actually pushed. When SOS was
        // handled while the app was backgrounded, the screen is never shown
        // (foreground-only) — an unconditional pop here would pop partner_home
        // instead and unwind to the launch route. Mirrors _completeSosDeny /
        // syncActiveSosState which both guard on _sosScreenPushed.
        if (_sosScreenPushed) {
          _safePop(lastContext);
          _sosScreenPushed = false;
        }
      case 'escalate':
        await _launchDialerFromCoordinator();
    }
  }

  /// Handles an SOS push notification from the backend.
  Future<void> handleSosNotification({
    required String action,
    required int sosId,
  }) async {
    _log('handleSOSNotification — action=$action, '
        'sosId=$sosId, pendingSosId=$_pendingSosId');

    final context = lastContext;
    if (context == null || !context.mounted) return;

    // Reject stale pushes — only process if this matches the active SOS session.
    if (_pendingSosId != null && _pendingSosId != sosId) {
      _log('handleSosNotification: stale push ignored '
          '(incoming=$sosId, pending=$_pendingSosId)');
      return;
    }

    // Push arrived before the Dart SOS flow started — capture pre-SOS baseline now
    if (_pendingSosId == null) _shieldProvider.capturePreSosState();

    // Dismiss the ShieldAlertBottomSheet if it's showing
    _sosResolvedExternally = true;
    // Pop only if the Phase-1 sheet is actually showing (see race note above).
    if (ShieldAlertBottomSheet.isShowing && !_appWasBackgrounded) {
      _safePop(context);
    }
    _pendingSosId = null;

    if (action == 'confirm' || action == 'auto_confirm') {
      await _executeSosConfirm(
        context: context,
        sosId: sosId,
        source: 'notification',
        actionType: action == 'auto_confirm' ? 'backend' : 'notification',
        callApi: false,
        pluginAlreadyRecording: true,
      );
    } else if (action == 'deny' || action == 'expired') {
      await _executeSosDeny(
        context: context,
        sosId: sosId,
        source: 'notification',
        actionType: action == 'expired' ? 'backend' : 'notification',
        callApi: false,
      );
    }
  }

  /// Confirms SoS from the bottom sheet.
  Future<void> onSosConfirmed(BuildContext context, int? sosId,
      {bool dismissBottomSheet = true,
      String actionType = 'bottom_sheet'}) async {
    _pendingSosId = null;
    if (dismissBottomSheet) _safePop(context);

    await _executeSosConfirm(
      context: context,
      sosId: sosId,
      source: 'bottom_sheet',
      actionType: actionType,
      callApi: true,
      pluginAlreadyRecording: false,
    );
  }

  /// Denies SoS from the bottom sheet.
  Future<void> onSosDenied(BuildContext context, int? sosId,
      {bool dismissBottomSheet = true,
      String actionType = 'bottom_sheet'}) async {
    _pendingSosId = null;
    if (dismissBottomSheet) _safePop(context);
    await _executeSosDeny(
      context: context,
      sosId: sosId,
      source: 'bottom_sheet',
      actionType: actionType,
      callApi: true,
    );
  }

  /// Called when the user declares a false alarm from SOSActiveScreen.
  Future<void> onFalseAlarm() async {
    _log('onFalseAlarm — active=${_shieldProvider.isShieldRecording}, '
        'monitoringOnly=${_shieldProvider.isMonitoringOnly}, '
        'sos=${_shieldProvider.isSOSMode}');
    _deterrence.cancel();
    if ((_shieldProvider.isShieldRecording || _shieldProvider.isMonitoringOnly) && _shieldProvider.isSOSMode) {
      final sosId = _confirmedSosId;
      _confirmedSosId = null;
      // Sync deny to backend — native denySoS() only resets local plugin state.
      try {
        await RunnerHttp.runnerSOS(data: {
          if (sosId != null) 'sos_id': sosId,
          'user_action': 'deny',
        });
      } catch (e) {
        _logError('onFalseAlarm deny API failed', e);
      }
      try {
        _shield.denySoS();
      } catch (e) {
        _log('denySoS error: $e');
        _logError('denySoS failed', e);
      }
      final snapshot = _shieldProvider.preSosSnapshot;
      _shieldProvider.clearPreSosState();
      _shieldProvider.setSOSMode(false);
      if (snapshot != null) {
        _shieldProvider.monitoringAcknowledged = snapshot.wasMonitoringAcknowledged;
      }
      _pendingSosMissedForBackground = false;
      _trackShieldEvent(TrackingEvents.expertShieldSosDenied, {
        'action_type': 'false_alarm',
        'sos_id': sosId,
        'source': _activeSosSource ?? 'unknown',
      });
      _activeSosSource = null;
    }
  }

  /// Called from SOSActiveScreen when the user taps "I am safe, end SOS".
  Future<void> deescalateSos() async {
    _log('deescalateSos');
    _deterrence.cancel();

    final sosId = _confirmedSosId;
    _confirmedSosId = null;
    try {
      await RunnerHttp.runnerSOS(data: {
        if (sosId != null) 'sos_id': sosId,
        'user_action': 'dismiss',
      });
    } catch (e) {
      _logError('deescalateSos API failed', e);
      _trackShieldEvent(TrackingEvents.expertShieldSosDeescalateError, {
        'sos_id': sosId,
        'source': _activeSosSource ?? 'unknown',
        'error': e.toString(),
      });
    }

    try {
      await _shield.deescalateSoS();
    } catch (e) {
      _log('deescalateSoS error: $e');
      _logError('deescalateSoS failed', e);
    }

    final snapshot = _shieldProvider.preSosSnapshot;
    _shieldProvider.clearPreSosState();
    _shieldProvider.setSOSMode(false);
    if (snapshot != null) {
      _shieldProvider.monitoringAcknowledged = snapshot.wasMonitoringAcknowledged;
      // §9: consent-backed MONITORING_ONLY origin permanently upgraded to
      // MONITORING+RECORDING — keep the card activated, do NOT downgrade.
      if (snapshot.wasMonitoringOnly) {
        _shieldProvider.setMonitoringOnly(false);
        _shieldProvider.monitoringAcknowledged = true;
        _persistManualMonitoringFlag(true);
      }
      // Stop only if shield was started solely for this SoS (wasn't running before, not accel-only, not monitoring-only)
      if (!snapshot.wasShieldRecording && !snapshot.wasAccelerometerOnly && !snapshot.wasMonitoringOnly && _shieldProvider.isShieldRecording) {
        await _stopShield();
      }
    }
    _pendingSosMissedForBackground = false;
    sosProvider?.reset();
    _trackShieldEvent(TrackingEvents.expertShieldSosDeescalated, {
      'sos_id': sosId,
      'source': _activeSosSource ?? 'unknown',
      'action_type': 'user_dismissed',
    });
    _activeSosSource = null;
  }

  /// Manages the manual SOS trigger flow via the plugin.
  Future<void> triggerManualSosOnly(
    BuildContext context, {
    required Future<bool> Function()
        ensureInitialized,
  }) async {
    _log('triggerManualSosOnly() called');

    final completer = Completer<void>();
    _pendingManualSosCompleter = completer;
    try {
      final initOk = await ensureInitialized();
      if (!initOk) {
        _pendingManualSosCompleter?.complete();
        _pendingManualSosCompleter = null;
        throw Exception(
            'SafetyShield not initialized (mic permission missing).');
      }
      await _shield.triggerManualSoS();
      // Never hang the SoS button: if the plugin doesn't emit the manual
      // onSoSTriggered event within the window, release the awaiter. A late
      // event then finds a null pending completer and is a no-op.
      return completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _log('triggerManualSoS: no SoS event within timeout — releasing awaiter');
          _pendingManualSosCompleter = null;
        },
      );
    } catch (e) {
      _pendingManualSosCompleter?.complete();
      _pendingManualSosCompleter = null;
      _log('triggerManualSoS() error: $e');
      _logError('triggerManualSosOnly failed', e);
      rethrow;
    }
  }

  /// Called from the SOS triggered event stream handler.
  void completeManualSosIfPending() {
    _pendingManualSosCompleter?.complete();
    _pendingManualSosCompleter = null;
  }

  /// Reconciles local SOS state with backend after app kill / restart.
  Future<void> syncActiveSosState(BuildContext context) async {
    if (_currentWidgetName() != _widgetJobInProgress ||
        _currentJobId() == null) {
      return;
    }
    if (_isSyncingActiveSos) return;
    _isSyncingActiveSos = true;
    try {
      final response = await RunnerHttp.runnerSOSActive();
      if (response == null || response.data == null) return;
      if (!context.mounted) return;

      final data = response.data as Map<String, dynamic>;
      final hasActiveSos = data['has_active_sos'] as bool? ?? false;

      if (!hasActiveSos) {
        if (_shieldProvider.isSOSMode) {
          _log('WARNING: local SOS active but backend reports no active SOS — desynced');
          MonitoringServiceHelper.logWarning(
            'SosFlowCoordinator: local/backend SOS state desync',
            {
              'local_sos_mode': true,
              'backend_has_active_sos': false,
              'job_id': _currentJobId(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          _trackShieldEvent(TrackingEvents.expertShieldSosStateDesync, {
            'local_sos_mode': true,
            'backend_has_active_sos': false,
            'job_id': _currentJobId(),
          });
          _deterrence.cancel();
          _shieldProvider.setSOSMode(false);
          sosProvider?.reset();
          if (_sosScreenPushed) {
            _safePop(lastContext);
            _sosScreenPushed = false;
          }
        }
        if (ShieldAlertBottomSheet.isShowing && !_appWasBackgrounded) {
          _sosResolvedExternally = true;
          ShieldAlertBottomSheet.hide(context);
        }
        _pendingSosId = null;
        return;
      }

      final sos = data['sos'] as Map<String, dynamic>?;
      if (sos == null) return;
      final status = sos['status'] as String?;
      final sosId = sos['sos_id'] as int?;
      final phoneNumber = sos['ph_no'] as String?;

      switch (status) {
        case 'initiated':
          await _handleSyncInitiated(context, sosId);
        case 'pending':
          await _handleSyncConfirmed(context, sosId, phoneNumber);
        case 'denied':
          _handleSyncDenied(context);
      }
    } catch (e, st) {
      _log('_syncActiveSosState error: $e');
      MonitoringServiceHelper.logError(
        'SosFlowCoordinator: _syncActiveSosState failed',
        {
          'error': e.toString(),
          'stack_trace': st.toString(),
          'job_id': _currentJobId(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } finally {
      _isSyncingActiveSos = false;
    }
  }

  /// Called when the app moves to background while the SOS alert sheet may be showing.
  /// Prevents [whenComplete] from auto-denying; [syncActiveSosState] re-prompts on resume.
  void onAppPaused() {
    _appWasBackgrounded = true;
  }

  /// Starts deterrence audio (e.g. for direct SOS slider path).
  void startDeterrence() => _startDeterrence();

  /// Cancels deterrence audio (called on job end).
  void cancelDeterrence() {
    _deterrence.cancel();
  }

  /// Disposes the deterrence audio.
  void dispose() {
    _deterrence.dispose();
  }

  // ── Private Helpers ─────────────────────────────────

  Future<void> _showSosAlertSheet(BuildContext context, int? sosId) async {
    final lang = context.read<LanguageProvider>();
    var handled = false;
    _sosResolvedExternally = false;
    _appWasBackgrounded = false;

    // RC-configurable auto-safe timeout. Timer is cancelled immediately on any
    // user interaction (button tap, sheet dismissed by user or notification).
    // When the app is backgrounded, the timer still fires but the callback
    // checks _appWasBackgrounded and skips the auto-deny — the runner will
    // be re-prompted via syncActiveSosState on resume.
    final displaySecs = RemoteConfigService.instance
        .getInt(RemoteConfigKeys.shieldSosAlertDisplaySecs, defaultValue: 20);
    Timer? alertTimer;
    alertTimer = Timer(Duration(seconds: displaySecs), () {
      if (!handled && !_sosResolvedExternally && !_appWasBackgrounded) {
        handled = true; // Prevent whenComplete from also firing deny
        _safePop(context);
        unawaited(onSosDenied(
          context,
          _pendingSosId,
          dismissBottomSheet: false,
          actionType: 'timeout',
        ));
      }
    });

    await ShieldAlertBottomSheet.show(
      context,
      imageUrl: 'snabbit-shield/safety_shield_siren.png'.cdn,
      title: lang.getMessage('shield_alert_title', 'Are you in danger?'),
      primaryButtonText:
          lang.getMessage('shield_alert_primary_bt', 'I am in danger'),
      primaryButtonIcon: _emojiDanger,
      onPrimaryTap: () {
        handled = true;
        _trackShieldEvent(TrackingEvents.expertShieldSosAlertConfirmClick, {
          'sos_id': _pendingSosId,
          'source': _activeSosSource ?? 'unknown',
        });
        onSosConfirmed(context, _pendingSosId);
      },
      secondaryButtonText:
          lang.getMessage('shield_alert_secondary_btn', 'I am safe'),
      secondaryButtonIcon: _emojiSafe,
      onSecondaryTap: () {
        handled = true;
        _trackShieldEvent(TrackingEvents.expertShieldSosAlertDenyClick, {
          'sos_id': _pendingSosId,
          'source': _activeSosSource ?? 'unknown',
        });
        onSosDenied(context, _pendingSosId);
      },
      onShown: () => _trackShieldEvent(TrackingEvents.expertShieldSosAlertBs, {
        'sos_id': sosId,
        'source': _activeSosSource ?? 'unknown',
      }),
    ).whenComplete(() {
      alertTimer?.cancel();
      if (!handled && !_sosResolvedExternally) {
        if (_appWasBackgrounded) {
          // OS dismissed the sheet (incoming call, runner switched apps).
          // Do NOT auto-deny — onAppResumed → syncActiveSosState re-prompts
          // the runner if the SOS is still pending on the backend.
          _log('SOS alert dismissed by OS backgrounding — suppressing auto-deny, '
              'will re-prompt on resume');
          MonitoringServiceHelper.logInfo(
            'SosFlowCoordinator: SOS alert dismissed by OS backgrounding — will re-prompt on resume',
            {
              'sos_id': _pendingSosId,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        } else {
          unawaited(onSosDenied(
            context,
            _pendingSosId,
            dismissBottomSheet: false,
            actionType: 'dismissed',
          ));
        }
      }
      _appWasBackgrounded = false;
    });
  }

  Future<void> _handleNotificationConfirm(NotificationActionEvent event) async {
    final sosId = _pendingSosId;

    _sosResolvedExternally = true;
    final context = lastContext;
    // Pop the Phase-1 sheet ONLY if it's actually on screen. In a fast
    // notification action the sheet may not have rendered yet (race with
    // _showSosAlertSheet); an unconditional pop would pop partner_home →
    // language screen + shield teardown via partner_home.dispose().
    if (ShieldAlertBottomSheet.isShowing && !_appWasBackgrounded) _safePop(context);
    _pendingSosId = null;

    _trackShieldEvent(TrackingEvents.expertShieldSosNotificationConfirmTap, {
      'sos_id': sosId,
      'source': event.source,
      'context_available': context != null && context.mounted,
    });

    // API call and state update run regardless of context — only Navigator.push
    // inside _completeSosConfirm is guarded by context != null.
    await _executeSosConfirm(
      context: context,
      sosId: sosId,
      source: event.source,
      actionType: 'notification_button',
      callApi: true,
      pluginAlreadyRecording: true,
    );
  }

  Future<void> _handleNotificationDeny(NotificationActionEvent event) async {
    final sosId = _pendingSosId;

    _sosResolvedExternally = true;
    final context = lastContext;
    // Pop the Phase-1 sheet ONLY if it's actually on screen. In a fast
    // notification action the sheet may not have rendered yet (race with
    // _showSosAlertSheet); an unconditional pop would pop partner_home →
    // language screen + shield teardown via partner_home.dispose().
    if (ShieldAlertBottomSheet.isShowing && !_appWasBackgrounded) _safePop(context);
    _pendingSosId = null;

    await _executeSosDeny(
      context: context,
      sosId: sosId,
      source: 'notificationAction',
      actionType: 'notification_button',
      callApi: true,
    );
  }

  Future<void> _executeSosConfirm({
    required BuildContext? context,
    required int? sosId,
    required Object source,
    required String actionType,
    required bool callApi,
    required bool pluginAlreadyRecording,
  }) async {
    Response<dynamic>? response;
    if (callApi) {
      try {
        response = await RunnerHttp.runnerSOS(data: {
          if (sosId != null) 'sos_id': sosId,
          'user_action': 'confirm',
        });
        _log('SOS confirm API status=${response?.statusCode}');
        if (response == null) {
          _logError('SOS confirm API returned null', null);
          _trackShieldEvent(TrackingEvents.expertShieldSosConfirmApiFailed, {
            'sos_id': sosId,
            'action_type': actionType,
            'source': _activeSosSource ?? 'unknown',
          });
        }
      } catch (e) {
        _logError('SOS confirm API failed', e);
        _trackShieldEvent(TrackingEvents.expertShieldSosConfirmApiFailed, {
          'sos_id': sosId,
          'action_type': actionType,
          'source': _activeSosSource ?? 'unknown',
          'error': e.toString(),
        });
      }
    }

    if (!pluginAlreadyRecording) {
      try {
        await _shield.triggerManualSoS();
      } catch (e) {
        _log('triggerManualSoS() error: $e');
        _logError('triggerManualSoS failed in _executeSosConfirm', e);
      }
    }

    final phoneNumber = response?.data?['ph_no'] as String?;
    await _completeSosConfirm(
      context: context,
      actionType: actionType,
      sosId: sosId,
      phoneNumber: phoneNumber,
    );
  }

  Future<void> _executeSosDeny({
    required BuildContext? context,
    required int? sosId,
    required String source,
    required String actionType,
    required bool callApi,
  }) async {
    if (callApi) {
      try {
        await RunnerHttp.runnerSOS(data: {
          if (sosId != null) 'sos_id': sosId,
          'user_action': 'deny',
        });
      } catch (e, st) {
        _logError('_executeSosDeny: deny API failed', e);
        MonitoringServiceHelper.logError(
          'SosFlowCoordinator: SOS deny API failed',
          {
            'error': e.toString(),
            'stack_trace': st.toString(),
            'sos_id': sosId,
            'source': source,
            'action_type': actionType,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        _trackShieldEvent(TrackingEvents.expertShieldSosDenyApiFailed, {
          'sos_id': sosId,
          'source': source,
          'action_type': actionType,
          'error': e.toString(),
        });
      }
    }

    _completeSosDeny(context: context, actionType: actionType, sosId: sosId);
  }

  Future<void> _completeSosConfirm({
    required BuildContext? context,
    required String actionType,
    int? sosId,
    String? phoneNumber,
    bool fromSync = false,
  }) async {
    _confirmedSosId = sosId;
    _shieldProvider.setSOSMode(true);

    try {
      await _shield.confirmSoS();
    } catch (e) {
      _log('confirmSoS() error: $e');
      _logError('confirmSoS failed in _completeSosConfirm', e);
    }

    _startDeterrence();

    if (!fromSync) {
      _trackShieldEvent(TrackingEvents.expertShieldSosConfirmed, {
        'action_type': actionType,
        'sos_id': sosId,
        'source': _activeSosSource ?? 'unknown',
      });
    }

    if (phoneNumber != null) {
      sosProvider?.setPhoneNumber(phoneNumber);
    }
    sosProvider?.setStep(SOSStep.postSOS);

    if (context != null && context.mounted && sosProvider != null && !_sosScreenPushed) {
      _sosScreenPushed = true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SOSActiveScreen(
            sosProvider: sosProvider!,
            isOnJob: _currentWidgetName() == _widgetJobInProgress,
            sosId: _confirmedSosId,
            sosSource: _activeSosSource,
          ),
        ),
      ).then((_) => _sosScreenPushed = false);
    }
  }

  void _completeSosDeny({
    required BuildContext? context,
    required String actionType,
    int? sosId,
    bool fromSync = false,
  }) {
    // SOSActiveScreen may be open if backend denies after Phase 2 confirm — pop it.
    if (_sosScreenPushed) {
      _safePop(lastContext);
      _sosScreenPushed = false;
    }
    _confirmedSosId = null;
    final snapshot = _shieldProvider.preSosSnapshot;
    _shieldProvider.clearPreSosState();
    try {
      _shield.denySoS();
    } catch (e) {
      _log('denySoS error: $e');
      _logError('denySoS failed in _completeSosDeny', e);
    }
    _shieldProvider.setSOSMode(false);
    if (snapshot != null) {
      _shieldProvider.monitoringAcknowledged = snapshot.wasMonitoringAcknowledged;
      // Native deny upgrades a consent-backed MONITORING_ONLY origin to MONITORING+RECORDING
      // (no downgrade) — keep the card activated.
      if (snapshot.wasMonitoringOnly) {
        _shieldProvider.setMonitoringOnly(false);
        _shieldProvider.monitoringAcknowledged = true;
        _persistManualMonitoringFlag(true);
      }
      // Stop only if shield was started solely for this SoS (wasn't running before, not accel-only, not monitoring-only)
      if (!snapshot.wasShieldRecording && !snapshot.wasAccelerometerOnly && !snapshot.wasMonitoringOnly && _shieldProvider.isShieldRecording) {
        unawaited(_stopShield().catchError((e) => _logError('_stopShield failed in _completeSosDeny', e)));
      }
    }
    _pendingSosMissedForBackground = false;
    if (!fromSync) {
      _trackShieldEvent(TrackingEvents.expertShieldSosDenied, {
        'action_type': actionType,
        'sos_id': sosId,
        'source': _activeSosSource ?? 'unknown',
      });
    }
    _activeSosSource = null;
  }

  void _startDeterrence() {
    _deterrence.start(
      delaySecs: RemoteConfigService.instance.getInt(
        RemoteConfigKeys.shieldSosDeterrenceDelaySecs,
        defaultValue: 3,
      ),
      isActive: () => _shieldProvider.isSOSMode,
      onPlayed: () => _trackShieldEvent(TrackingEvents.expertShieldDeterrencePlayed, {
        'sos_id': _confirmedSosId,
        'source': _activeSosSource ?? 'unknown',
      }),
    );
  }

  Future<void> _handleSyncInitiated(BuildContext context, int? sosId) async {
    if (_shieldProvider.isSOSMode) return;
    if (ShieldAlertBottomSheet.isShowing) return;
    if (_pendingSosId != null && !_pendingSosMissedForBackground) return;
    _pendingSosMissedForBackground = false;
    _shieldProvider.capturePreSosState();

    if (!_shieldProvider.isShieldRecording) {
      await _startShield(context, trigger: ShieldTrigger.sos);
    } else {
      try {
        await _shield.triggerManualSoS();
      } catch (e) {
        _log('triggerManualSoS() error (sync): $e');
        _logError('triggerManualSoS failed in _handleSyncInitiated', e);
      }
    }

    if (!context.mounted) return;
    _pendingSosId = sosId;

    await _showSosAlertSheet(context, sosId);

    _trackShieldEvent(TrackingEvents.expertShieldSosSynced, {
      'sos_id': sosId,
      'source': _activeSosSource ?? 'backend_sync',
    });
  }

  Future<void> _handleSyncConfirmed(
      BuildContext context, int? sosId, String? phoneNumber) async {
    if (_shieldProvider.isSOSMode) return;

    _sosResolvedExternally = true;
    if (ShieldAlertBottomSheet.isShowing) {
      ShieldAlertBottomSheet.hide(context);
    }
    _pendingSosId = null;

    try {
      await _shield.triggerManualSoS();
    } catch (e) {
      _log('triggerManualSoS() error (sync confirmed): $e');
    }

    _trackShieldEvent(TrackingEvents.expertShieldSosSyncConfirmed, {
      'sos_id': sosId,
      'action_type': 'backend',
      'source': _activeSosSource ?? 'backend_sync',
    });

    await _completeSosConfirm(
      context: context,
      actionType: 'backend',
      sosId: sosId,
      phoneNumber: phoneNumber,
      fromSync: true,
    );
  }

  void _handleSyncDenied(BuildContext context) {
    _sosResolvedExternally = true;
    if (ShieldAlertBottomSheet.isShowing) {
      ShieldAlertBottomSheet.hide(context);
    }
    final syncDeniedSosId = _pendingSosId;
    _pendingSosId = null;

    _deterrence.cancel();
    _trackShieldEvent(TrackingEvents.expertShieldSosSyncDenied, {
      'sos_id': syncDeniedSosId,
      'action_type': 'backend',
      'source': _activeSosSource ?? 'unknown',
    });
    _completeSosDeny(context: context, actionType: 'backend', fromSync: true);
    sosProvider?.reset();
  }

  // Dials the SoS team from a notification button — mirrors _launchDialer on SOSActiveScreen.
  Future<void> _launchDialerFromCoordinator() async {
    final String phone = sosProvider?.phoneNumber ??
        RemoteConfigService.instance.getString(
          RemoteConfigKeys.shieldSosFallbackPhone,
          defaultValue: '',
        );
    _trackShieldEvent(TrackingEvents.expertShieldSosActiveCallTeamCta, {
      'source': 'fgs_notification',
      'sos_id': _confirmedSosId,
    });
    try {
      await CallUtils.handleCallInitiation(
        phoneNumber: phone,
        context: lastContext,
        callSourceLabel: 'SOS_FGS_NOTIFICATION',
        onFailure: ({e, st}) {
          MonitoringServiceHelper.logError('SOS_CALL_FAILED_NOTIFICATION', {
            'error': e?.toString(),
            'stack_trace': st?.toString(),
          });
        },
      );
    } catch (e, st) {
      MonitoringServiceHelper.logError('SOS_CALL_FAILED_NOTIFICATION', {
        'error': e.toString(),
        'stack_trace': st.toString(),
      });
    }
  }

  void _safePop(BuildContext? context) {
    if (context != null && context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}
