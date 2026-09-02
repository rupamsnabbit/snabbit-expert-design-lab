import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../globals.dart';
import '../http_service.dart';

class LanguageHttp {
  static Future<Response?> getLocalizationData(
      {Map<String, dynamic>? headers, String? lang}) async {
    try {
      final response = await HttpService().get(
        GlobalState()
            .serverPath("api/v1/runners/internationalization_file/$lang"),
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

  static Future<Response?> fetchLanguages() async {
    try {
      final response = await HttpService().get(
          GlobalState().serverPath(
            "api/v1/runners/language_list",
          ),
          headers: {});
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching languages: ${e.toString()}");
      return null;
    }
  }

  static Future<Response?> fetchLanguageProficiencies() async {
    try {
      final response = await HttpService().get(
          GlobalState().serverPath(
            "api/v1/runners/me/language_proficiency",
          ),
          headers: {});
      return response;
    } catch (e) {
      debugPrint("Error fetching languages: ${e.toString()}");
      return null;
    }
  }
}
