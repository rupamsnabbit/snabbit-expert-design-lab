import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:snabbit_runner/services/analytics/analytics_service.dart';

PackageInfo buildPackageInfo({
  String version = '3.0.0',
  String buildNumber = '161',
}) =>
    PackageInfo(
      appName: 'Snabbit Runner',
      packageName: 'com.snabbit.runner',
      version: version,
      buildNumber: buildNumber,
    );

void main() {
  group('AnalyticsService.versionProperties', () {
    test('maps version name and build number to the RC-facing properties', () {
      final props = AnalyticsService.versionProperties(buildPackageInfo());

      expect(props, {
        'app_version': '3.0.0',
        'app_version_code': '161',
      });
    });

    test('property names match the documented constants', () {
      expect(AnalyticsService.appVersionProperty, 'app_version');
      expect(AnalyticsService.appVersionCodeProperty, 'app_version_code');
    });

    test('emits nothing beyond the two version properties', () {
      final props = AnalyticsService.versionProperties(buildPackageInfo());

      expect(props.keys, hasLength(2));
    });

    test('carries values through verbatim (no normalising/padding)', () {
      final props = AnalyticsService.versionProperties(
        buildPackageInfo(version: '3.1.0-rc.2', buildNumber: '0162'),
      );

      expect(props[AnalyticsService.appVersionProperty], '3.1.0-rc.2');
      expect(props[AnalyticsService.appVersionCodeProperty], '0162');
    });

    test('values stay within the 36-char Firebase user-property limit', () {
      final props = AnalyticsService.versionProperties(buildPackageInfo());

      for (final entry in props.entries) {
        expect(entry.key.length, lessThanOrEqualTo(24));
        expect(entry.value.length, lessThanOrEqualTo(36));
      }
    });
  });
}
