import 'package:dio/dio.dart';

import '../utils/constants.dart';
import 'globals.dart';
import 'http_service.dart';

class PayoutHttp {
  static Future<Response?> getAttendance({
    Map<String, dynamic>? headers,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
            "api/v1/payouts/me/attendance/${dateFormat.format(start)}/${dateFormat.format(end)}"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getPayout({
    Map<String, dynamic>? headers,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
            // "api/v1/payouts/me/daily/${dateFormat.format(start)}"
            "api/v1/payouts/me/month_payouts"),
        queryParameters: {
          'from_date': dateFormat.format(start),
          'to_date': dateFormat.format(end),
        },
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getPayslip({
    Map<String, dynamic>? headers,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
            // "api/v1/payouts/me/daily/${dateFormat.format(start)}"
            "api/v1/payouts/me/payslip/${dateFormat.format(start)}/${dateFormat.format(end)}"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getOvertimeDetails({
    Map<String, dynamic>? headers,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
            "api/v1/payouts/me/overtime/${dateFormat.format(start)}/${dateFormat.format(end)}"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getDeductionDetails({
    Map<String, dynamic>? headers,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
            "api/v1/payouts/me/deductions/${dateFormat.format(start)}/${dateFormat.format(end)}"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getRatings({
    Map<String, dynamic>? headers,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
            "api/v1/payouts/me/ratings/${dateFormat.format(start)}/${dateFormat.format(end)}"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getIncentives({
    Map<String, dynamic>? headers,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
            "api/v1/payouts/me/incentives/${dateFormat.format(start)}/${dateFormat.format(end)}"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getMonthlyEarningsList({
    required DateTime date,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final formattedMonth =
          "${date.year}-${date.month.toString().padLeft(2, '0')}";

      final response = await HttpService().get(
        "runner/monthly-earnings?month=$formattedMonth",
      );

      return response;
    } catch (e) {
      print('Exception fetching monthly earnings list: $e');
      return null;
    }
  }

  static Future<Response?> getPendingPayout({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/payouts/me/pending_payouts"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getFestiveBanner({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/payouts/me/festive_banner"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getFestiveBonus({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/payouts/me/festive_bonus"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetches the active bank account details for the expert/runner
  static Future<Response?> getActiveBankAccount({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().onboardingUrlServerPath("api/v1/expert/bank/active"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
