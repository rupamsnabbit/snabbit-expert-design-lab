import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/open_perfios_aadhaar_handler.dart';

import '../test_channel_mocks.dart';

/// Returns an opener that always resolves with [result].
PerfiosAadhaarOpener _resolvesWith(Map<String, dynamic>? result) =>
    () async => result;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  group('OpenPerfiosAadhaarHandler', () {
    test('is an RPC handler named "openPerfiosAadhaar"', () {
      final h = OpenPerfiosAadhaarHandler(openPerfios: _resolvesWith(null));
      expect(h.pattern, BifrostPattern.rpc);
      expect(h.actionName, 'openPerfiosAadhaar');
    });

    test('forwards a success payload back to the caller as data', () async {
      final payload = <String, dynamic>{
        'demographics': {'name': 'Aarti', 'maskedAadhaarNumber': 'XXXX 1234'},
        'rawPerfiosJson': '{"foo":1}',
      };
      final h = OpenPerfiosAadhaarHandler(openPerfios: _resolvesWith(payload));

      final result = await h.handle(const {});

      expect(result.error, isNull);
      expect(result.data, payload);
    });

    test('null pop resolves as USER_CANCELLED (retryable)', () async {
      final h = OpenPerfiosAadhaarHandler(openPerfios: _resolvesWith(null));

      final result = await h.handle(const {});

      expect(result.data, isNull);
      expect(result.error, isNotNull);
      expect(result.error!.code, BifrostErrorCodes.userCancelled);
      expect(result.error!.retryable, isTrue);
    });

    test('tunneled __error map forwards code + message', () async {
      final h = OpenPerfiosAadhaarHandler(
        openPerfios: _resolvesWith(<String, dynamic>{
          '__error': true,
          'code': BifrostErrorCodes.perfiosNoData,
          'message': 'no demographic data',
        }),
      );

      final result = await h.handle(const {});

      expect(result.data, isNull);
      expect(result.error!.code, BifrostErrorCodes.perfiosNoData);
      expect(result.error!.message, 'no demographic data');
    });

    test('tunneled __error without a code falls back to INTERNAL_ERROR',
        () async {
      final h = OpenPerfiosAadhaarHandler(
        openPerfios: _resolvesWith(<String, dynamic>{'__error': true}),
      );

      final result = await h.handle(const {});

      expect(result.error!.code, BifrostErrorCodes.internalError);
    });

    test('thrown exception from the opener → INTERNAL_ERROR', () async {
      final h = OpenPerfiosAadhaarHandler(
        openPerfios: () async => throw StateError('boom'),
      );

      final result = await h.handle(const {});

      expect(result.data, isNull);
      expect(result.error!.code, BifrostErrorCodes.internalError);
      expect(result.error!.message, contains('boom'));
    });

    test('a second call while one is in flight → PERFIOS_IN_PROGRESS',
        () async {
      final gate = Completer<Map<String, dynamic>?>();
      final h = OpenPerfiosAadhaarHandler(openPerfios: () => gate.future);

      // Kick off the first call but don't await it — it stays in flight.
      final first = h.handle(const {});
      // Let the microtask that sets `_inFlight = true` run.
      await Future<void>.delayed(Duration.zero);

      final second = await h.handle(const {});
      expect(second.error!.code, BifrostErrorCodes.perfiosInProgress);

      // Release the first call so the completer doesn't leak.
      gate.complete(<String, dynamic>{'demographics': {}, 'rawPerfiosJson': ''});
      final firstResult = await first;
      expect(firstResult.error, isNull);
    });

    test('inFlight guard clears after the first call resolves', () async {
      final h = OpenPerfiosAadhaarHandler(
        openPerfios: _resolvesWith(<String, dynamic>{
          'demographics': {'name': 'A'},
          'rawPerfiosJson': '{}',
        }),
      );

      final first = await h.handle(const {});
      expect(first.error, isNull);

      // A follow-up should not be blocked by a stuck _inFlight flag.
      final second = await h.handle(const {});
      expect(second.error, isNull);
    });

    test('inFlight guard clears even when the first call throws', () async {
      var callCount = 0;
      final h = OpenPerfiosAadhaarHandler(openPerfios: () async {
        callCount++;
        if (callCount == 1) throw StateError('first boom');
        return <String, dynamic>{'demographics': {}, 'rawPerfiosJson': ''};
      });

      final first = await h.handle(const {});
      expect(first.error!.code, BifrostErrorCodes.internalError);

      final second = await h.handle(const {});
      expect(second.error, isNull);
    });
  });
}
