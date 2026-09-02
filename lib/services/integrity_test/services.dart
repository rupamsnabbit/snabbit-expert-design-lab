import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
// import 'package:snabbit_runner/services/integrity_test/models.dart';

class RunnerIntegrityTestService {
  static Future<Response?> getQuestions({
    Map<String, dynamic>? headers,
    required int runnerId,
    // required IntegrityTestRequest data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/runner_onboarding/question/$runnerId"),
        headers: headers ?? {},
        // data: data.toJson(),
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getAllQuestions({
    Map<String, dynamic>? headers,
    String type = "INTEGRITY",
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runner_onboarding/questions/$type"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
