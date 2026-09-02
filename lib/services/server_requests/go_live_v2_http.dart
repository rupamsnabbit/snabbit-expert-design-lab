import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/cluster.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/recommended_shift.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/services/server_requests/go_live_v2_mock_data.dart';

/// Custom exception for Go Live V2 API errors
class GoLiveV2ApiException implements Exception {
  final String message;
  final String? errorCode;

  GoLiveV2ApiException(this.message, {this.errorCode});

  @override
  String toString() => message;
}

/// HTTP service for Go Live V2 API calls
class GoLiveV2Http {
  static const String _tag = '[GoLiveV2Http]';

  // ============================================================
  // MOCK MODE TOGGLE
  // Backed by a private flag and exposed via a kDebugMode-gated
  // getter so release builds always short-circuit to false. Even if
  // some code path flips _useMockData in release (e.g. via reflection
  // or future caller), the public read will still return false and
  // the mock branches stay unreachable.
  // ============================================================
  static bool _useMockData = false;
  static bool get useMockData => kDebugMode && _useMockData;

  /// Enable mock mode for testing. No-op in release builds.
  static void enableMockMode() {
    if (!kDebugMode) return;
    _useMockData = true;
    _log('🧪 MOCK MODE ENABLED - Using mock data for all API calls');
  }

  /// Disable mock mode to use real APIs. No-op in release builds.
  static void disableMockMode() {
    if (!kDebugMode) return;
    _useMockData = false;
    _log('🌐 MOCK MODE DISABLED - Using real API calls');
  }

  /// Helper to log API calls - prints to terminal
  static void _log(String message, {Object? data}) {
    final dataStr = data != null
        ? '\n${const JsonEncoder.withIndent('  ').convert(data)}'
        : '';
    debugPrint('$_tag $message$dataStr');
  } // TODO REMOVE THESE LOGS //TODO REMOVE

