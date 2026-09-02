import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';

import 'http_service.dart';

class EarlyPayoutsHttp {
  static Future<Response?> getEarlyPayoutsData({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/expert-wallet/me/info"),
        headers: headers ?? {},
      );

      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> requestManualWithdraw({
    required double requestedAmount,
    required String idempotencyKey,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final requestData = {
        'requested_amount': requestedAmount,
        'idempotency_key': idempotencyKey,
      };

      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/expert-wallet/me/withdraw/manual"),
        data: requestData,
        headers: headers ?? {},
      );

      return response;
    } catch (e) {
      return null;
    }
  }
}
