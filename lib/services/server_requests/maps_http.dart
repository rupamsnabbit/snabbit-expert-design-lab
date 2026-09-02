import 'package:dio/dio.dart';

import '../globals.dart';
import '../http_service.dart';

class MapsHttp {
  static Future<Response?> fetchUrl(String path,
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService()
          .get(GlobalState().serverPath(path), headers: headers ?? {});
      // if (response.statusCode == 200) {
      return response;
      // } else {
      //   return null;
      // }
    } catch (e) {
      // debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> fetchClusters({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/me/nearby_clusters"),
        headers: headers ?? {},
        queryParameters: queryParameters ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> fetchTrainingCenters(
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/geos/training_centers"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