  /// GET /v2/go_live/regions
  /// Fetches available regions
  static Future<RegionsResponse> getRegions() async {
    _log('📤 GET /v2/go_live/regions - Request started');

    // Use mock data if enabled
    if (useMockData) {
      _log('🧪 Using MOCK data for getRegions');
      await Future.delayed(GoLiveV2MockData.mockDelay);
      final mockResponse = {
        'regions': [
          {'id': 1, 'name': 'North Region'},
          {'id': 2, 'name': 'South Region'},
          {'id': 3, 'name': 'East Region'},
          {'id': 4, 'name': 'West Region'},
        ]
      };
      _log('📥 GET /v2/go_live/regions - Mock Response', data: mockResponse);
      return RegionsResponse.fromJson(mockResponse);
    }

    try {
      final url = GlobalState().serverPath("api/v2/go_live/regions");
      _log('📤 URL: $url');

      final response = await HttpService().get(url, headers: {});

      _log(
          '📥 GET /v2/go_live/regions - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _log('📥 GET /v2/go_live/regions - Response received',
            data: response.data);
        return RegionsResponse.fromJson(response.data);
      } else {
        _log('❌ GET /v2/go_live/regions - Error response', data: response.data);

        final errorInfo = _extractErrorInfo(response);
        final errorMessage = errorInfo.message ?? 'Failed to fetch regions';
        throw GoLiveV2ApiException(
          '$errorMessage (${response.statusCode})',
          errorCode: errorInfo.code,
        );
      }
    } catch (e) {
      if (e is GoLiveV2ApiException) rethrow;
      _log('❌ GET /v2/go_live/regions - Exception: $e');
      throw GoLiveV2ApiException('Failed to fetch regions: $e');
    }
  }

  /// GET /v2/go_live/clusters_by_tc?region_id=X
  /// Fetches available clusters for the partner's training center and region
  static Future<ClustersResponse> getClusters({
    int? tcId,
    required int regionId,
  }) async {
    _log('📤 GET /v2/go_live/clusters_by_tc - Request started');
    if (tcId != null) {
      _log('📤 Training Center ID: $tcId');
    }
    _log('📤 Region ID: $regionId');

    // Use mock data if enabled
    if (useMockData) {
      _log('🧪 Using MOCK data for getClusters');
      await Future.delayed(GoLiveV2MockData.mockDelay);
      final mockResponse = GoLiveV2MockData.getClustersResponse();
      _log('📥 GET /v2/go_live/clusters_by_tc - Mock Response',
          data: mockResponse);
      return ClustersResponse.fromJson(mockResponse);
    }

    try {
      final url = GlobalState()
          .serverPath("api/v2/go_live/clusters_by_tc?region_id=$regionId");
      _log('📤 URL: $url');

      final response = await HttpService().get(url, headers: {});

      _log(
          '📥 GET /v2/go_live/clusters_by_tc - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _log('📥 GET /v2/go_live/clusters_by_tc - Response received',
            data: response.data);
        return ClustersResponse.fromJson(response.data);
      } else {
        _log('❌ GET /v2/go_live/clusters_by_tc - Error response',
            data: response.data);

        // Extract error message and code from response
        final errorInfo = _extractErrorInfo(response);
        final errorMessage = errorInfo.message ?? 'Failed to fetch clusters';
        throw GoLiveV2ApiException(
          '$errorMessage (${response.statusCode})',
          errorCode: errorInfo.code,
        );
      }
    } catch (e) {
      if (e is GoLiveV2ApiException) rethrow;
      _log('❌ GET /v2/go_live/clusters_by_tc - Exception: $e');
      throw GoLiveV2ApiException('Failed to fetch clusters: $e');
    }
  }

  /// POST /v2/go_live/recommended_shifts
  /// Fetches recommended shifts based on user selections
  static Future<RecommendedShiftsResponse> getRecommendedShifts(
      RecommendedShiftsRequest request) async {
    _log('📤 POST /v2/go_live/recommended_shifts - Request',
        data: request.toJson());

    // Use mock data if enabled
    if (useMockData) {
      _log('🧪 Using MOCK data for getRecommendedShifts');
      await Future.delayed(GoLiveV2MockData.mockDelay);

      Map<String, dynamic> mockResponse;
      if (request.isWeekend) {
        // Calculate times for weekend mock
        final startHourInt = request.startHourRangeMin;
        final endHourInt = (startHourInt + request.shiftDurationMax) % 24;
        final startTime = '${startHourInt.toString().padLeft(2, '0')}:00';
        final endTime = '${endHourInt.toString().padLeft(2, '0')}:00';

        mockResponse = GoLiveV2MockData.getWeekendRecommendedShiftsResponse(
          startTime: startTime,
          endTime: endTime,
          durationHours: request.shiftDurationMax,
        );
      } else {
        mockResponse = GoLiveV2MockData.getWeekdayRecommendedShiftsResponse();
      }

      _log('📥 POST /v2/go_live/recommended_shifts - Mock Response',
          data: mockResponse);
      return RecommendedShiftsResponse.fromJson(mockResponse);
    }

    try {
      final url = GlobalState().serverPath("api/v2/go_live/recommended_shifts");
      _log('📤 URL: $url');

      final response = await HttpService().post(
        url,
        headers: {},
        data: request.toJson(),
      );

      _log(
          '📥 POST /v2/go_live/recommended_shifts - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _log('📥 POST /v2/go_live/recommended_shifts - Response received',
            data: response.data);
        return RecommendedShiftsResponse.fromJson(response.data);
      } else {
        _log('❌ POST /v2/go_live/recommended_shifts - Error response',
            data: response.data);

        // Extract error message and code from response
        final errorInfo = _extractErrorInfo(response);
        final errorMessage =
            errorInfo.message ?? 'Failed to fetch recommended shifts';
        throw GoLiveV2ApiException(
          '$errorMessage (${response.statusCode})',
          errorCode: errorInfo.code,
        );
      }
    } catch (e) {
      if (e is GoLiveV2ApiException) rethrow;
      _log('❌ POST /v2/go_live/recommended_shifts - Exception: $e');
      throw GoLiveV2ApiException('Failed to fetch recommended shifts: $e');
    }
  }

  /// Helper to extract error message and code from response
  static ({String? message, String? code}) _extractErrorInfo(
      Response response) {
    try {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        // Check for detail.errors array (v2 API format)
        final detail = data['detail'] as Map<String, dynamic>?;
        if (detail != null) {
          final errors = detail['errors'] as List<dynamic>?;
          if (errors != null && errors.isNotEmpty) {
            final firstError = errors.first as Map<String, dynamic>?;
            return (
              message: firstError?['message'] as String?,
              code: firstError?['error_message_code'] as String?,
            );
          }
        }

        // Check for errors array (alternative format)
        final errors = data['errors'] as List<dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          final firstError = errors.first as Map<String, dynamic>?;
          return (
            message: firstError?['message'] as String?,
            code: firstError?['error_message_code'] as String?,
          );
        }

        // Check for direct error_code/message fields
        return (
          message: data['message'] as String?,
          code: data['error_code'] as String?,
        );
      }
    } catch (_) {}
    return (message: null, code: null);
  }

  /// POST /v2/go_live/verify_shift
  /// Verifies if a shift is still available
  static Future<VerifyShiftResponse> verifyShift(
      VerifyShiftRequest request) async {
    _log('📤 POST /v2/go_live/verify_shift - Request', data: request.toJson());

    // Use mock data if enabled
    if (useMockData) {
      _log('🧪 Using MOCK data for verifyShift');
      await Future.delayed(const Duration(milliseconds: 500));
      final mockResponse = GoLiveV2MockData.getVerifyShiftResponse();
      _log('📥 POST /v2/go_live/verify_shift - Mock Response',
          data: mockResponse);
      return VerifyShiftResponse.fromJson(mockResponse);
    }

    try {
      final url = GlobalState().serverPath("api/v2/go_live/verify_shift");
      _log('📤 URL: $url');

      final response = await HttpService().post(
        url,
        headers: {},
        data: request.toJson(),
      );

      _log(
          '📥 POST /v2/go_live/verify_shift - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _log('📥 POST /v2/go_live/verify_shift - Response received',
            data: response.data);
        return VerifyShiftResponse.fromJson(response.data);
      } else {
        _log('❌ POST /v2/go_live/verify_shift - Error response',
            data: response.data);

        // Extract error message and code from response
        final errorInfo = _extractErrorInfo(response);
        final errorMessage = errorInfo.message ?? 'Failed to verify shift';
        throw GoLiveV2ApiException(
          '$errorMessage (${response.statusCode})',
          errorCode: errorInfo.code,
        );
      }
    } catch (e) {
      if (e is GoLiveV2ApiException) rethrow;
      _log('❌ POST /v2/go_live/verify_shift - Exception: $e');
      throw GoLiveV2ApiException('Failed to verify shift: $e');
    }
  }

  /// POST /v2/go_live/confirm_shift
  /// Confirms the selected shift
  static Future<ConfirmShiftResponse> confirmShift(
      ConfirmShiftRequest request) async {
    _log('📤 POST /v2/go_live/confirm_shift - Request', data: request.toJson());

    // Use mock data if enabled
    if (useMockData) {
      _log('🧪 Using MOCK data for confirmShift');
      await Future.delayed(const Duration(milliseconds: 1000));
      final mockResponse = GoLiveV2MockData.getConfirmShiftResponse();
      _log('📥 POST /v2/go_live/confirm_shift - Mock Response',
          data: mockResponse);
      return ConfirmShiftResponse.fromJson(mockResponse);
    }

    try {
      final url = GlobalState().serverPath("api/v2/go_live/confirm_shift");
      _log('📤 URL: $url');

      final response = await HttpService().post(
        url,
        headers: {},
        data: request.toJson(),
      );

      _log(
          '📥 POST /v2/go_live/confirm_shift - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _log('📥 POST /v2/go_live/confirm_shift - Response received',
            data: response.data);
        return ConfirmShiftResponse.fromJson(response.data);
      } else {
        _log('❌ POST /v2/go_live/confirm_shift - Error response',
            data: response.data);

        // Extract error message and code from response
        final errorInfo = _extractErrorInfo(response);
        final errorMessage = errorInfo.message ?? 'Failed to confirm shift';
        throw GoLiveV2ApiException(
          '$errorMessage (${response.statusCode})',
          errorCode: errorInfo.code,
        );
      }
    } catch (e) {
      if (e is GoLiveV2ApiException) rethrow;
      _log('❌ POST /v2/go_live/confirm_shift - Exception: $e');
      throw GoLiveV2ApiException('Failed to confirm shift: $e');
    }
  }
}

