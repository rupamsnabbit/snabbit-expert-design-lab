import 'dart:async';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/constants/date_constants.dart';
import 'package:snabbit_runner/services/globals.dart';
import '../models/auto_ot/auto_ot_models.dart';
import 'package:provider/provider.dart';
import '../providers/runner_rt_data.dart';
import '../services/auto_ot_http.dart';
import '../services/clevertap.dart';
import '../services/runner_state_channel.dart';
import '../utils/enums.dart';

/// Provider for managing Auto-OT (Auto Overtime) flow state
///
/// This provider:
/// - Manages the Auto-OT state machine
/// - Handles expiry timers
/// - Makes API calls for accept/deny
/// - Tracks dismissal reasons
///
/// Note: This provider does NOT depend on other providers.
/// Coordination with RunnerRTDataProvider is handled in the UI layer.
class AutoOtProvider extends ChangeNotifier {
  /// Current state of the Auto-OT flow
  AutoOtState _state = AutoOtState.idle;

  /// Auto-OT details from the backend
  AutoOtDetails? _details;

  /// Whether the popup is currently visible
  bool _isPopupVisible = false;

  /// Expiry timestamp for the Auto-OT request
  DateTime? _expiresAt;

  /// Timer for expiry countdown
  Timer? _expiryTimer;

  /// Request ID to prevent duplicate processing
  int? _autoOtRequestId;

  /// Current OT type (autoOt or earlyTime) — used for display text only
  OtType _otType = OtType.EndOt;

  /// Getter for current state
  AutoOtState get state => _state;

  /// Getter for Auto-OT details
  AutoOtDetails? get details => _details;

  /// Getter for popup visibility
  bool get isPopupVisible => _isPopupVisible;

  /// Getter for expiry timestamp
  DateTime? get expiresAt => _expiresAt;

  /// Getter for request ID
  int? get autoOtRequestId => _autoOtRequestId;

  /// Getter for OT type
  OtType get otType => _otType;

  /// Check if current state is active (not idle, success, or expired)
  bool get isActive =>
      _state != AutoOtState.idle &&
      _state != AutoOtState.success &&
      _state != AutoOtState.expired;

  /// Check if Auto-OT request is expired
  bool get isExpired {
    if (_expiresAt == null) return false;
    return DateTime.now().isAfter(_expiresAt!);
  }

  List<String> get blockedWidgets =>
      GlobalState().appConfig?.blockedAutoOTWidgets ??
      [
        'RUNNER_JOB_IN_PROGRESS',
        'RUNNER_JOB_POST_ACCEPT',
        'RUNNER_JOB_CHECK_IN',
        'RUNNER_NEW_JOB',
        'RUNNER_SUSPENDED'
      ];

  /// Checks if job assignment should preempt Auto-OT
  ///
  /// Called from UI layer when widgetInfo changes.
  /// Returns true if Auto-OT should be dismissed due to job assignment.
  bool shouldDismissForJobAssignment(String? widgetName) {
    if (widgetName == null || !isActive) return false;

    // Job-assignment related widgets that should preempt Auto-OT.
    // Auto-OT can be shown on Partner Home when the login hotspot widget is active.

    return blockedWidgets.contains(widgetName);
  }

  void handleAutoOtCancellation() {
    // Bridge the cancellation to the KMP Auto-OT sheet so it flips to "expired" too (the KMP
    // coordinator applies its own active-offer guard). Placed here so every caller — the foreground
    // FCM handler AND the killed-state resume path — bridges without touching those risky files.
    RunnerStateChannel.autoOtCancelled();
    if (isActive && !isExpired) {
      handleExpired();
    }
  }

  void initializeFromCurrentState(
    AutoOtDetails data, {
    OtType otType = OtType.EndOt,
  }) {
    try {
      _autoOtRequestId = data.requestId;
      _details = data;
      _otType = otType;
      if (_details?.regularShift == null || _details?.otShift == null) return;
      if (data.expiryDuration != null) _startExpiryTimer(data.expiryDuration!);
      _state = AutoOtState.initial;
      _isPopupVisible = true;

      notifyListeners();

      // Log analytics
      ClevertapSetup.logEvent('ot_popup_shown', {
        'request_id': _autoOtRequestId,
        'expiry_duration': data.expiryDuration,
        'ot_type': otType.name,
      });
    } catch (e) {
      // If initialization fails, reset to idle
      reset();
    }
  }

  /// Transitions to confirmation state
  void showConfirmation() {
    if (_state != AutoOtState.initial) return;

    _state = AutoOtState.confirm;
    notifyListeners();

    // Log analytics
    ClevertapSetup.logEvent('ot_confirm_clicked', {
      'request_id': _autoOtRequestId,
      'ot_type': _otType.name,
    });
  }

