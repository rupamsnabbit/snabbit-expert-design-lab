import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

class CredentialsManagementHttp {
  static Future<Response?> getCredentials({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().onboardingUrlServerPath("api/v1/expert/credentials"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
