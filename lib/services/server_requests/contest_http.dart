import 'dart:async';

import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

class ContestHttp {
  static Future<Response?> getContestLeaderboard({
    required int contestId,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runner_referrals/contests/$contestId/leaderboard"),
        queryParameters: queryParameters ?? {},
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
