import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview_event_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

import 'fake_webview_channel.dart';

void main() {
  group('WebViewEventHandler.sendBackPressed', () {
    test('pushes a backPressed event with no data payload', () async {
      final channel = FakeWebViewChannel();

      await WebViewEventHandler.sendBackPressed(channel);

      expect(channel.pushedEvents, hasLength(1));
      expect(channel.pushedEvents.first.event, WebViewConstants.eventBackPressed);
      expect(channel.pushedEvents.first.data, isNull);
    });
  });

  group('FakeWebViewChannel', () {
    test('records registered inbound handlers by name', () {
      final channel = FakeWebViewChannel();
      Future<void> handler(List<dynamic> args) async {}

      channel.registerInboundHandler('flutterHandler', handler);

      expect(channel.inboundHandlers, containsPair('flutterHandler', handler));
    });

    test('getCurrentUrl returns the seeded value', () async {
      final channel = FakeWebViewChannel()
        ..currentUrl = 'https://example.com/page';

      expect(await channel.getCurrentUrl(), 'https://example.com/page');
    });
  });
}
