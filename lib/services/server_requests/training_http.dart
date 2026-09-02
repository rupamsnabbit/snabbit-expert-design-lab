import 'dart:io';

import 'package:dio/dio.dart';

import '../globals.dart';
import '../http_service.dart';

class TrainingHttp {
  static Future<Response?> getTrainingBatches({
        Map<String, dynamic>? headers,
        Map<String, dynamic>? queryParameters,
      }) async {
    try {
      Response response = await HttpService().get(
        GlobalState().serverPath(
            "api/v1/training/me/potential_batches"),
        headers: headers ?? {},
        queryParameters: queryParameters,
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      // debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> getRunnerTrainingDays({
        Map<String, dynamic>? headers,
        Map<String, dynamic>? queryParameters,
      }) async {
    try {
      Response? response = await HttpService().get(
        GlobalState().serverPath(
            "api/v1/training/me/batches/latest"),
        headers: headers ?? {},
        queryParameters: queryParameters,
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

  static Future<Response?> setBatch({
        Map<String, dynamic>? headers,
        Map<String, dynamic>? data,
      }) async {
    try {
      Response? response = await HttpService().post(
        GlobalState().serverPath(
            "api/v1/training/me/batches"),
        headers: headers ?? {},
        data: data,
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

  static Future<Response?> trainingLogout({
        Map<String, dynamic>? headers,
        Map<String, dynamic>? data,
      }) async {
    try {
      Response? response = await HttpService().post(
        GlobalState().serverPath(
            "api/v1/training/me/logout"),
        headers: headers ?? {},
        data: data,
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

  static Future<Response?> trainingLogin(File? file, String otp) async {
    try {
      MultipartFile? multipartFile;
      multipartFile = await MultipartFile.fromFile(file!.path);
      FormData formData = FormData.fromMap({
        // "aadhar_number": userProfileProvider.user?.aadhaarNumber,
        'file': multipartFile,
        'otp': otp,
      });
      final response = await HttpService().postDocs(
        GlobalState().serverPath(
          'api/v1/training/me/login',
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
