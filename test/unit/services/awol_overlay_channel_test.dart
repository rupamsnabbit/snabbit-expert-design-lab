import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/awol_overlay_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methodChannel = MethodChannel('com.snabbit.runner/awol_overlay');

  setUpAll(() {
    // The error path logs via MonitoringServiceHelper, whose lazy singleton
    // graph (GlobalState → AudioPlayer, Coralogix) fires these plugin
    // channels; stub them so their MissingPluginExceptions can't escape as
    // uncaught zone errors.
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
      MethodChannel('cx_flutter_plugin'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
  });

  group('setEnabled', () {
    test('pushes the kill-switch and both fallback image URLs', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        received = call;
        return null;
      });

      await AwolOverlayChannel.setEnabled(
        true,
        breachImageUrl: 'https://cdn/enter.jpg',
        reEnteredImageUrl: 'https://cdn/back.png',
      );

      expect(received?.method, 'setOverlayEnabled');
      // homeCardEnabled is omitted here, so it crosses as its `false` default.
      expect(received?.arguments, {
        'enabled': true,
        'homeCardEnabled': false,
        'breachImageUrl': 'https://cdn/enter.jpg',
        'reEnteredImageUrl': 'https://cdn/back.png',
      });
    });

    test('forwards homeCardEnabled:true into the arguments', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        received = call;
        return null;
      });

      await AwolOverlayChannel.setEnabled(
        true,
        homeCardEnabled: true,
        breachImageUrl: 'https://cdn/enter.jpg',
        reEnteredImageUrl: 'https://cdn/back.png',
      );

      expect(received?.method, 'setOverlayEnabled');
      expect(received?.arguments, {
        'enabled': true,
        'homeCardEnabled': true,
        'breachImageUrl': 'https://cdn/enter.jpg',
        'reEnteredImageUrl': 'https://cdn/back.png',
      });
    });

    test('omitted URLs cross as null (native keeps the placeholder)', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        received = call;
        return null;
      });

      await AwolOverlayChannel.setEnabled(false);

      expect(received?.arguments, {
        'enabled': false,
        'homeCardEnabled': false,
        'breachImageUrl': null,
        'reEnteredImageUrl': null,
      });
    });

    test('never throws when the platform side errors', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(code: 'boom');
      });

      await expectLater(AwolOverlayChannel.setEnabled(true), completes);
    });
  });

  group('sync', () {
    test(
        'without Remote Config: pushes overlay OFF and the bundled CDN '
        'fallback asset URLs', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        received = call;
        return null;
      });

      await AwolOverlayChannel.sync();

      // Safe defaults: both kill-switches (overlay + home card) stay off; the
      // image URLs degrade to the bundled CDN asset paths (RemoteConfigAssets'
      // own fallbacks). The home-card flag reads
      // RemoteConfigKeys.enableAwolV2HomeCard, which returns false when Remote
      // Config is unavailable.
      expect(received?.arguments, {
        'enabled': false,
        'homeCardEnabled': false,
        'breachImageUrl':
            'https://assets-expert.snabbit.com/awol/enter_hotspot.jpg',
        'reEnteredImageUrl':
            'https://assets-expert.snabbit.com/awol/back_in_hotspot.png',
      });
    });
  });
}
