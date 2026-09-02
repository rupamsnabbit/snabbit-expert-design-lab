import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/constants.dart';

import 'http_service.dart';

class DailyEarningsHttp {
  // Single endpoint to fetch all daily earnings data
  static Future<Response?> getDailyEarnings({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {

      final response = await HttpService().get(
        GlobalState()
            .serverPath("api/v1/payouts/me/daily_payouts"),
        headers: headers ?? {},
        queryParameters: queryParameters ?? {},
      );

      return response;
    } catch (e) {
      // print('Exception fetching daily earnings: $e');
      return null;
    }
  }

  static Future<Response?> getMonthlyEarningsList({
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final formattedStartDate = dateFormat.format(startDate);
      final formattedEndDate = dateFormat.format(endDate);

      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/payouts/me/range_payouts"),
        headers: headers ?? {},
        queryParameters: {
          'from_date': formattedStartDate,
          'to_date': formattedEndDate,
        },
      );

      return response;
    } catch (e) {
      // print('Exception fetching daily earnings: $e');
      return null;
    }
  }
}
