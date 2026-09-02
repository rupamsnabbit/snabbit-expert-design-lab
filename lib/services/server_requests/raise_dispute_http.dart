import 'package:dio/dio.dart';
import 'package:snabbit_runner/models/issue_data.dart';

import '../globals.dart';
import '../http_service.dart';

class RaiseDisputeHttp {
  static Future<Response?> getIssueHistory({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters, // int size, string cursor
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/expert-issues/me/issue_history"),
        headers: headers ?? {},
        queryParameters: queryParameters ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> reportIssue(IssueData? issue,
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/expert-issues/me/report_issue"),
          headers: headers ?? {},
          data: issue?.toJson());
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> requestReview(IssueData? issue,
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/expert-issues/me/request_review"),
          headers: headers ?? {},
          data: issue?.toJson());
      return response;
    } catch (e) {
      return null;
    }
  }
}
