import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

class RootDetectionService {
  static const MethodChannel _channel =
      MethodChannel('com.snabbit.runner/security');

  static Future<RootStatus> isDeviceRooted() async {
    try {
      final res = await _channel.invokeMethod('isRootedWithReason');
      final status = RootStatus.fromJson(res);
      return status;
    } catch (e) {
      MonitoringServiceHelper.logError("ROOT_DETECTION_SERVICE_FAILED", {
        'error': e.toString(),
      });
      return RootStatus();
    }
  }

  static performRootCheck() async {
    if (isRootDetectionEnabled) {
      final rootStatus = await isDeviceRooted();

      if (rootStatus.isRooted) {
        final AndroidDeviceInfo androidInfo =
            await DeviceInfoPlugin().androidInfo;
        ClevertapSetup.logEvent(TrackingEvents.rootedDevice, {
          'device_model': androidInfo.model,
          'os_version': 'Android ${androidInfo.version.release}',
          'device_manufacturer': androidInfo.manufacturer,
          'reason': rootStatus.reason,
        });
      }
    }
  }

  static bool get isRootDetectionEnabled {
    return RemoteConfigService.instance.getBool(
      RemoteConfigKeys.expertRootDetectionEnabled,
      defaultValue: false,
    );
  }
}


class RootStatus {
  final bool isRooted;
  final String? reason;

  // Standard constructor
  const RootStatus({
    this.isRooted=false,
    this.reason,
  });

  /// Factory constructor to create an instance from a JSON map.
  /// Handles potential nulls gracefully.
  factory RootStatus.fromJson(Map<Object?, Object?> json) {
    return RootStatus(
      isRooted: json['is_rooted'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }

  /// Optional: Converts the object back to JSON for logging or storage.
  Map<String, dynamic> toJson() {
    return {
      'is_rooted': isRooted,
      'reason': reason,
    };
  }

  @override
  String toString() => 'RootStatus(isRooted: $isRooted, reason: $reason)';
}