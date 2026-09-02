// Rollout-safety contract for the AWOL v2 (KMP) stand-down flag.
//
// When `expert_enable_awol_v2_overlay` is ON, partner_home's background AWOL
// path stands down and the native KMP launcher owns the overlay. That makes
// the flag's *default* load-bearing in the opposite direction: if Remote
// Config is unavailable (fresh install, fetch failure, unit test), the getter
// MUST report false so the legacy overlay path keeps running — a true-by-
// accident default would silently kill AWOL alerting for every runner whose
// RC fetch fails.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/providers/overlay_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // OverlayProvider's constructor talks to the native compose_overlay
    // channel (checkPermission / isOverlayVisible). Stub it so construction
    // doesn't raise MissingPluginExceptions in a unit test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.snabbit.runner/compose_overlay/methods'),
      (_) async => false,
    );
  });

  group('OverlayProvider AWOL flag defaults (Remote Config unavailable)', () {
    test('v2 overlay stand-down defaults to OFF so legacy keeps alerting', () {
      final provider = OverlayProvider();
      expect(provider.isAwolV2OverlayEnabled, isFalse,
          reason: 'without RC the legacy path must keep owning the overlay');
    });

    test('legacy + job-AWOL flags also default safe (ship-dark contract)', () {
      final provider = OverlayProvider();
      expect(provider.isAwolOverlayEnabled, isFalse);
      expect(provider.isAwolV2Enabled, isFalse);
    });
  });
}
