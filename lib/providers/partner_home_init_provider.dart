import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:snabbit_runner/main.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

import '../services/iot/config/config_sync.dart';

/// Provider for handling PartnerHome screen initialization and background tasks
class PartnerHomeInitProvider extends ChangeNotifier {
  bool _monitoringInitialized = false;
  bool _configSyncStarted = false;

  /// Completes once [initializeServices] has run — i.e. ConfigSync finished and
  /// the IoT foreground service's `startService()` has been requested. The MQTT
  /// cohort's KMP switch awaits this (see `RegistrationNavigation`) so the FGS
  /// starts while Flutter is still foregrounded, BEFORE the native KMP Activity
  /// backgrounds the engine — otherwise the start races the pause and the IoT
  /// service often never starts for the cohort. Completes at most once; a second
  /// call (already-initialized guard) leaves it completed.
  final Completer<void> _servicesReady = Completer<void>();
  Future<void> get servicesReady => _servicesReady.future;

  Future<void> initializeServices(BuildContext _) async {
    // ConfigSync must run first so SharedPreferences has the correct
    // iot_config_api_enabled value before the background service reads it.
    // Previous order caused a race condition on first install where the
    // background service read the default (false) before ConfigSync wrote true.
    await _startIotConfigSync();
    await _initializeBackgroundMonitoringService();
    if (!_servicesReady.isCompleted) _servicesReady.complete();
  }

  /// Initialize all services
  Future<void> _initializeBackgroundMonitoringService() async {
    if (_monitoringInitialized) return;

    try {
      _monitoringInitialized = true;
      initializeService();
    } catch (e, stackTrace) {
      // Handle error appropriately
      MonitoringServiceHelper.logError("failed to initialize services", {
        "error": e.toString(),
        "stack_trace": stackTrace.toString(),
      });
    }
  }

  /// Start IoT ConfigSync in an isolate
  Future<void> _startIotConfigSync() async {
    if (_configSyncStarted) return;

    try {
      final configSync = ConfigSync();
      configSync.onConfigUpdated = () {
        FlutterBackgroundService().invoke('iot_config_updated');
      };
      await configSync.startListening().catchError((_) {});
      _configSyncStarted = true;
    } catch (e, stackTrace) {
      MonitoringServiceHelper.logError("failed to start iot services", {
        "error": e.toString(),
        "stack_trace": stackTrace.toString(),
      });
    }
  }
}
