import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/token_expired_handler.dart';

void main() {
  group('TokenExpiredHandler', () {
    test('is an RPC handler named "tokenExpired"', () {
      final h = TokenExpiredHandler(onClose: () {});
      expect(h.pattern, BifrostPattern.rpc);
      expect(h.actionName, 'tokenExpired');
    });

    test('returns {closing: true} immediately', () async {
      final h = TokenExpiredHandler(
        onClose: () {},
        closeDelay: const Duration(milliseconds: 1),
      );

      final result = await h.handle(const {});

      expect(result.error, isNull);
      expect(result.data, {'closing': true});
    });

    test('schedules onClose after closeDelay, not synchronously', () async {
      int closeCount = 0;
      final h = TokenExpiredHandler(
        onClose: () => closeCount++,
        closeDelay: const Duration(milliseconds: 20),
      );

      await h.handle(const {});
      // Right after handle returns, onClose must not have fired yet —
      // the router still has to deliver the RPC response.
      expect(closeCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(closeCount, 1);
    });
  });
}
