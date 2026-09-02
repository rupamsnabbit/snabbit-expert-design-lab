import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/app_strings.dart';

class SecureStorageService {
  // Private constructor
  SecureStorageService._internal();

  // Singleton instance
  static final SecureStorageService _instance =
      SecureStorageService._internal();

  // Factory constructor
  factory SecureStorageService() => _instance;

  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = AppStrings.accessToken;
  static const _userIdKey = AppStrings.userId;
  static const _phoneNumberKey = AppStrings.phoneNumber;

  /// Write values
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<void> savePhoneNumber(String phoneNumber) async {
    await _storage.write(key: _phoneNumberKey, value: phoneNumber);
  }

  /// Read values
  Future<String?> getAccessToken() async {
    String? accessToken = await _storage.read(key: _accessTokenKey);

    accessToken ??= await _migrateFromSharedPreferences(_accessTokenKey);

    return accessToken;
  }

  Future<String?> getUserId() async {
    String? userId = await _storage.read(key: _userIdKey);

    userId ??= await _migrateFromSharedPreferences(_userIdKey);

    return userId;
  }

  Future<String?> getPhoneNumber() async {
    String? phoneNumber = await _storage.read(key: _phoneNumberKey);

    phoneNumber ??= await _migrateFromSharedPreferences(_phoneNumberKey);

    return phoneNumber;
  }

  /// Delete values
  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<String?> _migrateFromSharedPreferences(
    String key,
  ) async {
    // Migrate from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(key);

      if (value != null) {
        // Migrate to secure storage
        await _storage.write(key: key, value: value);
        // Clean up old storage
        await prefs.remove(key);
      }
      return value;
    } catch (_) {
      return null;
    }
  }
}

class SecureStorageUtils {
  static Future<void> saveAccessToken(String accessToken) async {
    try {
      final secureStorageService = SecureStorageService();
      await secureStorageService.saveAccessToken(accessToken);
    } catch (e) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppStrings.accessToken, accessToken);
      MonitoringServiceHelper.logError("SECURE_STORAGE_SERVICE_FAILED", {
        'task': "SAVING_ACCESS_TOKEN",
        'error': e.toString(),
      });
    }
  }

  static Future<String?> getAccessToken(String debugLabel) async {
    try {
      final service = SecureStorageService();
      final accessToken = await service.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        return accessToken;
      }
    } catch (e) {
      MonitoringServiceHelper.logError("SECURE_STORAGE_SERVICE_FAILED", {
        'task': "RETRIEVING_ACCESS_TOKEN",
        'debug_label': debugLabel,
        'error': e.toString(),
      });
    }
    // Fallback to SharedPreferences (only has a token if SecureStorage failed during save).
    // clearToken() always clears both stores, so no stale values linger here.
    String? fallbackToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      fallbackToken = prefs.getString(AppStrings.accessToken);
    } catch (_) {
      fallbackToken = null;
    }
    if (fallbackToken == null || fallbackToken.isEmpty) {
      // The read resolved to null/empty WITHOUT a storage exception. This is the
      // root cause of the background-isolate current_state 401s: the request then
      // goes out with no Authorization header. Probe the store to root-cause the
      // silent null read (key absent vs present-but-null vs a retry recovering it).
      await _logNullTokenRead(debugLabel);
    }
    return fallbackToken;
  }

  /// Instrumentation-only probe. Runs solely on the null-token path to root-cause
  /// the silent null read seen in the background isolate. Never throws and is
  /// time-bounded so it cannot delay or break the caller.
  static Future<void> _logNullTokenRead(String debugLabel) async {
    bool? containsKey;
    try {
      containsKey = await const FlutterSecureStorage()
          .containsKey(key: AppStrings.accessToken)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Probe itself failed (storage subsystem unavailable in this isolate).
      containsKey = null;
    }

    String retryRead;
    try {
      final retry = await const FlutterSecureStorage()
          .read(key: AppStrings.accessToken)
          .timeout(const Duration(seconds: 3));
      retryRead = (retry == null || retry.isEmpty)
          ? 'still_empty'
          : 'recovered_${retry.length}';
    } catch (e) {
      retryRead = 'error_${e.runtimeType}';
    }

    MonitoringServiceHelper.logWarning("ACCESS_TOKEN_NULL_ON_READ", {
      'debug_label': debugLabel,
      // true only in a background isolate (bg-service or FCM handler); the
      // main/UI isolate keeps this false. Disambiguates fg vs bg null reads.
      'is_bg': GlobalState().isBackgroundIsolate,
      // true  => ciphertext is on disk but read() returned null (cipher/decrypt issue)
      // false => key not visible to this isolate's storage view
      // null  => the probe itself could not reach the store
      'contains_key': containsKey,
      // recovered_N => transient; an immediate retry succeeded (init race)
      // still_empty => persistently null; not a simple race
      // error_*     => read threw on retry
      'retry_read': retryRead,
    });
  }

  static Future<void> clearToken() async {
    try {
      final secureStorage = SecureStorageService();
      await secureStorage.clearAll();
    } catch (e) {
      MonitoringServiceHelper.logError("SECURE_STORAGE_SERVICE_FAILED", {
        'task': "CLEARING_ACCESS_TOKEN",
        'error': e.toString(),
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppStrings.accessToken);
    } catch (_) {}
  }

  static Future<String?> getUserId() async {
    String? userId;
    try {
      final secureStorageService = SecureStorageService();
      userId = await secureStorageService.getUserId();
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString(AppStrings.userId);
      MonitoringServiceHelper.logError("SECURE_STORAGE_SERVICE_FAILED", {
        'task': "RETRIEVING_USER_ID",
        'error': e.toString(),
      });
    }
    return userId;
  }
}
