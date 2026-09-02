import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/go_live_complete_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

void main() {
  group('GoLiveCompleteHandler', () {
    test('actionName is goLiveComplete', () {
      final handler = GoLiveCompleteHandler(onGoLiveComplete: () {});
      expect(handler.actionName, WebViewConstants.eventGoLiveComplete);
      expect(handler.actionName, 'goLiveComplete');
    });

    test('is fire-and-forget', () {
      final handler = GoLiveCompleteHandler(onGoLiveComplete: () {});
      expect(handler.pattern, BifrostPattern.fireAndForget);
    });

    test('invokes onGoLiveComplete and returns empty success', () async {
      var called = 0;
      final handler = GoLiveCompleteHandler(onGoLiveComplete: () => called++);

      final result = await handler.handle(const {});

      expect(called, 1);
      expect(result.error, isNull);
      expect(result.data, isNull);
    });

    test('invokes the callback regardless of payload (native owns routing)',
        () async {
      var called = 0;
      final handler = GoLiveCompleteHandler(onGoLiveComplete: () => called++);

      await handler.handle({'unexpected': 'ignored'});

      expect(called, 1);
    });
  });
}