  /// Goes back from confirmation to initial state
  void goBackToInitial() {
    if (_state != AutoOtState.confirm) return;

    _state = AutoOtState.initial;
    notifyListeners();
  }

  /// Submits the Auto-OT acceptance request
  ///
  /// Transitions to loading state and makes API call.
  /// On success, transitions to success state.
  /// On failure, transitions to failure state.
  Future<void> submitRequest() async {
    if (_state != AutoOtState.confirm || _autoOtRequestId == null) return;

    _state = AutoOtState.loading;
    notifyListeners();

    // Log analytics
    ClevertapSetup.logEvent('ot_accept_clicked', {
      'request_id': _autoOtRequestId,
      'ot_type': _otType.name,
    });

    try {
      final response = await AutoOtHttp.acceptOt(requestId: _autoOtRequestId!);

      if (response != null && response.statusCode == 200) {
        handleSuccess();
      } else {
        handleFailure();
      }
    } catch (e) {
      handleFailure();
    }
  }

  /// Handles successful Auto-OT acceptance
  void handleSuccess() {
    _stopExpiryTimer();
    _state = AutoOtState.success;
    notifyListeners();

    // Log analytics
    ClevertapSetup.logEvent('ot_success', {
      'request_id': _autoOtRequestId,
      'ot_type': _otType.name,
    });

    _refreshCurrentState();
  }

  /// Handles failed Auto-OT acceptance
  void handleFailure() {
    _stopExpiryTimer();
    _state = AutoOtState.failure;
    notifyListeners();
  }

  /// Handles expired Auto-OT request
  ///
  /// Called when expiry timer completes or cancellation notification received.
  void handleExpired() {
    _stopExpiryTimer();
    _state = AutoOtState.expired;
    notifyListeners();

    // Log analytics
    ClevertapSetup.logEvent('ot_expired', {
      'request_id': _autoOtRequestId,
      'ot_type': _otType.name,
    });
  }

  /// Dismisses the Auto-OT popup and calls deny API
  ///
  /// [reason] determines the denial reason sent to backend.
  /// This must be called for all dismissal paths.
  Future<void> dismissPopup(AutoOtDenyReason reason) async {
    if (_state == AutoOtState.idle ||
        _state == AutoOtState.success ||
        _autoOtRequestId == null) {
      return;
    }

    _stopExpiryTimer();
    _isPopupVisible = false;

    // Call deny API
    try {
      await AutoOtHttp.denyOt(requestId: _autoOtRequestId!, reason: reason);
    } catch (e) {
      // Log error but continue with dismissal
    }

    // Log analytics if rejected by user
    if (reason == AutoOtDenyReason.rejected) {
      ClevertapSetup.logEvent('ot_rejected', {
        'request_id': _autoOtRequestId,
        'ot_type': _otType.name,
      });
    }

    // Reset state
    reset();

    _refreshCurrentState();
  }

  /// Refreshes current_state so the backend's latest data is reflected
  /// immediately after an accept or reject action.
  void _refreshCurrentState() {
    try {
      final context = GlobalState().navigatorKey.currentContext;
      if (context != null) {
        Provider.of<RunnerRtDataProvider>(context, listen: false)
            .fetchDataNow();
      }
    } catch (_) {
      // Must not break the OT flow.
    }
  }

  /// Starts the expiry timer
  ///
  /// [durationMinutes] is the expiry duration in minutes.
  void _startExpiryTimer(int durationMinutes) {
    _stopExpiryTimer();

    _expiresAt = DateTime.now().add(Duration(minutes: durationMinutes));

    _expiryTimer = Timer(Duration(minutes: durationMinutes), () {
      if (isActive) {
        handleExpired();
      }
    });
  }

  /// Stops the expiry timer
  void _stopExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _expiresAt = null;
  }

  /// Resets the provider to idle state
  void reset() {
    _stopExpiryTimer();
    _state = AutoOtState.idle;
    _details = null;
    _isPopupVisible = false;
    _autoOtRequestId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopExpiryTimer();
    super.dispose();
  }

  /// Formats DateTime to "8 AM - 5 PM" format
  String formatTimeRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '';
    final format = DateConstants.dateFormatVisual1; // jm gives "8:00 AM" format
    final startStr = format.format(start);
    final endStr = format.format(end);
    // Remove :00 if present for cleaner display
    return '${startStr.replaceAll(':00', '')} - ${endStr.replaceAll(':00', '')}';
  }
}
