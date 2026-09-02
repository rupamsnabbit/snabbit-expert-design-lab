import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Singleton service for managing Firebase Analytics user properties.
///
/// Sets targeting properties (cluster_id, region_id, training_center_id,
/// service_id, build_type, app_version, app_version_code) used by Firebase
/// Remote Config conditions. Each property must also be registered in Firebase
/// Analytics → Custom definitions before it appears in the RC condition
/// dropdown.
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Set user targeting properties for Remote Config conditions.
  void setUserTargetingProperties({
    int? clusterId,
    int? regionId,
    int? trainingCenterId,
    int? serviceId,
  }) {
    try {
      if (clusterId != null) {
        unawaited(_analytics.setUserProperty(
          name: 'cluster_id',
          value: clusterId.toString(),
        ));
      }
      if (regionId != null) {
        unawaited(_analytics.setUserProperty(
          name: 'region_id',
          value: regionId.toString(),
        ));
      }
      if (trainingCenterId != null) {
        unawaited(_analytics.setUserProperty(
          name: 'training_center_id',
          value: trainingCenterId.toString(),
        ));
      }
      if (serviceId != null) {
        unawaited(_analytics.setUserProperty(
          name: 'service_id',
          value: serviceId.toString(),
        ));
      }
      // Compile-time constant — set unconditionally so RC can target
      // debug builds (e.g. opt every dev install into a feature
      // without affecting prod users). Idempotent on repeat calls.
      unawaited(_analytics.setUserProperty(
        name: 'build_type',
        value: kDebugMode ? 'debug' : 'release',
      ));
    } catch (_) {
      // Silently ignore analytics errors to avoid disrupting app flow
    }
  }

  /// Firebase Analytics user-property names carrying the running build.
  ///
  /// `app_version` is the version *name* (`3.0.0`) — string comparisons only.
  /// `app_version_code` is the Android version *code* / build number (`161`),
  /// which Remote Config can compare numerically (`>=`, `<`, …), so prefer it
  /// for "this build and newer" conditions.
  static const String appVersionProperty = 'app_version';
  static const String appVersionCodeProperty = 'app_version_code';

  /// The user properties derived from [info], as sent to Firebase Analytics.
  @visibleForTesting
  static Map<String, String> versionProperties(PackageInfo info) => {
        appVersionProperty: info.version,
        appVersionCodeProperty: info.buildNumber,
      };

  /// Mirror the running build's version into Firebase Analytics user
  /// properties so Remote Config conditions can target specific app versions
  /// via a "User property" condition.
  ///
  /// Call this once per launch *before* the session's first Remote Config
  /// fetch (see `main.dart`) so that fetch is likely to carry the values.
  ///
  /// Best-effort ordering, not a guarantee: awaiting only means the native
  /// SDK was *invoked* — it commits user properties on its own worker thread.
  /// So a freshly upgraded install can still evaluate one fetch against the
  /// previous build's values, which persist until overwritten.
  Future<void> setAppVersionProperties() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      // Awaited rather than fire-and-forget to order these ahead of the
      // Remote Config fetch; costs ~ms next to the network call that follows.
      await Future.wait(
        versionProperties(info).entries.map(
              (entry) => _analytics.setUserProperty(
                name: entry.key,
                value: entry.value,
              ),
            ),
      );
    } catch (e) {
      // Log but don't rethrow — analytics failures must not disrupt boot.
      unawaited(MonitoringServiceHelper.logError(
        'failed to set firebase analytics app version properties',
        {'error': e.toString()},
      ));
    }
  }

  /// Set the Firebase Analytics user id so events (including `app_remove`)
  /// can be mapped back to a backend user in the BigQuery export, which is
  /// otherwise anonymous (only `user_pseudo_id` is populated). Mirrored into
  /// an `account_id` user property for easier querying/debugging.
  void setUserId(String userId) {
    try {
      unawaited(_analytics.setUserId(id: userId));
      unawaited(_analytics.setUserProperty(
        name: 'account_id',
        value: userId,
      ));
    } catch (e) {
      // Log but don't rethrow — analytics failures must not disrupt app flow.
      unawaited(MonitoringServiceHelper.logError(
        'failed to set firebase analytics user id',
        {'error': e.toString()},
      ));
    }
  }
}
