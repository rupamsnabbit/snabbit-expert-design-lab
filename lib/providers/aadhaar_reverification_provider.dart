import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/models/aadhaar_update_response.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/models/perfios_aadhaar_data.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/server_requests/aadhaar_reverification_services.dart';

/// Phases of the self-contained Aadhaar re-KYC flow.
enum ReKycPhase { intro, loading, webview, review, submitting, result }

/// Posts the raw Perfios JSON to the re-KYC endpoint. Injectable so the
/// provider can be unit-tested without the network.
typedef AadhaarUpdateSubmitter = Future<Response?> Function(String perfiosJson);

Future<Response?> _defaultSubmitter(String perfiosJson) =>
    AadhaarReverificationServices.submitAadhaarUpdate(perfiosJson: perfiosJson);

/// Drives the stateless Aadhaar re-KYC flow: Perfios result → review → submit
/// to `/aadhaar/update` → result. Error/status handling mirrors the current
/// Aadhaar flow (`submitPerfiosValidationResponse`): non-200s surface a
/// [CustomError] `title`/`message` and the runner may retry; there is no
/// client-side error-code branching.
class AadhaarReverificationProvider extends ChangeNotifier {
  AadhaarReverificationProvider({AadhaarUpdateSubmitter? submitter})
      : _submitter = submitter ?? _defaultSubmitter;

  final AadhaarUpdateSubmitter _submitter;

  ReKycPhase _phase = ReKycPhase.intro;
  ReKycPhase get phase => _phase;

  PerfiosAadhaarData? _reviewData;
  PerfiosAadhaarData? get reviewData => _reviewData;

  String? _rawPerfiosJson;

  AadhaarUpdateResponse? _result;
  AadhaarUpdateResponse? get result => _result;

  CustomError? _error;
  CustomError? get error => _error;

  /// Whether the current outcome allows another attempt (re-launch Perfios).
  /// `verified` and `name_mismatched` are terminal; everything else (rejected,
  /// backend error, network/null, Perfios interruption) is retryable.
  bool get canRetry {
    final result = _result;
    if (result != null) {
      return !result.isVerified && !result.isNameMismatched;
    }
    return _error != null;
  }

  void goToLoading() {
    _phase = ReKycPhase.loading;
    notifyListeners();
  }

  void goToWebview() {
    _phase = ReKycPhase.webview;
    notifyListeners();
  }

  /// Perfios `onShutdown` fired. This callback also fires when the runner
  /// *exits* the Perfios webview (its native "Exit" dialog), so we must NOT
  /// treat every payload as a submittable success. Only a genuine result —
  /// one that carries Aadhaar demographic data and has no error/exit marker —
  /// goes to the review screen; anything else is an interrupted, retryable
  /// failure (no "submit anyway" screen).
  void onPerfiosSuccess(String rawJson) {
    final map = _decodePerfios(rawJson);
    final data = map == null ? null : PerfiosAadhaarData.fromJson(map);
    final exitedOrErrored =
        map?['isError'] == true || map?['exitByUser'] == true;

    if (data == null || exitedOrErrored || !data.hasAnyData) {
      onPerfiosFailed();
      return;
    }

    _rawPerfiosJson = rawJson;
    _reviewData = data;
    _error = null;
    _result = null;
    _phase = ReKycPhase.review;
    notifyListeners();
  }

  /// Perfios reported a failure or the runner exited the webview. We do not
  /// POST anything; we surface a retryable failure.
  void onPerfiosFailed() {
    _rawPerfiosJson = null;
    _reviewData = null;
    _result = null;
    _error = CustomError(
      errorMessageCode: 'AADHAAR_REKYC_PERFIOS_INTERRUPTED',
      message: 'Aadhaar verification was interrupted. Please try again.',
    );
    _phase = ReKycPhase.result;
    notifyListeners();
  }

  /// Submits the stored raw Perfios JSON. [onVerified] runs only when the
  /// backend returns `status=verified` — the page wires it to a state refresh.
  Future<void> submit({Future<void> Function()? onVerified}) async {
    final raw = _rawPerfiosJson;
    if (raw == null) return;
    // Re-entrancy guard: ignore a second submit while one is in flight (the
    // Confirm button only disables after the next rebuild, so a fast double
    // tap could otherwise fire two POSTs).
    if (_phase == ReKycPhase.submitting) return;

    _phase = ReKycPhase.submitting;
    _error = null;
    _result = null;
    notifyListeners();

    try {
      final response = await _submitter(raw);
      if (response == null) {
        _error = CustomError(
          errorMessageCode: 'AADHAAR_REKYC_NO_RESPONSE',
          message: 'No response from server. Please try again.',
        );
      } else if (response.statusCode == 200) {
        final data = response.data;
        final map =
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _result = AadhaarUpdateResponse.fromJson(map);
        if (_result!.isVerified) {
          await onVerified?.call();
        }
      } else {
        _error = _parseError(response) ??
            CustomError(
              errorMessageCode: 'AADHAAR_REKYC_FAILED',
              message: 'Something went wrong. Please try again.',
            );
      }
    } catch (e, st) {
      MonitoringServiceHelper.reportError(
        'AADHAAR_REKYC_SUBMIT_HANDLER_FAILED',
        {'error': e.toString()},
        st.toString(),
      );
      _error = CustomError(
        errorMessageCode: 'AADHAAR_REKYC_EXCEPTION',
        message: 'Something went wrong. Please try again.',
      );
    } finally {
      _phase = ReKycPhase.result;
      notifyListeners();
    }
  }

  /// Returns to [ReKycPhase.intro] so the page can relaunch the webview.
  void retry() => reset();

  void reset() {
    _phase = ReKycPhase.intro;
    _reviewData = null;
    _rawPerfiosJson = null;
    _result = null;
    _error = null;
    notifyListeners();
  }

  Map<String, dynamic>? _decodePerfios(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      MonitoringServiceHelper.logError(
        'AADHAAR_REKYC_PERFIOS_PARSE_FAILED',
        {'error': e.toString()},
      );
    }
    return null;
  }

  CustomError? _parseError(Response response) {
    try {
      final data = response.data;
      if (data is Map && data['errors'] != null) {
        return ResponseError.fromMap(Map<String, dynamic>.from(data))
            .getFirstError();
      }
    } catch (e) {
      MonitoringServiceHelper.logError(
        'AADHAAR_REKYC_ERROR_PARSE_FAILED',
        {'error': e.toString()},
      );
    }
    return null;
  }
}
