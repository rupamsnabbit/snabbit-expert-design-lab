import 'package:dio/dio.dart';
import '../utils/common_methods.dart';
import 'globals.dart';
import 'http_service.dart';
import 'monitoring/monitoring_service_helper.dart';

class JobHttp {
  static Future<Response?> markAttendance(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final response = await HttpService().post(
          GlobalState()
              .serverPath("api/v1/runners/me/provisional_attendance/mark"),
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

  static Future<Response?> changeAttendance(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/runners/me/attendance/mark"),
          headers: headers ?? {},
          data: data ?? {});
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> blockCustomer(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final response = await HttpService().put(
          GlobalState().serverPath("api/v1/runners/me/preferences"),
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

  static Future<Response?> getBlockedCustomers(
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/me/preferences"),
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

  static Future<Response?> initiatePayment(
      {Map<String, dynamic>? headers,
      required int jobId,
      Map<String, dynamic>? data}) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/jobs/$jobId/initiate_payment"),
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

  static Future<Response?> confirmPayment(
      {Map<String, dynamic>? headers,
      required int jobId,
      Map<String, dynamic>? data}) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/jobs/$jobId/confirm_payment"),
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

  static Future<Response?> acceptJob(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();

      if(position != null){
        data ??= {};
        data.addAll({
          'location' : {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/jobs/${data?['job_id']}/accept_job"),
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

  static Future<Response?> denyJob(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();

      if(position != null){
        data ??= {};
        data.addAll({
          'location' : {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/jobs/${data?['job_id']}/deny_job"),
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

  static Future<Response?> checkArrival(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final response = await HttpService().post(
          GlobalState()
              .serverPath("api/v1/jobs/${data?['job_id']}/check_arrival"),
          headers: headers ?? {},
          data: data);
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

  static Future<Response?> startJob(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();

      if(position != null){
        data ??= {};
        data.addAll({
          'location' : {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/jobs/${data?['job_id']}/start_job"),
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

  static Future<Response?> runnerLogout(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/runners/me/shift/logout"),
          headers: headers ?? {},
          data: data ?? {});
      return response;
    } catch (e) {
      // debugPrint(e.toString());
      return null;
    }
  }

  /// Emergency logout — `period_leave` is sent in the JSON body.
  static Future<Response?> emergencyLogout({
    required bool periodLeave,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/runners/me/emergency_logout"),
        headers: headers ?? {},
        data: {'period_leave': periodLeave},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Quota for emergency logout (`emergency_logouts_taken` / `max_emergency_logouts`).
  static Future<Map<String, dynamic>?> getEmergencyLogoutData() async {
    try {
      final response = await HttpService().get(
        GlobalState()
            .serverPath('api/v1/runners/me/emergency_logout/availability'),
        headers: {},
        queryParameters: {},
      );

      if (response.statusCode == 200) {
        final d = response.data;
        if (d is Map<String, dynamic>) return d;
        if (d is Map) return Map<String, dynamic>.from(d);
        return null;
      }
      return null;
    } catch (e, st) {
      MonitoringServiceHelper.logError('getEmergencyLogoutData_failed', {
        'error': e.toString(),
        'stackTrace': st.toString(),
      });
      return null;
    }
  }

  static Future<Response?> checkout(
      {Map<String, dynamic>? headers,
      required int jobId,
      Map<String, dynamic>? data}) async {
    try {
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();

      if(position != null){
        data ??= {};
        data.addAll({
          'location' : {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/jobs/$jobId/check_out"),
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

}
