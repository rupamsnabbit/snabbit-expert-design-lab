import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

class ConfigHttp {
  static Future<Response?> getAppConfig({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
          GlobalState().serverPath("api/v1/runners/app_config"),
          headers: headers ?? {}
      );
      return response;
    } catch (e) {
      // debugPrint(e.toString());
      return null;
    }
  }
}