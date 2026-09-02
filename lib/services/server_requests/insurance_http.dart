import 'package:dio/dio.dart';

import '../globals.dart';
import '../http_service.dart';

class InsuranceHttp {
  static Future<Response?> getInsurance(
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/me/insurance"),
        headers: headers ?? {},
      );
      // if (response.statusCode == 200) {
      return response;
      // } else {
      //   return response;
      // }
    } catch (e) {
      // debugPrint(e.toString());
      return null;
    }
  }
  static Future<Response?> getInsuranceSupport(
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/me/claim_insurance"),
        headers: headers ?? {},
      );
      // if (response.statusCode == 200) {
      return response;
      // } else {
      //   return response;
      // }
    } catch (e) {
      // debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> getInsuranceTierInfo(
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/me/insurance-tier"),
        headers: headers ?? {},
      );
      // if (response.statusCode == 200) {
      return response;
      // } else {
      //   return response;
      // }
    } catch (e) {
      // debugPrint(e.toString());
      return null;
    }
  }
}
