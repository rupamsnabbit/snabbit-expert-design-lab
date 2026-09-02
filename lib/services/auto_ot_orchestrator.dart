import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auto_ot/auto_ot_models.dart';
import '../providers/auto_ot_provider.dart';
import '../providers/runner_rt_data.dart';
import '../utils/enums.dart';
import '../services/auto_ot_http.dart';
import '../services/globals.dart';
import '../widgets/auto_ot/auto_ot_bottom_sheet.dart';

/// Orchestrator for Auto-OT (Auto Overtime) popup flow.
///
/// This helper coordinates between RunnerRtDataProvider and AutoOtProvider
/// using the global navigatorKey context, so that Auto-OT can be shown as a
/// global bottom sheet without wrapping individual screens.
class AutoOtOrchestrator {
  static bool _isBottomSheetShowing = false;

  /// Called after RunnerRtDataProvider has updated widgetInfo/widgetUtil.
  ///
  /// - Reads the latest widgetInfo auto_ot payload.
  /// - Initializes AutoOtProvider with a new Auto-OT request when applicable.
  /// - Resets Auto-OT when auto_ot is removed.
  /// - Decides whether to show the Auto-OT bottom sheet based on state and
  ///   screen eligibility.
  static Future<void> onRunnerStateUpdated() async {
    final context = GlobalState().navigatorKey.currentContext;
    if (context == null) return;

    try {
      final runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: false);
      final autoOtProvider =
          Provider.of<AutoOtProvider>(context, listen: false);
      final widgetInfo = runnerRtDataProvider.widgetInfo;

      // Job flows can preempt Auto-OT.
      if (autoOtProvider.shouldDismissForJobAssignment(widgetInfo?.name)) {
        await autoOtProvider
            .dismissPopup(AutoOtDenyReason.cancelledDueToJobAssignment);
        return;
      }

      // Extract auto_ot object from widget data.
      final otData = widgetInfo?.data?['auto_ot'];

      if (otData != null && otData is Map<String, dynamic>) {
        // Parse Auto-OT details safely.
        AutoOtDetails? details;
        try {
          details = AutoOtDetails.fromJson(otData);
        } catch (_) {}

        if (details == null) {
          // If parsing fails, do not crash polling.
          return;
        }

        if (autoOtProvider.autoOtRequestId != details.requestId) {
          autoOtProvider.initializeFromCurrentState(details, otType: details.otType);
        }
      } else if (otData == null &&
          autoOtProvider.state != AutoOtState.idle &&
          autoOtProvider.otType != OtType.StartOt) {
        // If auto_ot is removed from current_state, reset Auto-OT.
        // Skip reset for StartOt (pre-shift) — it is triggered via the
        // attendance API and is not expected to persist in current_state.
        autoOtProvider.reset();
      }

      // After state updates, decide whether to show the bottom sheet.
      await _maybeShowBottomSheet(context);
    } catch (_) {
      // Orchestration must never break polling; swallow errors here.
    }
  }

  /// Checks if the current screen and widgetInfo allow showing Auto-OT,
  /// and shows the bottom sheet if all conditions are met.
  static Future<void> _maybeShowBottomSheet(BuildContext context) async {
    if (!context.mounted) return;

    final autoOtProvider = Provider.of<AutoOtProvider>(context, listen: false);

    // Check if popup should be shown
    if (autoOtProvider.isPopupVisible &&
        autoOtProvider.state == AutoOtState.initial &&
        !_isBottomSheetShowing &&
        _isScreenEligibleForAutoOt(context)) {
      // Show bottom sheet
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            autoOtProvider.isPopupVisible &&
            autoOtProvider.state == AutoOtState.initial &&
            !_isBottomSheetShowing &&
            _isScreenEligibleForAutoOt(context)) {
          _isBottomSheetShowing = true;
          showAutoOtBottomSheet(context, otType: autoOtProvider.otType)
              .then((_) => _isBottomSheetShowing = false);
        }
      });
    } else if (!autoOtProvider.isPopupVisible) {
      _isBottomSheetShowing = false;
    }
  }

  /// Triggers Auto-OT flow after provisional attendance is marked.
  ///
  /// Calls the API to fetch OT data, parses the response as [AutoOtDetails],
  /// and initializes the Auto-OT provider if valid data is returned.
  /// This is an additional trigger path — the existing polling-based
  /// Auto-OT from current_state remains unchanged.
  static Future<void> onAttendanceMarked() async {
    final context = GlobalState().navigatorKey.currentContext;
    if (context == null) return;

    try {
      final response = await AutoOtHttp.fetchOtOnAttendance();
      if (response == null ||
          response.statusCode != 200 ||
          response.data == null) {
        return;
      }

      final Map<String, dynamic>? otData =
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : null;
      if (otData == null) return;

      AutoOtDetails? details;
      try {
        details = AutoOtDetails.fromJson(otData);
      } catch (_) {}
      if (details == null) return;

      final autoOtProvider =
          Provider.of<AutoOtProvider>(context, listen: false);

      if (autoOtProvider.autoOtRequestId != details.requestId) {
        autoOtProvider.initializeFromCurrentState(
          details,
          otType: details.otType,
        );
      }

      await _maybeShowBottomSheet(context);
    } catch (_) {
      // Must not crash the attendance flow.
    }
  }

  /// Checks if the current screen is eligible for Auto-OT popup.
  ///
  /// Returns true if the current route is in the allowed list and we are not
  /// currently in a job assignment flow that should block Auto-OT.
  static bool _isScreenEligibleForAutoOt(BuildContext context) {

    // Blocked screens - check if we're in a job flow FIRST via widgetInfo.
    final autoOtProvider = Provider.of<AutoOtProvider>(context, listen: false);
    final widgetName = Provider.of<RunnerRtDataProvider>(context, listen: false)
        .widgetInfo
        ?.name;

    if (widgetName != null &&
        autoOtProvider.blockedWidgets.contains(widgetName)) {
      if (autoOtProvider.isActive) {
        autoOtProvider
            .dismissPopup(AutoOtDenyReason.cancelledDueToJobAssignment);
      }
      return false;
    }

    return true;
  }
}
