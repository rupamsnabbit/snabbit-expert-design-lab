import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../globals.dart';
import '../http_service.dart';

class LoginHttp {
  static Future<Response?> sendOtp({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
            "api/v1/runners/login/send_otp"),
        headers: headers ?? {},
        data: data ?? {},
      );
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> sendAccountVerificationOtp({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
            "api/v1/runners/bank_consent/send_otp"),
        headers: headers ?? {},
        data: data ?? {},
      );
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> verifyOtp({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
            "api/v1/runners/login/verify_otp"),
        headers: headers ?? {},
        data: data ?? {},
      );

      return response;

    } catch (e) {
      return null;
    }
  }

  static Future<Response?> verifyToken({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
            "api/v1/runners/login/otpless/verify_token"),
        headers: headers ?? {},
        data: data ?? {},
      );
      if (kDebugMode) {
        debugPrint('[Otpless] verifyToken HTTP status=${response.statusCode}');
      }
      return response;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Otpless] verifyToken HTTP error: $e');
      }
      return null;
    }
  }
}
