import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

/// Remote Config Service
///
/// Singleton service for managing Firebase Remote Config.
/// Provides methods to fetch, activate, and retrieve remote config values.
class RemoteConfigService {
  // Singleton instance
  static final RemoteConfigService _instance = RemoteConfigService._internal();

  static RemoteConfigService get instance => _instance;

  factory RemoteConfigService() => _instance;

  RemoteConfigService._internal();

  FirebaseRemoteConfig? _remoteConfig;
  bool _isInitialized = false;
  StreamSubscription<RemoteConfigUpdate>? _updateSubscription;
  bool _isListeningForUpdates = false;
  final StreamController<Set<String>> _updatedKeysController =
      StreamController<Set<String>>.broadcast();

  /// Configured fetch settings, retained so [forceRefetch] can restore the
  /// normal throttle after a one-off bypass.
  Duration _fetchTimeout = const Duration(seconds: 60);
  Duration _minimumFetchInterval = const Duration(hours: 1);

  /// Get the Firebase Remote Config instance
  FirebaseRemoteConfig? get remoteConfig => _remoteConfig;

  /// Check if remote config is initialized
  bool get isInitialized => _isInitialized;

  /// Check if real-time update listening is active
  bool get isListeningForUpdates => _isListeningForUpdates;

  /// Stream of updated keys when Remote Config changes are received and activated
  Stream<Set<String>> get onUpdatedKeys => _updatedKeysController.stream;

  /// Convenience stream that emits true whenever a specific [key] is updated
  Stream<bool> onKeyUpdated(String key) =>
      onUpdatedKeys.map((keys) => keys.contains(key)).where((v) => v);

