
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/widgets/check_in_without_otp/models/check_in_without_otp_request_model.dart';

/// Service layer for verify check-in by phone number.
///
/// This wraps the project's `HttpService` and composes the server URL via
/// `GlobalState().serverPath(...)`.
class CheckInWithoutOtpService {
  /// HTTP client wrapper used for all server calls.
  final HttpService _httpService;

  /// Creates the service with an optional injected HTTP service.
  CheckInWithoutOtpService({HttpService? httpService})
      : _httpService = httpService ?? HttpService();

  /// Performs the verification request.
  ///
  /// Currently a placeholder implementation. Replace with a real endpoint and
  /// response parsing once the backend is ready.
  Future<Response?> verifyAndStartJob({
    required CheckInWithoutOtpRequestModel request,
    required int jobId,
  }) async {
    // Kept as a reference for upcoming integration (avoids unused field lint).
    // ignore: unnecessary_statements
    _httpService;

    // Example structure for the future real call:
    final response = await HttpService().post(
      GlobalState().serverPath('api/v1/jobs/$jobId/start_job'),
      headers: {},
      data: CheckInWithoutOtpRequestModel.toJson(request),
    );

    return response;
  }
}