// ============ Request/Response Models for verify_shift ============

/// Request model for POST /v2/go_live/verify_shift
class VerifyShiftRequest {
  final int hoodId;
  final ShiftTimingsData shiftTimings;
  final bool isWeekend;

  VerifyShiftRequest({
    required this.hoodId,
    required this.shiftTimings,
    required this.isWeekend,
  });

  Map<String, dynamic> toJson() {
    return {
      'hood_id': hoodId,
      'shift_timings': shiftTimings.toJson(),
      'is_weekend': isWeekend,
    };
  }
}

/// Response model for POST /v2/go_live/verify_shift
class VerifyShiftResponse {
  final bool isAvailable;
  final List<ApiError> errors;

  VerifyShiftResponse({
    required this.isAvailable,
    required this.errors,
  });

  factory VerifyShiftResponse.fromJson(Map<String, dynamic> json) {
    return VerifyShiftResponse(
      isAvailable: json['is_available'] as bool? ?? false,
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => ApiError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get hasErrors => errors.isNotEmpty;
}

// ============ Request/Response Models for confirm_shift ============

/// Shift selection data for confirm_shift request
class ShiftSelectionData {
  final int hoodId;
  final ShiftTimingsData shiftTimings;
  final int rateCardId;

  ShiftSelectionData({
    required this.hoodId,
    required this.shiftTimings,
    required this.rateCardId,
  });

  Map<String, dynamic> toJson() {
    return {
      'hood_id': hoodId,
      'shift_timings': shiftTimings.toJson(),
      'rate_card_id': rateCardId,
    };
  }
}

/// Shift timings data
class ShiftTimingsData {
  final String start;
  final String end;

  ShiftTimingsData({
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
    };
  }
}

/// Request model for POST /v2/go_live/confirm_shift
class ConfirmShiftRequest {
  final ShiftSelectionData? weekdaySelection;
  final ShiftSelectionData? weekendSelection;

  ConfirmShiftRequest({
    this.weekdaySelection,
    this.weekendSelection,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (weekdaySelection != null) {
      json['weekday_selection'] = weekdaySelection!.toJson();
    }
    if (weekendSelection != null) {
      json['weekend_selection'] = weekendSelection!.toJson();
    }
    return json;
  }
}

/// Response model for POST /v2/go_live/confirm_shift
class ConfirmShiftResponse {
  final bool success;
  final String? message;
  final List<ApiError> errors;

  ConfirmShiftResponse({
    required this.success,
    this.message,
    required this.errors,
  });

  factory ConfirmShiftResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmShiftResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => ApiError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get hasErrors => errors.isNotEmpty;
}

/// Common API error model
class ApiError {
  final String message;
  final String errorMessageCode;
  final dynamic data;

  ApiError({
    required this.message,
    required this.errorMessageCode,
    this.data,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      message: json['message'] as String? ?? '',
      errorMessageCode: json['error_message_code'] as String? ?? '',
      data: json['data'],
    );
  }
}

// ============ Request/Response Models for regions ============

/// Region model
class Region {
  final int id;
  final String name;

  Region({
    required this.id,
    required this.name,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final capitalizedName =
        name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
    return Region(
      id: json['id'] as int,
      name: capitalizedName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

/// Response model for GET /v2/go_live/regions
class RegionsResponse {
  final List<Region> regions;

  RegionsResponse({
    required this.regions,
  });

  factory RegionsResponse.fromJson(Map<String, dynamic> json) {
    return RegionsResponse(
      regions: (json['regions'] as List<dynamic>?)
              ?.map((e) => Region.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
