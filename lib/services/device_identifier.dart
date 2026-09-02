import 'package:android_id/android_id.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

class DeviceIdentifier {
  static const _storage = FlutterSecureStorage();
  static const _androidIdPlugin = AndroidId();
  static const _storageKey = 'device_id';

  static void _reportError(Object error, StackTrace stackTrace, String reason) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: reason, fatal: false);
  }

  static Future<String> getFinalDeviceId() async {
    String deviceId = '';
    try {
      for (int i = 0; i < 3; i++) {
        if (deviceId.isEmpty) {
          try {
            deviceId = await DeviceIdentifier.getDeviceId();
          } catch (e, st) {
            debugPrint('[DeviceIdentifier] Attempt ${i + 1} failed: $e');
            _reportError(e, st, 'DeviceIdentifier attempt ${i + 1}');
          }
        } else {
          break;
        }
      }
    } finally {
      if (deviceId.isEmpty) {
        debugPrint('[DeviceIdentifier] All attempts failed, falling back to UUID');
        deviceId = await DeviceIdentifier.getDeviceId(forceUuid: true);
      }
    }
    return deviceId;
  }

  static Future<String> getDeviceIdOrEmpty() async {
    try {
      return await DeviceIdentifier.getFinalDeviceId();
    } catch (e, st) {
      debugPrint('[DeviceIdentifier] getDeviceIdOrEmpty failed: $e');
      _reportError(e, st, 'DeviceIdentifier getDeviceIdOrEmpty');
      return "";
    }
  }

  static Future<String> getDeviceId({forceUuid = false}) async {
    // Check if Device ID already exists
    String? deviceId = await _storage.read(key: _storageKey);

    if (deviceId != null && deviceId.isNotEmpty) {
      return deviceId;
    }

    // Generate a new Device ID
    if (Platform.isAndroid && !forceUuid) {
      deviceId = await _androidIdPlugin.getId();
    } else {
      deviceId = generateUniqueId();
    }

    // Only persist non-empty IDs — empty means generation failed,
    // let the retry loop in getFinalDeviceId handle it.
    if (deviceId != null && deviceId.isNotEmpty) {
      await _storage.write(key: _storageKey, value: deviceId);
      return deviceId;
    }

    return "";
  }

  static String generateUniqueId() {
    return const Uuid().v4();
  }
}
