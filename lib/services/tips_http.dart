import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/constants.dart';

import 'http_service.dart';

class TipsHttp {
  static Future<Response?> getMonthlyTips({
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final formattedStartDate = dateFormat.format(startDate);
      final formattedEndDate = dateFormat.format(endDate);

      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/payouts/me/tips"),
        headers: headers ?? {},
        queryParameters: {
          'from_date': formattedStartDate,
          'to_date': formattedEndDate,
        },
      );

      return response;
    } catch (e) {
      return null;
    }
  }
}
