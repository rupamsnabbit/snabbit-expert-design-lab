import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/request_init_data_handler.dart';

void main() {
  group('RequestInitDataHandler', () {
    test('is an RPC handler (requestId required)', () {
      final handler = RequestInitDataHandler(
        buildInitData: (_) async => const BifrostResult.empty(),
      );
      expect(handler.pattern, BifrostPattern.rpc);
    });

    test('delegates to buildInitData and returns its success result',
        () async {
      final result =
          BifrostResult(data: {'token': 'abc', 'platform': 'android'});
      final handler = RequestInitDataHandler(
        buildInitData: (_) async => result,
      );

      final handled = await handler.handle(const {});

      expect(handled.data, {'token': 'abc', 'platform': 'android'});
      expect(handled.error, isNull);
    });

    test('forwards buildInitData error unchanged', () async {
      const error = BifrostError(
        code: 'TOKEN_UNAVAILABLE',
        message: 'no token',
      );
      final handler = RequestInitDataHandler(
        buildInitData: (_) async => const BifrostResult(error: error),
      );

      final handled = await handler.handle(const {});

      expect(handled.data, isNull);
      expect(handled.error, error);
    });

    test('invokes buildInitData once per handle call', () async {
      int calls = 0;
      final handler = RequestInitDataHandler(
        buildInitData: (_) async {
          calls++;
          return const BifrostResult.empty();
        },
      );

      await handler.handle(const {});
      await handler.handle(const {});

      expect(calls, 2);
    });

    test('passes the inbound request data through to buildInitData',
        () async {
      Map<String, dynamic>? seen;
      final handler = RequestInitDataHandler(
        buildInitData: (data) async {
          seen = data;
          return const BifrostResult.empty();
        },
      );

      await handler.handle({
        'capabilities': ['navigate', 'trackEvent'],
      });

      expect(seen, {
        'capabilities': ['navigate', 'trackEvent'],
      });
    });
  });
}
