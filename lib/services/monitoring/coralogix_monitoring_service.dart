import 'package:cx_flutter_plugin/cx_domain.dart';
import 'package:cx_flutter_plugin/cx_exporter_options.dart';
import 'package:cx_flutter_plugin/cx_flutter_plugin.dart';
import 'package:cx_flutter_plugin/cx_instrumentation_type.dart';
import 'package:cx_flutter_plugin/cx_types.dart';
import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'base_logs_interface.dart';
import 'monitoring_setup.dart';

class CoralogixMonitoringService
    implements MonitoringSetupInterface, BasicLogsInterface {
  static final CoralogixMonitoringService _instance =
      CoralogixMonitoringService._internal();

  factory CoralogixMonitoringService() {
    return _instance;
  }

  CoralogixMonitoringService._internal();

  /// True only after a successful `CxFlutterPlugin.initSdk`. When Coralogix is
  /// disabled via [RemoteConfigKeys.enableCoralogixMonitoring], init is
  /// skipped, this stays false, and every log method no-ops without touching
  /// the platform channel — sparing low-end devices the perf cost of a sink
  /// we're transitioning away from.
  bool _active = false;

  @override
  Future<void> initializeService() async {
    final enabled = RemoteConfigService.instance.getBool(
      RemoteConfigKeys.enableCoralogixMonitoring,
      defaultValue: true,
    );
    if (!enabled) {
      if (kDebugMode) {
        print('Coralogix disabled via Remote Config — skipping init');
      }
      return;
    }
    try {
      var options = CXExporterOptions(
        coralogixDomain: CXDomain.ap1,
        environment: kDebugMode || GlobalState().currentEnv == localEnv
            ? 'DEBUG'
            : GlobalState().currentEnv.name,
        application: 'Snabbit Expert Android',
        version: await GlobalState().currentVersionCode(),
        publicKey: 'cxtp_oMZcWlFeT9p8i4DTGOJJ7mpZQloNPG',
        ignoreUrls: [],
        ignoreErrors: [],
        labels: {'app': 'snabbit_expert_android'},
        sdkSampler: 100,
        mobileVitalsFPSSamplingRate: 150,
        instrumentations: {
          CXInstrumentationType.anr.value: true,
          CXInstrumentationType.custom.value: true,
          CXInstrumentationType.errors.value: true,
          CXInstrumentationType.lifeCycle.value: true,
          CXInstrumentationType.mobileVitals.value: true,
          CXInstrumentationType.network.value: true,
          CXInstrumentationType.userActions.value: true
        },
        collectIPData: true,
        debug: false,
        enableSwizzling: true,
      );

      await CxFlutterPlugin.initSdk(options);
      _active = true;
      if (kDebugMode) {
        print('Coralogix SDK initialized successfully');
      }
    } catch (e) {
      _active = false;
      if (kDebugMode) {
        print('Coralogix SDK initialization failed : $e');
      }
    }
  }

  @override
  Future<void> setUserData(UserProfile user) async {
    if (!_active) return;
    try {
      var userContext = UserMetadata(
        userId: user.id.toString(),
        userName: user.name ?? '',
        userEmail: '', // Email not available in current user model
        userMetadata: {
          'phone': user.phoneNumber,
          'country_code': user.countryCode,
          'gender': user.gender?.value?.name ?? '',
          'status': user.runnerStatus?.name ?? '',
          'language': user.languagePreference ?? '',
          'tier': user.tier?.name ?? '',
          'service_id': user.service?.id?.toString() ?? '',
        },
      );
      await CxFlutterPlugin.setUserContext(userContext);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating Coralogix user context: $e');
      }
    }
  }

  @override
  Future<void> logDebug(String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      await CxFlutterPlugin.log(
        CxLogSeverity.debug,
        message,
        data,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending debug log $message to Coralogix because of: $e');
      }
    }
  }

  @override
  Future<void> logInfo(String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      await CxFlutterPlugin.log(
        CxLogSeverity.info,
        message,
        data,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending info log $message to Coralogix because of: $e');
      }
    }
  }

  @override
  Future<void> logWarning(String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      await CxFlutterPlugin.log(
        CxLogSeverity.warn,
        message,
        data,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending warning log $message to Coralogix because of: $e');
      }
    }
  }

  @override
  Future<void> logError(String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      await CxFlutterPlugin.log(
        CxLogSeverity.error,
        message,
        data,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending error log $message to Coralogix because of: $e');
      }
    }
  }

  @override
  Future<void> logCriticalError(
      String message, Map<String, dynamic> data) async {
    if (!_active) return;
    try {
      await CxFlutterPlugin.log(
        CxLogSeverity.critical,
        message,
        data,
      );
      // Also report as an error for better tracking
      reportError(
        message,
        data,
        StackTrace.current.toString(),
      );
    } catch (e) {
      if (kDebugMode) {
        print(
            'Error sending critical log $message to Coralogix because of: $e');
      }
    }
  }

  // Additional utility methods
  Future<void> setView(String viewName) async {
    if (!_active) return;
    try {
      await CxFlutterPlugin.setView(viewName);
    } catch (e) {
      if (kDebugMode) {
        print('Error setting view $viewName to Coralogix because of: $e');
      }
    }
  }

  Future<void> setLabels(Map<String, dynamic> labels) async {
    if (!_active) return;
    try {
      await CxFlutterPlugin.setLabels(labels);
    } catch (e) {
      if (kDebugMode) {
        print(
            'Error setting labels ${labels.keys} to Coralogix because of: $e');
      }
    }
  }

  Future<void> shutdown() async {
    if (!_active) return;
    try {
      await CxFlutterPlugin.shutdown();
    } catch (e) {
      if (kDebugMode) {
        print('Error shutting down Coralogix because of: $e');
      }
    }
  }

  @override
  Future<dynamic> reportError(
      String message, Map<String, dynamic>? data, String? stackTrace) async {
    if (!_active) return;
    try {
      await CxFlutterPlugin.reportError(
        message,
        data,
        stackTrace,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error reporting error $message to Coralogix because of: $e');
      }
    }
  }
}