  /// Initialize Firebase Remote Config
  ///
  /// [fetchTimeout] - Maximum time to wait for fetch request (default: 60 seconds)
  /// [minimumFetchInterval] - Minimum interval between fetch requests (default: 1 hour in production, 0 in debug)
  /// [defaultParameters] - Default values to use before fetching from server
  Future<bool> initialize({
    Duration fetchTimeout = const Duration(seconds: 60),
    Duration minimumFetchInterval = const Duration(hours: 1),
    Map<String, dynamic>? defaultParameters,
    bool listenForUpdates = true,
  }) async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set config settings
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: fetchTimeout,
          minimumFetchInterval: minimumFetchInterval,
        ),
      );
      _fetchTimeout = fetchTimeout;
      _minimumFetchInterval = minimumFetchInterval;

      // Set default parameters if provided
      if (defaultParameters != null) {
        await _remoteConfig!.setDefaults(defaultParameters);
      }

      // Start listening for real-time updates if enabled
      if (listenForUpdates) {
        _startRealtimeUpdates();
      }

      // Fetch and activate
      await fetchAndActivate();

      _isInitialized = true;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Start listening to real-time Remote Config updates and auto-activate when notified
  void _startRealtimeUpdates() {
    if (_remoteConfig == null || _isListeningForUpdates) return;

    try {
      _updateSubscription = _remoteConfig!.onConfigUpdated
          .listen((RemoteConfigUpdate update) async {
        try {
          final activated = await _remoteConfig!.fetchAndActivate();
          if (activated) {
            // Emit updated keys only after successful activation
            _updatedKeysController.add(update.updatedKeys);
          }
        } catch (e) {
          // Error activating after update
        }
      });

      _isListeningForUpdates = true;
    } catch (e) {
      _isListeningForUpdates = false;
    }
  }

  /// Stop listening to real-time Remote Config updates
  Future<void> stopRealtimeUpdates() async {
    try {
      await _updateSubscription?.cancel();
    } catch (_) {}
    _updateSubscription = null;
    _isListeningForUpdates = false;
  }

  /// Dispose resources held by the service
  Future<void> dispose() async {
    await stopRealtimeUpdates();
    await _updatedKeysController.close();
  }

  /// Fetch and activate remote config values
  ///
  /// Returns true if new values were fetched and activated
  Future<bool> fetchAndActivate() async {
    try {
      if (_remoteConfig == null) {
        return false;
      }

      final activated = await _remoteConfig!.fetchAndActivate();
      return activated;
    } catch (e) {
      return false;
    }
  }

  /// Fetches and activates while bypassing [minimumFetchInterval] for this one
  /// call, then restores the configured throttle. Use right after user
  /// targeting properties change (e.g. at login) so server-side conditions
  /// re-evaluate this session instead of waiting out the throttle.
  Future<bool> forceRefetch() async {
    if (_remoteConfig == null) return false;
    try {
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: _fetchTimeout,
          minimumFetchInterval: Duration.zero,
        ),
      );
      return await fetchAndActivate();
    } finally {
      // Always restore the normal throttle so other fetch paths stay throttled.
      try {
        await _remoteConfig!.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: _fetchTimeout,
            minimumFetchInterval: _minimumFetchInterval,
          ),
        );
      } catch (e) {
        debugPrint(
            'RemoteConfigService: failed to restore fetch settings - $e');
      }
    }
  }

  /// Get string value from remote config
  /// Returns defaultValue if the key doesn't exist in Remote Config
  String getString(String key, {String defaultValue = ''}) {
    try {
      // Firebase getString returns '' (not null) for missing keys, so the
      // `?? defaultValue` never fired — check existence first, like getInt.
      if (!hasKey(key)) {
        return defaultValue;
      }
      return _remoteConfig?.getString(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Get int value from remote config
  /// Returns defaultValue if the key doesn't exist in Remote Config
  int getInt(String key, {int defaultValue = 0}) {
    try {
      // Firebase getInt returns 0 for missing keys, so check existence first
      if (!hasKey(key)) {
        return defaultValue;
      }
      return _remoteConfig?.getInt(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Get double value from remote config
  /// Returns defaultValue if the key doesn't exist in Remote Config
  double getDouble(String key, {double defaultValue = 0.0}) {
    try {
      // Firebase getDouble returns 0.0 for missing keys, so check existence first
      if (!hasKey(key)) {
        return defaultValue;
      }
      return _remoteConfig?.getDouble(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Get bool value from remote config
  /// Returns defaultValue if the key doesn't exist in Remote Config
  bool getBool(String key, {bool defaultValue = false}) {
    try {
      // Firebase getBool returns false for missing keys, so check existence first
      if (!hasKey(key)) {
        return defaultValue;
      }
      return _remoteConfig?.getBool(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Get JSON value from remote config and decode it
  ///
  /// Returns null if the value is not valid JSON
  Map<String, dynamic>? getJson(String key) {
    try {
      final value = _remoteConfig?.getString(key);
      if (value == null || value.isEmpty) return null;
      return json.decode(value) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Get list value from remote config
  ///
  /// Returns null if the value is not a valid JSON array
  List<dynamic>? getList(String key) {
    try {
      final value = _remoteConfig?.getString(key);
      if (value == null || value.isEmpty) return null;
      return json.decode(value) as List<dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Get list of strings from remote config
  List<String> getStringList(String key,
      {List<String> defaultValue = const []}) {
    try {
      final list = getList(key);
      if (list == null) return defaultValue;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return defaultValue;
    }
  }

  /// Get all remote config values
  Map<String, dynamic> getAllValues() {
    try {
      final keys = _remoteConfig?.getAll();
      if (keys == null) return {};

      final Map<String, dynamic> result = {};
      keys.forEach((key, value) {
        result[key] = value.asString();
      });
      return result;
    } catch (e) {
      return {};
    }
  }

  /// Get the last fetch time
  DateTime? getLastFetchTime() {
    return _remoteConfig?.lastFetchTime;
  }

  /// Get the last fetch status
  RemoteConfigFetchStatus? getLastFetchStatus() {
    return _remoteConfig?.lastFetchStatus;
  }

  /// Check if a key exists in remote config
  bool hasKey(String key) {
    try {
      return _remoteConfig?.getAll().containsKey(key) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set defaults for remote config
  ///
  /// Useful for providing fallback values before remote values are fetched
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    try {
      await _remoteConfig?.setDefaults(defaults);
    } catch (e) {
      // Error setting defaults
    }
  }

  /// Get int value from remote config
  int getNonZeroInt(String key, {required int defaultValue}) {
    try {
      final val = _remoteConfig?.getInt(key) ?? defaultValue;
      if (val == 0) {
        return defaultValue;
      }
      return val;
    } catch (e) {
      debugPrint('RemoteConfigService: Error getting int for key $key - $e');
      return defaultValue;
    }
  }
}
