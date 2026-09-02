import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/device_identifier.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/services/iot/config/config_service.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_collector.dart';

/// HTTP service for sending IoT data to the backend
/// Includes configurable timeout and socket error handling
class IotHttp {
  static final Logger _logger = Logger();
  final ConfigService _config;
  final IotDiagnosticsCollector _diagnostics;

  IotHttp({
    ConfigService? config,
    IotDiagnosticsCollector? diagnostics,
  })  : _config = config ?? ConfigService.instance,
        _diagnostics = diagnostics ?? IotDiagnosticsCollector();

  /// Send IoT data (batteries and locations) to backend
  /// Returns true if successful (200/201), false otherwise
  /// Treats socket exceptions as network unavailable
  Future<bool> sendIotData({
    required String endpoint,
    required String userId,
    required List<Map<String, dynamic>> batteries,
    required List<Map<String, dynamic>> locations,
    List<Map<String, dynamic>> deviceStates = const [],
  }) async {
    try {
      _logger.d('[IoT API] Sending: ${batteries.length} batteries, ${locations.length} locations, ${deviceStates.length} device_states');

      final timeout = Duration(seconds: _config.apiTimeout);

      // Get app version and device ID
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceId = await DeviceIdentifier.getDeviceIdOrEmpty();

      // Convert data to API format
      final apiBatteries = batteries.map((b) => {
        'percentage': b['percentage'],
        'collected_at': b['collected_at'],
        if (b['collection_cycle_id'] != null)
          'collection_cycle_id': b['collection_cycle_id'],
      }).toList();

      final apiLocations = locations.map((l) => {
        'lat': l['lat'],
        'long': l['long'],
        'collected_at': l['collected_at'],
        'accuracy': l['accuracy'],
        if (l['alt'] != null) 'alt': l['alt'],
        if (l['alt_accuracy'] != null) 'alt_accuracy': l['alt_accuracy'],
        if (l['heading'] != null) 'heading': l['heading'],
        if (l['heading_accuracy'] != null) 'heading_accuracy': l['heading_accuracy'],
        if (l['speed'] != null) 'speed': l['speed'],
        if (l['speed_accuracy'] != null) 'speed_accuracy': l['speed_accuracy'],
        'is_mocked': (l['is_mocked'] ?? 0) == 1,
        if (l['collection_cycle_id'] != null)
          'collection_cycle_id': l['collection_cycle_id'],
      }).toList();

      final apiDeviceStates = deviceStates.map((d) => {
        'location_services_on': d['location_services_on'],
        'mobile_data_on': d['mobile_data_on'],
        'network_type': d['network_type'],
        'collected_at': d['collected_at'],
        if (d['collection_cycle_id'] != null)
          'collection_cycle_id': d['collection_cycle_id'],
      }).toList();

      final payload = {
        'user_id': userId,
        'device_id': deviceId,
        'app_version': packageInfo.version,
        'schema_version': '1.2',
        'sent_at': DateTime.now().millisecondsSinceEpoch,
        'batteries': apiBatteries,
        'locations': apiLocations,
        'device_states': apiDeviceStates,
      };

      final response = await HttpService().post(
        endpoint,
        data: payload,
        headers: {},
        receiveTimeout: timeout,
        connectTimeout: timeout,
      );

      // Success on 200 or 201
      final success = response.statusCode == 200 || response.statusCode == 201;
      if (success) {
        _logger.d('[IoT API] Success: ${response.statusCode}');
        // Stamp the last successful send time so the foreground fallback in the
        // main isolate (IotForegroundFallback) can detect IoT staleness without
        // racing the bg isolate. Cross-isolate handshake via SharedPreferences;
        // best-effort — never block the success path on it.
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
            'iot_last_send_success_ms',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          // This timestamp is the foreground fallback's only staleness signal;
          // a silent failure here could let the fallback re-fire. Log it.
          _logger.w('[IoT API] Failed to stamp last send time', error: e);
        }
        _logDiagnostic(
          eventName: 'IOT_API_HTTP_SUCCESS',
          userId: userId,
          batteries: batteries,
          locations: locations,
          deviceStates: deviceStates,
        );
      } else {
        _logger.w('[IoT API] Failed: ${response.statusCode}');
        _logDiagnostic(
          eventName: 'IOT_API_HTTP_ERROR',
          userId: userId,
          batteries: batteries,
          locations: locations,
          deviceStates: deviceStates,
          data: {
            'status_code': response.statusCode,
            // Bounded so we never ship a large / PII response body.
            'response_body': _truncate(response.data?.toString(), 300),
          },
        );
      }
      return success;
    } on SocketException catch (e) {
      _logger.w('[IoT API] Network unavailable: ${e.message}');
      _logDiagnostic(
        eventName: 'IOT_API_NETWORK_UNAVAILABLE',
        userId: userId,
        batteries: batteries,
        locations: locations,
        deviceStates: deviceStates,
        data: {
          'error_message': e.message,
          'connectivity': await _currentConnectivity(),
        },
      );
      return false;
    } catch (e,st) {
      _logger.e('[IoT API] Unexpected error', error: e);
      // HttpService catches DioException internally and rethrows it as a plain
      // Exception(e.message), so `e` is almost never a DioException here — the
      // message text is the only surviving signal. Classify off it (with a
      // defensive DioException branch) so this catch-all stops hiding the
      // well-understood network failures (DNS, connect/receive timeout, reset).
      String errorKind;
      int? statusCode;
      String? dioType;
      if (e is DioException) {
        dioType = e.type.name;
        statusCode = e.response?.statusCode;
        errorKind = _classifyDioError(e);
      } else {
        errorKind = classifyNetworkErrorMessage(e.toString());
      }
      // Connectivity at failure time disambiguates the dns_failure bucket:
      // 'none' = truly offline; 'wifi'/'mobile' = "connected" but DNS/portal/
      // carrier failure (the more interesting case for drift).
      final connectivity = await _currentConnectivity();
      _logDiagnostic(
        eventName: 'IOT_API_UNEXPECTED_ERROR',
        userId: userId,
        batteries: batteries,
        locations: locations,
        deviceStates: deviceStates,
        data: {
          'error_kind': errorKind,
          'connectivity': connectivity,
          if (dioType != null) 'dio_type': dioType,
          if (statusCode != null) 'status_code': statusCode,
          'error_type': e.runtimeType.toString(),
          'error_message': e.toString(),
          'stacktrace': st.toString(),
        },
      );
      return false;
    }
  }

  /// Normalizes a Dio failure into a stable, queryable kind so the
  /// IOT_API_UNEXPECTED_ERROR bucket stops conflating distinct causes.
  String _classifyDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'timeout_connect';
      case DioExceptionType.receiveTimeout:
        return 'timeout_receive';
      case DioExceptionType.badResponse:
        return 'bad_response';
      case DioExceptionType.badCertificate:
        return 'bad_certificate';
      case DioExceptionType.cancel:
        return 'cancelled';
      case DioExceptionType.connectionError:
        final msg = (e.message ?? '').toLowerCase();
        return msg.contains('failed host lookup')
            ? 'dns_failure'
            : 'connection_error';
      case DioExceptionType.unknown:
        return 'unknown';
      case DioExceptionType.transformTimeout:
      case DioExceptionType.sendTimeout:
        return 'timeout_send';
    }
  }

  /// Classifies the wrapped network-failure message HttpService produces
  /// (`Exception(dioException.message)`) — the only signal left once the
  /// original DioException type is gone. Mirrors _classifyDioError's vocabulary.
  /// Public + @visibleForTesting because it's fragile string-matching that's
  /// worth guarding with a unit test against the real observed messages.
  @visibleForTesting
  static String classifyNetworkErrorMessage(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('failed host lookup')) return 'dns_failure';
    if (msg.contains('to receive data')) return 'timeout_receive';
    if (msg.contains('to send data')) return 'timeout_send';
    if (msg.contains('took longer')) return 'timeout_connect';
    if (msg.contains('connection reset')) return 'connection_reset';
    if (msg.contains('connection refused')) return 'connection_refused';
    if (msg.contains('software caused') || msg.contains('connection abort')) return 'connection_aborted';
    if (msg.contains('no route to host')) return 'no_route_to_host';
    if (msg.contains('connection errored') || msg.contains('connection failed')) return 'connection_error';
    if (msg.contains('timed out') || msg.contains('timeout')) return 'timeout';
    return 'unknown';
  }

  String? _truncate(String? s, int max) {
    if (s == null) return null;
    return s.length <= max ? s : '${s.substring(0, max)}…';
  }

  /// Connectivity at the moment of an upload failure. Lets us separate a truly
  /// offline device ('none') from one that's "connected" but still failing DNS
  /// (carrier/captive portal) — both otherwise surface only as dns_failure.
  Future<String> _currentConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty) return 'unknown';
      return results.map((r) => r.name).join('+');
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> _logDiagnostic({
    required String userId,
    required String eventName,
    required List<Map<String, dynamic>> batteries,
    required List<Map<String, dynamic>> locations,
    List<Map<String, dynamic>> deviceStates = const [],
    Map<String, dynamic>? data,
  }) async {
    Map<String, dynamic> eventData = {
      'battery_count': batteries.length,
      'location_count': locations.length,
      'device_state_count': deviceStates.length,
      'memory_rss_mb': IotDiagnosticsCollector.getMemoryRssMb(),
      'user_id': userId,
    };
    if (data != null) {
      eventData.addAll(data);
    }
    await _diagnostics.logDiagnostic(eventName, eventData);
  }
}
