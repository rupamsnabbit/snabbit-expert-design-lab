import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:snabbit_runner/services/debug/network_inspector.dart';
import 'package:snabbit_runner/services/iot/config/config_service.dart';

/// HTTP service for sending IoT data to the backend
/// Includes configurable timeout and socket error handling
class HttpService {
  static final Logger _logger = Logger();

  final Dio _dio;
  final ConfigService _config;

  HttpService({
    Dio? dio,
    ConfigService? config,
  })  : _dio = dio ?? Dio(),
        _config = config ?? ConfigService.instance {
    // Capture IoT (atlas-iot) traffic in the debug network inspector.
    DebugNetworkInspector.instance.attach(_dio);
  }

  /// Send IoT data (batteries and locations) to backend
  /// Returns true if successful (200/201), false otherwise
  /// Treats socket exceptions as network unavailable
  Future<bool> sendIotData({
    required String endpoint,
    required String userId,
    required List<Map<String, dynamic>> batteries,
    required List<Map<String, dynamic>> locations,
  }) async {
    try {
      _logger.d(
          '[IoT API] Sending: ${batteries.length} batteries, ${locations.length} locations');

      final timeout = Duration(seconds: _config.apiTimeout);

      // Get app version and device ID
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      String deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      } else {
        deviceId = 'unknown';
      }

      // Convert data to API format
      final apiBatteries = batteries
          .map((b) => {
                'percentage': b['percentage'],
                'collected_at': b['collected_at'],
              })
          .toList();

      final apiLocations = locations
          .map((l) => {
                'lat': l['lat'],
                'long': l['long'],
                'collected_at': l['collected_at'],
                'accuracy': l['accuracy'],
                if (l['alt'] != null) 'alt': l['alt'],
                if (l['alt_accuracy'] != null)
                  'alt_accuracy': l['alt_accuracy'],
                if (l['heading'] != null) 'heading': l['heading'],
                if (l['heading_accuracy'] != null)
                  'heading_accuracy': l['heading_accuracy'],
                if (l['speed'] != null) 'speed': l['speed'],
                if (l['speed_accuracy'] != null)
                  'speed_accuracy': l['speed_accuracy'],
                'is_mocked': (l['is_mocked'] ?? 0) == 1,
              })
          .toList();

      final payload = {
        'user_id': userId,
        'device_id': deviceId,
        'app_version': packageInfo.version,
        'schema_version': '1.0',
        'sent_at': DateTime.now().millisecondsSinceEpoch,
        'batteries': apiBatteries,
        'locations': apiLocations,
      };

      final response = await _dio.post(
        endpoint,
        data: payload,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );

      // Success on 200 or 201
      final success = response.statusCode == 200 || response.statusCode == 201;
      if (success) {
        _logger.d('[IoT API] Success: ${response.statusCode}');
      } else {
        _logger.w('[IoT API] Failed: ${response.statusCode}');
      }
      return success;
    } on SocketException catch (e) {
      _logger.w('[IoT API] Network unavailable: ${e.message}');
      return false;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _logger.w('[IoT API] Timeout: ${e.type}');
        return false;
      }
      if (e.error is SocketException) {
        _logger.w('[IoT API] Network error');
        return false;
      }
      _logger.w('[IoT API] Error: ${e.response?.statusCode} - ${e.message}');
      return false;
    } catch (e) {
      _logger.e('[IoT API] Unexpected error', error: e);
      return false;
    }
  }
}
