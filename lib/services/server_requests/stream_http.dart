import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

class StreamHttp {
  /// Get Stream API key from the dedicated endpoint
  /// Returns response with stream_api_key and user_type
  static Future<Response?> getStreamApiKey({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/stream/stream_api_key"),
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
}