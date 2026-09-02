import 'package:dio/dio.dart';
import '../models/auto_ot/auto_ot_models.dart';
import 'globals.dart';
import 'http_service.dart';

/// HTTP service for Auto-OT (Auto Overtime) API calls
///
/// Handles all network requests related to accepting or denying
/// Auto-OT requests from the backend.
class AutoOtHttp {
  /// Accepts an Auto-OT request
  ///
  /// Makes a POST request to accept the overtime shift.
  /// Returns the response if successful, null otherwise.
  static Future<Response?> acceptOt({
    required int requestId,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/auto-ot/requests/$requestId/accept"),
        headers: headers ?? {},
        data: data ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Fetches OT data after provisional attendance is marked.
  ///
  /// Called when a runner responds to provisional attendance via any CTA.
  /// The response has the same structure as the auto_ot object from current_state.
  /// Returns the response if successful, null otherwise.
  static Future<Response?> fetchOtOnAttendance({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/auto-ot/start-ot/request"),
        headers: headers ?? {},
        data: data ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Denies an Auto-OT request
  ///
  /// Makes a POST request to deny the overtime shift with the specified reason.
  /// [reason] determines the denial reason sent to the backend.
  /// Returns the response if successful, null otherwise.
  static Future<Response?> denyOt({
    required int requestId,
    required AutoOtDenyReason reason,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final requestData = {
        'rejection_reason': reason.toString(),
        ...?data,
      };

      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/auto-ot/requests/$requestId/reject"),
        headers: headers ?? {},
        data: requestData,
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}
