import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/go_live/device_status.dart';
import 'package:snabbit_runner/models/go_live/shift_change_request.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

class GoLiveHttp {
  static Future<Response?> getRunnerStatus(
    int runnerId, {
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState()
            .serverPath("api/v1/go_live/get_runner_status?runner_id=$runnerId"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> updateRunner({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/go_live/update_runner"),
        headers: headers ?? {},
        data: data ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> availableClusters(
    int runnerId, {
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/go_live/available/clusters"),
        headers: headers ?? {},
      );

      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getShiftData(
    int runnerId,
    int clusterId,
    bool isWeekend, {
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
            "api/v1/go_live/clusters/$clusterId/shifts?runner_id=$runnerId&weekend=$isWeekend"),
        headers: headers ?? {},
      );

      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> postConfirmShiftTimings({
    Map<String, dynamic>? headers,
    required ShiftChangeRequestData data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/go_live/cluster/runner"),
        headers: headers ?? {},
        data: data.toJson(),
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getAvailableHotspots({
    Map<String, dynamic>? headers,
    int? hoodId,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/go_live/available/hotspots"),
        headers: headers ?? {},
        queryParameters: hoodId != null ? {'hood_id': hoodId} : null,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> updateHotspot({
    Map<String, dynamic>? headers,
    required int? hotspotId,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState()
            .serverPath("api/v1/go_live/runner/hotspot?hotspot_id=$hotspotId"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> reportPhoneIntegrityStatus({
    Map<String, dynamic>? headers,
    required DeviceStatusData data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/go_live/runner/phone_integrity_check"),
        headers: headers ?? {},
        data: data.toJson(),
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
