import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

class LoanHttp {
  /// Get loan details for the current runner
  /// Returns loan eligibility and status information
  static Future<Response?> getLoanDetails({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/me/loan_details"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
