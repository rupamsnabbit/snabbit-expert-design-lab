import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/services/auto_ot_orchestrator.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

/// Dedicated state holder for the PA_BEFORE_LOGOUT bottom sheet.
/// Keeps track of UI state (initial -> submitting -> success).
enum ProvisionalAttendanceBeforeLogoutSheetState {
  initial,
  submitting,
  success,
  failure,
  denialBuffer
}

class ProvisionalAttendanceBeforeLogoutProvider
    extends ChangeNotifier {
  ProvisionalAttendanceBeforeLogoutSheetState _state =
      ProvisionalAttendanceBeforeLogoutSheetState.initial;

  ProvisionalAttendanceBeforeLogoutSheetState get state => _state;

  bool get isSubmitting => _state ==
      ProvisionalAttendanceBeforeLogoutSheetState.submitting;

  bool get isSuccess =>
      _state == ProvisionalAttendanceBeforeLogoutSheetState.success;

  void setState(ProvisionalAttendanceBeforeLogoutSheetState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  void reset() {
    _state = ProvisionalAttendanceBeforeLogoutSheetState.initial;
    notifyListeners();
  }


  Map<String, dynamic> attendanceBeforeLogoutMixpanelProps(
      Map<String, dynamic> widgetData,
      ) {
    final sosVisibility = widgetData["sos_visibility"];
    bool? sosVisible;
    if (sosVisibility is Map) {
      final visible = sosVisibility["visible"];
      sosVisible = visible is bool ? visible : null;
    }

    return {
      "date": widgetData["date"]?.toString(),
      "shift_time": widgetData["shift_time"]?.toString(),
      "tomorrow_date": widgetData["tomorrow_date"]?.toString(),
      "tomorrow_shift_time": widgetData["tomorrow_shift_time"]?.toString(),
      "sos_visible": sosVisible,
      "provisional_atn": widgetData["provisional_atn"],
    };
  }

  String extractShiftEndTime(String shiftTimeRange) {
    final parts = shiftTimeRange.split('-');
    if (parts.length >= 2) {
      return formatAmPm(parts[1].trim());
    }
    return formatAmPm(shiftTimeRange.trim());
  }

  String formatTimeRangeForDisplay(String range) {
    return formatAmPm(range).replaceAll(RegExp(r'\s*-\s*'), ' - ');
  }

  String formatAmPm(String input) {
    // Convert "am"/"pm" to uppercase AM/PM for consistent UI.
    return input
        .replaceAll(RegExp(r'\bam\b', caseSensitive: false), 'AM')
        .replaceAll(RegExp(r'\bpm\b', caseSensitive: false), 'PM');
  }

  int get _delayTime => RemoteConfigService.instance.getNonZeroInt(
    RemoteConfigKeys.expertProvisionalAttendanceBottomsheetCloseTime,
    defaultValue: 5,
  );

  Future<void> markPresent({required Map<String, dynamic> widgetData,required VoidCallback onStart, required VoidCallback onSuccess, required VoidCallback onFailure, VoidCallback? onApiSuccess}) async {
    await MixpanelSetup.logEvent(
      'attendance_before_logout_yes_clicked',
      attendanceBeforeLogoutMixpanelProps(widgetData),
    );
    setState(ProvisionalAttendanceBeforeLogoutSheetState.submitting);
    onStart();

    try {
      final Response? response = await JobHttp.markAttendance(
        data: {"mark": true},
      );

      if (response != null && response.statusCode == 200) {
        try {
          onApiSuccess?.call();
        } catch (e, st) {
          FirebaseCrashlytics.instance.recordError(e, st,
              reason: 'provisional_attendance_override_failed', fatal: false);
        }
        await AutoOtOrchestrator.onAttendanceMarked();
        await ClevertapSetup.logEvent(TrackingEvents.attendanceMarked, {
          "runner_attendance": "attendance marked",
          "marked": true,
          "type": "provisional",
        });

        await MixpanelSetup.logEvent(
          'attendance_before_logout_yes_marked_success',
          attendanceBeforeLogoutMixpanelProps(widgetData),
        );
        setState(ProvisionalAttendanceBeforeLogoutSheetState.success);

        await Future.delayed(Duration(seconds: _delayTime));
        onSuccess();
        reset();
      } else {
        await MixpanelSetup.logEvent(
          'attendance_before_logout_yes_marked_failure',
          attendanceBeforeLogoutMixpanelProps(widgetData),
        );
        setState(ProvisionalAttendanceBeforeLogoutSheetState.failure);
        onFailure();
        reset();
      }
    } catch (e, st) {
      MonitoringServiceHelper.reportError(
        "FAILED_TO_MARK_PRESENT",
        {'error': e.toString()},
        st.toString(),
      );
      await MixpanelSetup.logEvent(
        'attendance_before_logout_yes_marked_failure',
        attendanceBeforeLogoutMixpanelProps(widgetData),
      );
      setState(ProvisionalAttendanceBeforeLogoutSheetState.failure);
      onFailure();
      reset();
    }
  }

  Future<void> markAbsent({required Map<String, dynamic> widgetData,required VoidCallback onStart, required VoidCallback onSuccess, required VoidCallback onFailure, VoidCallback? onApiSuccess}) async {
    await MixpanelSetup.logEvent(
      'attendance_before_logout_no_confirmed_clicked',
      attendanceBeforeLogoutMixpanelProps(widgetData),
    );

    setState(ProvisionalAttendanceBeforeLogoutSheetState.submitting);
    onStart();

    try {
      final Response? response = await JobHttp.markAttendance(
        data: {
          "mark": false,
        },
      );

      if (response != null && response.statusCode == 200) {
        try {
          onApiSuccess?.call();
        } catch (e, st) {
          FirebaseCrashlytics.instance.recordError(e, st,
              reason: 'provisional_attendance_override_failed', fatal: false);
        }
        await ClevertapSetup.logEvent(TrackingEvents.attendanceMarked, {
          "runner_attendance": "attendance marked",
          "marked": false,
          "type": "provisional",
        });

        await MixpanelSetup.logEvent(
          'attendance_before_logout_no_marked_success',
          attendanceBeforeLogoutMixpanelProps(widgetData),
        );
        setState(ProvisionalAttendanceBeforeLogoutSheetState.success);

        await Future.delayed(Duration(seconds: _delayTime));
        onSuccess();
        reset();
      } else {
        await MixpanelSetup.logEvent(
          'attendance_before_logout_no_marked_failure',
          attendanceBeforeLogoutMixpanelProps(widgetData),
        );
        setState(ProvisionalAttendanceBeforeLogoutSheetState.failure);
        onFailure();
        reset();
      }
    } catch (e, st) {
      MonitoringServiceHelper.reportError(
        "FAILED_TO_MARK_ABSENT",
        {'error': e.toString()},
        st.toString(),
      );
      await MixpanelSetup.logEvent(
        'attendance_before_logout_no_marked_failure',
        attendanceBeforeLogoutMixpanelProps(widgetData),
      );
      setState(ProvisionalAttendanceBeforeLogoutSheetState.failure);
      onFailure();
      reset();
    }
  }
}

