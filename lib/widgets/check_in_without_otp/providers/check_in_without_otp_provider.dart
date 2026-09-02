import 'package:flutter/material.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import '../../../utils/error_handler.dart';
import '../models/error_response.dart';
import '../models/check_in_without_otp_bottom_sheet_view.dart';
import '../models/check_in_without_otp_request_model.dart';
import '../services/check_in_without_otp_service.dart';

/// Provider for the verify check-in by phone number bottom sheet.
///
/// Owns the current view state, the entered phone number, and the async flow
/// that transitions to success/failure placeholders.
class CheckInWithoutOtpProvider extends ChangeNotifier {
  /// Service used to perform verification.
  CheckInWithoutOtpService? _service;

  /// Current view shown inside the bottom sheet.
  CheckInWithoutOtpBottomSheetView _view =
      CheckInWithoutOtpBottomSheetView.enterPhoneNumber;

  /// Phone number entered by the user.
  String? _phoneNumber;

  ErrorResponse? errorResponse;

  int? _jobId;

  /// Initializes the provider with dependencies.
  ///
  /// Intended to be called once from the widget's `didChangeDependencies`.
  void init({
    required CheckInWithoutOtpService service,
    required int jobId,
  }) {
    _service ??= service;
    _jobId ??= jobId;
  }

  /// Current view getter.
  CheckInWithoutOtpBottomSheetView get view => _view;

  /// Current phone number getter.
  String? get phoneNumber => _phoneNumber;


  /// Updates the phone number as the user types.
  void setPhoneNumber(String value) {
    _phoneNumber = value;
    notifyListeners();
    ClevertapSetup.logEvent(
        TrackingEvents.checkInWithoutOtpPhoneNumberEntered, {
      'job_id': _jobId,
      'phone_number': _phoneNumber,
    });
  }

  /// Resets the sheet back to the default phone entry view.
  void resetToEntry() {
    _view = CheckInWithoutOtpBottomSheetView.enterPhoneNumber;
    notifyListeners();
  }

  /// Submits the phone number to verify and start the job.
  ///
  /// Transitions: enterPhoneNumber -> loading -> success/failure.
  Future<void> submit(BuildContext context) async {
    if (_service == null || _jobId == null) return;

    ClevertapSetup.logEvent(
        TrackingEvents.checkInWithoutOtpVerifyPhoneNumberBtnClicked, {
      'job_id': _jobId,
      'phone_number': _phoneNumber,
    });

    _view = CheckInWithoutOtpBottomSheetView.loading;
    errorResponse = null;
    notifyListeners();

    try {
      final position = await fetchCurrentLocation();
      final result = await _service?.verifyAndStartJob(
          request: CheckInWithoutOtpRequestModel(
            phoneNumber: _phoneNumber,
            lat: position?.latitude,
            long: position?.longitude,
          ),
          jobId: _jobId ?? 0);
      if (result?.statusCode == 200) {
        _view = CheckInWithoutOtpBottomSheetView.success;
        notifyListeners();
        ClevertapSetup.logEvent(
            TrackingEvents.checkInWithoutOtpSuccessStateDisplayed, {
          'job_id': _jobId,
          'phone_number': _phoneNumber,
        });
      } else {
        ErrorHandler.handleResponseError(
          response: result,
          context: context,
          onError: (context, responseError) {
            try {
              final error = responseError.errors?.first;
              final data = error?.data;
              if (data != null) {
                _view = CheckInWithoutOtpBottomSheetView.failure;
                errorResponse = ErrorResponse.fromJson(data);
                notifyListeners();
                ClevertapSetup.logEvent(
                    TrackingEvents.checkInWithoutOtpSuccessStateDisplayed, {
                  'job_id': _jobId,
                  'phone_number': _phoneNumber,
                  'error_type': errorResponse?.failureType?.key,
                });
              } else {
                _view = CheckInWithoutOtpBottomSheetView.failure;
                ClevertapSetup.logEvent(
                    TrackingEvents.checkInWithoutOtpSuccessStateDisplayed, {
                  'job_id': _jobId,
                  'phone_number': _phoneNumber,
                  'error_type': error?.title,
                  'error_message': error?.message,
                });
                notifyListeners();
              }
            } catch (e) {
              _view = CheckInWithoutOtpBottomSheetView.failure;
              ClevertapSetup.logEvent(
                  TrackingEvents.checkInWithoutOtpSuccessStateDisplayed, {
                'job_id': _jobId,
                'phone_number': _phoneNumber,
                'error_type': "OTHER_ERROR",
              });
              MonitoringServiceHelper.logError("CHECK_IN_WITHOUT_OTP_ERROR", {
                'error': e.toString(),
              });
              notifyListeners();
            }
          },
        );
      }
    } catch (e) {
      _view = CheckInWithoutOtpBottomSheetView.failure;
      notifyListeners();
      ClevertapSetup.logEvent(
          TrackingEvents.checkInWithoutOtpSuccessStateDisplayed, {
        'job_id': _jobId,
        'phone_number': _phoneNumber,
        'error_type': "FAILED_TO_PROCESS",
      });
      MonitoringServiceHelper.logError("CHECK_IN_WITHOUT_OTP_ERROR", {
        'error': e.toString(),
      });
    }
  }

  /// Sets the view explicitly (useful for future flows and testing).
  void setView(CheckInWithoutOtpBottomSheetView view) {
    _view = view;
    notifyListeners();
  }
}
