import 'package:snabbit_runner/providers/user_profile.dart';
import 'base_logs_interface.dart';
import 'monitoring_service_store.dart';
import 'monitoring_setup.dart';

class MonitoringServiceHelper {
  static get defaultEventLogServices =>
      MonitoringServiceStore.instance.getServices<BasicLogsInterface>();

  static get defaultDataSetupServices =>
      MonitoringServiceStore.instance.getServices<MonitoringSetupInterface>();

  // Initialize all analytics services
  static Future<void> initializeAllServices() async {
    for (MonitoringSetupInterface service in defaultDataSetupServices) {
      await service.initializeService();
    }
  }

  // Set user data across all analytics services
  static Future<void> setUserDataAcrossServices(UserProfile user) async {
    for (MonitoringSetupInterface service in defaultDataSetupServices) {
      await service.setUserData(user);
    }
  }

  // Log debug across all logging services
  static Future<void> logDebug(
      String message, Map<String, dynamic> data) async {
    for (BasicLogsInterface service in defaultEventLogServices) {
      await service.logDebug(message, data);
    }
  }

  // Log info across all logging services
  static Future<void> logInfo(String message, Map<String, dynamic> data) async {
    for (BasicLogsInterface service in defaultEventLogServices) {
      await service.logInfo(message, data);
    }
  }

  // Log warning across all logging services
  static Future<void> logWarning(
      String message, Map<String, dynamic> data) async {
    for (BasicLogsInterface service in defaultEventLogServices) {
      await service.logWarning(message, data);
    }
  }

  // Log error across all logging services
  static Future<void> logError(
      String message, Map<String, dynamic> data) async {
    for (BasicLogsInterface service in defaultEventLogServices) {
      await service.logError(message, data);
    }
  }

  // Log critical error across all logging services
  static Future<void> logCriticalError(
      String message, Map<String, dynamic> data) async {
    for (BasicLogsInterface service in defaultEventLogServices) {
      await service.logCriticalError(message, data);
    }
  }

  static Future<void> reportError(
      String message, Map<String, dynamic> data, String stackTrace) async {
    for (BasicLogsInterface service in defaultEventLogServices) {
      await service.reportError(
        message,
        data,
        stackTrace,
      );
    }
  }
}
