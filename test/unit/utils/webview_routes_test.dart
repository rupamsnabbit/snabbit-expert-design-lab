import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';

void main() {
  group('resolveLunchSlotsPath', () {
    test('uses the Remote Config path when one is configured', () {
      expect(resolveLunchSlotsPath('v2/lunch-slots'), 'v2/lunch-slots');
    });

    test('trims surrounding whitespace off a configured path', () {
      expect(resolveLunchSlotsPath('  v2/lunch-slots  '), 'v2/lunch-slots');
    });

    test('falls back to the baked-in default when the key is empty', () {
      expect(resolveLunchSlotsPath(''), WebviewRoutes.lunchSlots);
    });

    test('falls back when the key holds only whitespace', () {
      // Guards against a blank RC value sending the banner to the bare base URL.
      expect(resolveLunchSlotsPath('   '), WebviewRoutes.lunchSlots);
    });

    test('baked-in default is the lunch-slot page path', () {
      expect(WebviewRoutes.lunchSlots, 'v1/lunch');
    });
  });
}
