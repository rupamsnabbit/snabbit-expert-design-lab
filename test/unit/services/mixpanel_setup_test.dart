import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';

/// Verifies the post-migration MixpanelSetup facade forwards to the KMP
/// analytics MethodChannel and merges Dart-side super properties (the
/// native `mixpanel_flutter` SDK is gone).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.snabbit.runner/analytics');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    MixpanelSetup.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('MixpanelSetup.logEvent', () {
    test('forwards the event to the channel track method', () async {
      await MixpanelSetup.logEvent('job_started', {'job_id': '42'});

      expect(calls, hasLength(1));
      expect(calls.single.method, 'track');
      expect(calls.single.arguments['name'], 'job_started');
      expect(calls.single.arguments['props'], {'job_id': '42'});
    });

    test('merges registered super properties; call-site wins on conflict',
        () async {
      await MixpanelSetup.registerSuperProperties(
          {'runner_id': 7, 'k': 'super'});

      await MixpanelSetup.logEvent('e', {'k': 'event', 'a': 1});

      final props = calls.single.arguments['props'] as Map;
      expect(props['runner_id'], 7); // super prop merged in
      expect(props['a'], 1); // call-site prop
      expect(props['k'], 'event'); // call-site wins over super prop
    });
  });

  group('MixpanelSetup.identify', () {
    test('forwards a non-null userId', () async {
      await MixpanelSetup.identify('expert-42');

      expect(calls.single.method, 'identify');
      expect(calls.single.arguments['userId'], 'expert-42');
    });

    test('null userId never crosses the channel', () async {
      await MixpanelSetup.identify(null);

      expect(calls, isEmpty);
    });
  });

  group('MixpanelSetup.setUserProfile', () {
    test('sends the whole map in a single setUserProperties call', () async {
      await MixpanelSetup.setUserProfile({
        'city': 'Mumbai',
        'team': null,
        'tier': 2,
      });

      expect(calls, hasLength(1));
      expect(calls.single.method, 'setUserProperties');
      // KMP-side sanitisation strips the null 'team'; Dart passes the
      // unfiltered map so we don't duplicate the rule on both sides.
      expect(calls.single.arguments['props'], {
        'city': 'Mumbai',
        'team': null,
        'tier': 2,
      });
    });

    test('empty map is a no-op (no channel crossing)', () async {
      await MixpanelSetup.setUserProfile({});

      expect(calls, isEmpty);
    });
  });
}
