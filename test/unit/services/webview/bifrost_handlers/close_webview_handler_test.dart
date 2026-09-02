import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/close_webview_handler.dart';

void main() {
  group('CloseWebViewHandler', () {
    test('passes data map to onClose when non-empty', () async {
      Map<String, dynamic>? received;
      final handler = CloseWebViewHandler(
        onClose: (result) => received = result,
      );

      await handler.handle({'orderId': 'ord_1'});

      expect(received, {'orderId': 'ord_1'});
    });

    test('passes empty map to onClose when data is empty (web completion)', () async {
      Map<String, dynamic>? received;
      final handler = CloseWebViewHandler(
        onClose: (result) => received = result,
      );

      await handler.handle(const {});

      expect(received, isEmpty);
    });
  });
}
