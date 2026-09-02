import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

/// Service class for making HTTP requests related to payout history
class PayoutHistoryService {
  /// Fetches payout history data from the server with cursor-based pagination
  static Future<Response?> getPayoutHistory({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/expert-wallet/me/transactions"),
        headers: headers ?? {},
        queryParameters: queryParameters ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
