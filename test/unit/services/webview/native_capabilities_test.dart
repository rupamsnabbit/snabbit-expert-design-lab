import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/native_capabilities.dart';

void main() {
  group('NativeCapabilities.intersect', () {
    test('null input yields empty list', () {
      expect(NativeCapabilities.intersect(null), isEmpty);
    });

    test('empty input yields empty list', () {
      expect(NativeCapabilities.intersect(const []), isEmpty);
    });

    test('returns only entries that native supports', () {
      final result = NativeCapabilities.intersect(const [
        'navigate',
        'trackEvent',
        'tokenExpired',
        'dataSync', // not yet supported (Phase 2 action)
      ]);

      expect(result, ['navigate', 'trackEvent', 'tokenExpired']);
    });

    test('preserves the web caller order', () {
      final result = NativeCapabilities.intersect(const [
        'trackEvent',
        'navigate',
      ]);

      expect(result, ['trackEvent', 'navigate']);
    });

    test('exact-match, case-sensitive', () {
      expect(NativeCapabilities.intersect(const ['Navigate']), isEmpty);
      expect(NativeCapabilities.intersect(const ['navigate ']), isEmpty);
    });

    test('ignores asks that native has never heard of', () {
      expect(
        NativeCapabilities.intersect(const ['foo', 'bar', 'baz']),
        isEmpty,
      );
    });

    test('every currently-supported capability is listed', () {
      // Regression guard: if a capability is added, this test should force
      // an explicit update so nobody accidentally ships a rename.
      expect(NativeCapabilities.supported, {
        'navigate',
        'trackEvent',
        'tokenExpired',
        'permissionRequest',
        'captureImage',
        'cancelCapture',
        'releaseCapture',
        'goLiveComplete',
        'deviceStorage',
        'openPerfiosAadhaar',
        'speak',
      });
    });

    test('intersecting the supported set returns all of it', () {
      // What the legacy `onPageCommitVisible` push now passes. It fires before
      // the web has asked for anything, so it reports the whole set rather than
      // the empty list a null ask produces — a push claiming no capabilities
      // silently disables every gated feature on clients that let it win the
      // race against their own requestInitData RPC.
      expect(
        NativeCapabilities.intersect(NativeCapabilities.supported),
        NativeCapabilities.supported.toList(),
      );
    });
  });
}
