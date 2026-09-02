import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'globals.dart';
import 'http_service.dart';

class LunchHttp {
  static Future<Response?> runnersMeBreak(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();

      if(position != null) {
        data ??= {};
        data.addAll({
          'location' : {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }

      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/runners/me/break"),
          headers: headers ?? {},
          data: data ?? {});
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

  static Future<Response?> runnersMeBreakStart(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();

      if(position != null) {
        data ??= {};
        data.addAll({
          'location' : {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }

      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/runners/me/break/start"),
          headers: headers ?? {},
          data: data ?? {});
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

  static Future<Response?> runnersMeBreakEnd(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();

      if(position != null) {
        data ??= {};
        data.addAll({
          'location' : {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }

      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/runners/me/break/end"),
          headers: headers ?? {},
          data: data ?? {});
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

  static Future<Response?> acceptLunch({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
            "api/v1/runners/me/lunch/accept"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> denyLunch({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState()
            .serverPath("api/v1/runners/me/lunch/deny"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<Response?> skipBuffer(int runnerId,{
    Map<String, dynamic>? headers,
  }) async {
    try {
      Map<String, dynamic> data = { "skip_buffer": true };
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();

      if(position != null) {
        data.addAll({
          'location' : {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }
      final response = await HttpService().post(
        GlobalState()
            .serverPath("api/v1/runners/job/$runnerId/skip_buffer"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }
}
