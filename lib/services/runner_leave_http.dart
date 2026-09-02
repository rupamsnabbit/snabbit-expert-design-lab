import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

class RunnerLeaveHTTP {
  static Future<Response?> getLeaves({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters, // int size, string cursor
  }) async {
    try {
      final response = await HttpService().get(
          GlobalState().serverPath("api/v1/runner_leaves/me"),
          headers: headers ?? {},
          queryParameters: queryParameters ?? {});
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> createLeave(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/runner_leaves/me"),
          headers: headers ?? {},
          data: data ?? {});
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> cancelLeave(
      {Map<String, dynamic>? headers, required int id}) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/runner_leaves/me/$id/cancel"),
          headers: headers ?? {},
          data: {});
      return response;
    } catch (e) {
      return null;
    }
  }
}
