import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/analytics/kmp_analytics_channel.dart';

/// Covers the super-property store on [KmpAnalyticsChannel]: it merges into
/// [KmpAnalyticsChannel.track] for Dart-origin events AND forwards
/// register/clear across the channel so the KMP tracker's own store (which
/// serves native/CMP-origin events) stays in sync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.snabbit.runner/analytics');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    KmpAnalyticsChannel.resetSuperPropsForTest();
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

  MethodCall lastOf(String method) =>
      calls.lastWhere((c) => c.method == method);

  test('registerSuperProperties forwards props across the channel', () async {
    KmpAnalyticsChannel.instance.registerSuperProperties({'cluster_id': 'BLR'});
    await Future<void>.delayed(Duration.zero); // let the async invoke land

    final call = lastOf('registerSuperProperties');
    expect((call.arguments as Map)['props'], {'cluster_id': 'BLR'});
  });

  test(
      'registerSuperProperties forwards the full accumulated snapshot, '
      'so a dropped hop self-heals on the next register', () async {
    KmpAnalyticsChannel.instance.registerSuperProperties({'cluster_id': 'BLR'});
    KmpAnalyticsChannel.instance.registerSuperProperties({'region_id': 'S1'});
    await Future<void>.delayed(Duration.zero);

    // Second call carries BOTH keys (full store), not just the delta {region_id}.
    expect((lastOf('registerSuperProperties').arguments as Map)['props'],
        {'cluster_id': 'BLR', 'region_id': 'S1'});
  });

  test('track merges registered super-props; call-site props win', () async {
    KmpAnalyticsChannel.instance
        .registerSuperProperties({'cluster_id': 'BLR', 'region_id': 'S1'});
    await KmpAnalyticsChannel.instance
        .track(name: 'e', props: {'cluster_id': 'MUM', 'source': 'icon'});

    final props = (lastOf('track').arguments as Map)['props'] as Map;
    expect(props['cluster_id'], 'MUM'); // call-site wins
    expect(props['region_id'], 'S1'); // super-prop merged
    expect(props['source'], 'icon');
  });

  test('clearSuperProperties crosses the channel and empties the Dart store',
      () async {
    KmpAnalyticsChannel.instance.registerSuperProperties({'cluster_id': 'BLR'});

    await KmpAnalyticsChannel.instance.clearSuperProperties();
    await KmpAnalyticsChannel.instance.track(name: 'post_logout');

    expect(calls.any((c) => c.method == 'clearSuperProperties'), isTrue);
    final props = (lastOf('track').arguments as Map)['props'] as Map;
    expect(props.containsKey('cluster_id'), isFalse); // super-prop dropped
  });
}
