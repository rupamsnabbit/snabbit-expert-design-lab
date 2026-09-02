import 'package:flutter/foundation.dart';
import '../globals.dart';
import 'base14_monitoring_service.dart';
import 'coralogix_monitoring_service.dart';
import 'monitoring_setup.dart';

class MonitoringServiceStore {
  // Singleton instance
  static MonitoringServiceStore? _instance;

  // Private constructor
  MonitoringServiceStore._();

  // Singleton factory method
  static MonitoringServiceStore get instance {
    _instance ??= MonitoringServiceStore._();
    return _instance!;
  }

  // List of all analytics services. Order matters: initializeAllServices in
  // MonitoringServiceHelper awaits each service sequentially, so we init
  // Base14 first — we're transitioning to it as the primary sink and don't
  // want Coralogix's init to gate Scout's readiness.
  final List<MonitoringSetupInterface> analyticsServices = [
    // base14 (Scout) — registered in ALL envs including local, so local dev
    // telemetry can reach the non-prod platform when enabled. Kept fully inert
    // by the RC kill-switch (expert_enable_base14_monitoring, default OFF) and
    // the empty-endpoint check inside Base14MonitoringService.initializeService
    // until configured; still receives fan-out calls (incl. KMP crash reports).
    Base14MonitoringService(),
    if (!kDebugMode || GlobalState().currentEnv != localEnv)
      CoralogixMonitoringService(),
    // Add other analytics services here as they are implemented
  ];

  // Generic method to get services of a specific type
  List<T> getServices<T>() {
    List<T> result = [];
    for (var service in analyticsServices) {
      if (service is T) {
        result.add(service as T);
      }
    }
    return result;
  }

  // Shutdown all analytics services
  Future<void> shutdownAllServices() async {
    for (var service in analyticsServices) {
      if (service is CoralogixMonitoringService) {
        await service.shutdown();
      }
      // Add shutdown calls for other services as they are implemented
    }
  }
}
