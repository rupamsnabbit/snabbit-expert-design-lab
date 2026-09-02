import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/providers/aadhaar_reverification_provider.dart';

Response _resp(int statusCode, dynamic data) => Response(
      requestOptions: RequestOptions(path: '/aadhaar/update'),
      statusCode: statusCode,
      data: data,
    );

/// Builds a provider whose network call returns [response], capturing the
/// raw JSON it was asked to submit.
AadhaarReverificationProvider _providerReturning(
  Response? response, {
  List<String>? capturedJson,
  Object? throwError,
}) {
  return AadhaarReverificationProvider(
    submitter: (json) async {
      capturedJson?.add(json);
      if (throwError != null) throw throwError;
      return response;
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The provider fires monitoring logs via platform channels that don't
    // exist in a unit test. Stub them so the fire-and-forget reportError /
    // logError calls don't raise unhandled exceptions.
    for (final name in const [
      'cx_flutter_plugin',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  const validPerfios = '{"name":"Ravi Kumar","maskedAadhaarNumber":"XXXX1234"}';

  group('initial state', () {
    test('starts at the intro phase and cannot retry', () {
      final provider = _providerReturning(null);

      expect(provider.phase, ReKycPhase.intro);
      expect(provider.result, isNull);
      expect(provider.error, isNull);
      expect(provider.canRetry, isFalse);
    });
  });

  group('onPerfiosSuccess', () {
    test('a real Aadhaar payload moves to review', () {
      final provider = _providerReturning(null);

      provider.onPerfiosSuccess(validPerfios);

      expect(provider.phase, ReKycPhase.review);
      expect(provider.reviewData?.name, 'Ravi Kumar');
      expect(provider.reviewData?.maskedAadhaarNumber, 'XXXX1234');
    });

    test(
        'an empty payload (no Aadhaar data) is a retryable failure, not review',
        () {
      final provider = _providerReturning(null);

      provider.onPerfiosSuccess('{}');

      expect(provider.phase, ReKycPhase.result);
      expect(provider.reviewData, isNull);
      expect(provider.error, isNotNull);
      expect(provider.canRetry, isTrue);
    });

    test('an exit payload (user exited Perfios) is a retryable failure', () {
      final provider = _providerReturning(null);

      provider.onPerfiosSuccess('{"exitByUser":true}');

      expect(provider.phase, ReKycPhase.result);
      expect(provider.reviewData, isNull);
      expect(provider.canRetry, isTrue);
    });

    test('an error payload is a retryable failure even with some data', () {
      final provider = _providerReturning(null);

      provider.onPerfiosSuccess('{"isError":true,"name":"Ravi Kumar"}');

      expect(provider.phase, ReKycPhase.result);
      expect(provider.canRetry, isTrue);
    });

    test('a non-object payload is a retryable failure', () {
      final provider = _providerReturning(null);

      provider.onPerfiosSuccess('[]');

      expect(provider.phase, ReKycPhase.result);
      expect(provider.reviewData, isNull);
    });

    test('invalid JSON is a retryable failure', () {
      final provider = _providerReturning(null);

      provider.onPerfiosSuccess('not-json');

      expect(provider.phase, ReKycPhase.result);
      expect(provider.reviewData, isNull);
    });
  });

  group('onPerfiosFailed', () {
    test('moves to a retryable result with an error', () {
      final provider = _providerReturning(null);

      provider.onPerfiosFailed();

      expect(provider.phase, ReKycPhase.result);
      expect(provider.result, isNull);
      expect(provider.error, isNotNull);
      expect(provider.canRetry, isTrue);
    });
  });

  group('submit', () {
    test('ignores a second submit while one is already in flight', () async {
      final gate = Completer<Response?>();
      var calls = 0;
      final provider = AadhaarReverificationProvider(submitter: (json) {
        calls++;
        return gate.future;
      });
      provider.onPerfiosSuccess(validPerfios);

      final first = provider.submit();
      final second = provider.submit(); // phase is already submitting → no-op

      expect(provider.phase, ReKycPhase.submitting);
      gate.complete(_resp(200, {'status': 'verified'}));
      await Future.wait([first, second]);

      expect(calls, 1);
    });

    test('does nothing when there is no Perfios result to submit', () async {
      final provider = _providerReturning(_resp(200, {'status': 'verified'}));

      await provider.submit();

      expect(provider.phase, ReKycPhase.intro);
      expect(provider.result, isNull);
    });

    test('verified → result, no retry, and onVerified runs once', () async {
      var verifiedCalls = 0;
      final provider = _providerReturning(_resp(200, {
        'document_id': 42,
        'status': 'verified',
        'aadhaar_number': 'XXXX1234',
      }));
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit(onVerified: () async => verifiedCalls++);

      expect(provider.phase, ReKycPhase.result);
      expect(provider.result?.isVerified, isTrue);
      expect(provider.canRetry, isFalse);
      expect(verifiedCalls, 1);
    });

    test('verified without an onVerified callback does not throw', () async {
      final provider = _providerReturning(_resp(200, {'status': 'verified'}));
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit();

      expect(provider.result?.isVerified, isTrue);
    });

    test('submits the raw Perfios JSON unchanged', () async {
      final captured = <String>[];
      final provider = _providerReturning(
        _resp(200, {'status': 'verified'}),
        capturedJson: captured,
      );
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit();

      expect(captured.single, validPerfios);
    });

    test('rejected → retryable result, onVerified not run', () async {
      var verifiedCalls = 0;
      final provider = _providerReturning(_resp(200, {'status': 'rejected'}));
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit(onVerified: () async => verifiedCalls++);

      expect(provider.result?.isRejected, isTrue);
      expect(provider.canRetry, isTrue);
      expect(verifiedCalls, 0);
    });

    test('name_mismatched → result is not retryable', () async {
      final provider =
          _providerReturning(_resp(200, {'status': 'name_mismatched'}));
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit();

      expect(provider.result?.isNameMismatched, isTrue);
      expect(provider.canRetry, isFalse);
    });

    test('200 with non-map body does not crash', () async {
      final provider = _providerReturning(_resp(200, null));
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit();

      expect(provider.phase, ReKycPhase.result);
      expect(provider.result?.isVerified, isFalse);
    });

    test('non-200 with errors envelope surfaces the backend message', () async {
      final provider = _providerReturning(_resp(400, {
        'errors': [
          {
            'code': 'AADHAAR_ALREADY_LINKED',
            'title': 'Aadhaar already in use',
            'message': 'Linked to another account.',
          }
        ],
      }));
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit();

      expect(provider.result, isNull);
      expect(provider.error?.title, 'Aadhaar already in use');
      expect(provider.error?.message, 'Linked to another account.');
      expect(provider.canRetry, isTrue);
    });

    test('non-200 without an errors envelope falls back to a generic error',
        () async {
      final provider = _providerReturning(_resp(400, {'unexpected': true}));
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit();

      expect(provider.error, isNotNull);
      expect(provider.canRetry, isTrue);
    });

    test('null response surfaces a retryable error', () async {
      final provider = _providerReturning(null);
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit();

      expect(provider.error, isNotNull);
      expect(provider.canRetry, isTrue);
    });

    test('a thrown network error is caught and surfaced as retryable',
        () async {
      final provider = _providerReturning(null, throwError: Exception('boom'));
      provider.onPerfiosSuccess(validPerfios);

      await provider.submit();

      expect(provider.phase, ReKycPhase.result);
      expect(provider.error, isNotNull);
      expect(provider.canRetry, isTrue);
    });
  });

  group('reset / retry', () {
    test('reset clears everything back to intro', () async {
      final provider = _providerReturning(_resp(200, {'status': 'rejected'}));
      provider.onPerfiosSuccess(validPerfios);
      await provider.submit();

      provider.reset();

      expect(provider.phase, ReKycPhase.intro);
      expect(provider.result, isNull);
      expect(provider.error, isNull);
      expect(provider.reviewData, isNull);
    });

    test('retry returns to intro so the webview can relaunch', () async {
      final provider = _providerReturning(_resp(200, {'status': 'rejected'}));
      provider.onPerfiosSuccess(validPerfios);
      await provider.submit();

      provider.retry();

      expect(provider.phase, ReKycPhase.intro);
    });
  });

  group('phase setters', () {
    test('goToLoading and goToWebview move through the pre-webview phases', () {
      final provider = _providerReturning(null);

      provider.goToLoading();
      expect(provider.phase, ReKycPhase.loading);

      provider.goToWebview();
      expect(provider.phase, ReKycPhase.webview);
    });
  });
}
