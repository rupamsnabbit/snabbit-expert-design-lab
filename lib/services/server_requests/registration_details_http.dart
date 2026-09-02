import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import '../globals.dart';
import '../http_service.dart';

class RegistrationDetailsHttp {
  static Future<Response?> verifyBankDetails({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
            "api/v1/runners/me/bank_details/verify"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> register(int id,
      {
        Map<String, dynamic>? headers,
        Map<String, dynamic>? data,
      }) async {
    try {
      final response = await HttpService().put(
        GlobalState().serverPath(
          'api/v1/runners/registration/$id',
        ),
        headers: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> submitIdDocs(FormData formData, {
        Map<String, dynamic>? headers,
        Map<String, dynamic>? data,
      }) async {
    try {
      final response = await HttpService().postDocs(
        GlobalState().serverPath(
            'api/v1/runners/registration/documents',
        ),
        formData: formData,
        headers: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> verifyPanNumber({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
            'api/v1/runners/me/pan/verify'),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> verifyAadhaarNumber(String aadhaarNumber,{
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
            'api/v1/runners/me/aadhaar/validate?aadhaar=$aadhaarNumber'),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> updatePanDocs(FormData formData, {
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().postDocs(
        GlobalState().serverPath(
          'api/v1/runners/add_document/pan',
        ),
        formData: formData,
        headers: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
