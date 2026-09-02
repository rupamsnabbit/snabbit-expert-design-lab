import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/webview/analytics_sink.dart';

/// Locks the merged-form sink: a single channel call targeting both
/// providers, super-props merged once via the Mixpanel facade.
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

  test('fires a single track call targeting Mixpanel + CleverTap + AppsFlyer',
      () async {
    await const KmpWebAnalyticsSink().track('web_event', {'k': 'v'});

    expect(calls, hasLength(1));
    expect(calls.single.method, 'track');
    expect(calls.single.arguments['targets'],
        ['Mixpanel', 'CleverTap', 'AppsFlyer']);
  });

  test('merges registered super-props into the payload', () async {
    await MixpanelSetup.registerSuperProperties({'runner_id': 7, 'k': 'super'});

    await const KmpWebAnalyticsSink().track('web_event', {'a': 1});

    expect(calls.single.arguments['props'],
        {'runner_id': 7, 'k': 'super', 'a': 1});
  });

  test('call-site props win over super-props on conflict', () async {
    await MixpanelSetup.registerSuperProperties({'k': 'super'});

    await const KmpWebAnalyticsSink().track('e', {'k': 'event'});

    expect(calls.single.arguments['props']['k'], 'event');
  });
}
