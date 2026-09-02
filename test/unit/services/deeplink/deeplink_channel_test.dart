import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/deeplink/deeplink_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methodChannel = MethodChannel('com.snabbit.runner/deeplink');
  const eventChannel = EventChannel('com.snabbit.runner/deeplink_events');

  group('getInitialDeeplink', () {
    tearDown(() {
      messenger.setMockMethodCallHandler(methodChannel, null);
    });

    test('returns the native-resolved param map', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        expect(call.method, 'getInitialDeeplink');
        return <dynamic, dynamic>{
          'deep_link_value': 'early-payouts',
          'is_deferred': 'false',
        };
      });

      final result = await DeeplinkChannel.getInitialDeeplink();
      expect(
          result, {'deep_link_value': 'early-payouts', 'is_deferred': 'false'});
    });

    test('returns null when there is no pending link', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async => null);
      final result = await DeeplinkChannel.getInitialDeeplink();
      expect(result, isNull);
    });
  });

  group('deeplinks stream', () {
    tearDown(() {
      messenger.setMockStreamHandler(eventChannel, null);
    });

    test('maps emitted events to String-keyed maps', () async {
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success(<dynamic, dynamic>{'deep_link_value': 'seva'});
          },
        ),
      );

      final event = await DeeplinkChannel.deeplinks.first;
      expect(event, {'deep_link_value': 'seva'});
    });
  });
}
