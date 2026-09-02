import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/get_account_setup_handler.dart';

void main() {
  group('GetAccountSetupHandler', () {
    test('is an RPC handler named getAccountSetup', () {
      final handler = GetAccountSetupHandler(
        buildAccountSetup: () async => const BifrostResult(data: {}),
      );
      expect(handler.pattern, BifrostPattern.rpc);
      expect(handler.actionName, 'getAccountSetup');
    });

    test('delegates to the injected builder', () async {
      var calls = 0;
      final handler = GetAccountSetupHandler(
        buildAccountSetup: () async {
          calls += 1;
          return const BifrostResult(data: {
            'upiBank': {'status': 'added'},
            'pan': {'status': 'not_added'},
          });
        },
      );

      final result = await handler.handle(const {});

      expect(calls, 1);
      expect(result.error, isNull);
      expect(result.data, {
        'upiBank': {'status': 'added'},
        'pan': {'status': 'not_added'},
      });
    });

    test('forwards builder errors as-is', () async {
      final handler = GetAccountSetupHandler(
        buildAccountSetup: () async => const BifrostResult(
          error: BifrostError(
            code: BifrostErrorCodes.internalError,
            message: 'no user',
          ),
        ),
      );

      final result = await handler.handle(const {});

      expect(result.data, isNull);
      expect(result.error?.code, BifrostErrorCodes.internalError);
    });
  });
}
