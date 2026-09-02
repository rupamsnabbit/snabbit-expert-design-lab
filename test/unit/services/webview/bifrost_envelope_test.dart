import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';

String _loadFixture(String relPath) {
  final file = File('test/fixtures/bifrost_contract/$relPath');
  return file.readAsStringSync();
}

void main() {
  group('BifrostEnvelope.tryParse', () {
    group('valid envelopes', () {
      test('parses a fully-populated envelope', () {
        final env = BifrostEnvelope.tryParse(
          '{"event":"navigate","data":{"route":"snabbit://x"},"requestId":"r1"}',
        );

        expect(env, isNotNull);
        expect(env!.event, 'navigate');
        expect(env.data, {'route': 'snabbit://x'});
        expect(env.requestId, 'r1');
        expect(env.error, isNull);
      });

      test('treats missing data as empty map (backPressed shape)', () {
        final env = BifrostEnvelope.tryParse('{"event":"backPressed"}');

        expect(env, isNotNull);
        expect(env!.event, 'backPressed');
        expect(env.data, isEmpty);
      });

      test('parses a response envelope with error', () {
        final env = BifrostEnvelope.tryParse(
          '{"event":"navigate","requestId":"r1","error":{"code":"UNKNOWN_ROUTE","message":"no such route","retryable":false}}',
        );

        expect(env, isNotNull);
        expect(env!.error, isNotNull);
        expect(env.error!.code, 'UNKNOWN_ROUTE');
        expect(env.error!.message, 'no such route');
        expect(env.error!.retryable, isFalse);
      });
    });

    group('malformed envelopes return null', () {
      test('empty string', () {
        expect(BifrostEnvelope.tryParse(''), isNull);
      });

      test('non-JSON garbage', () {
        expect(BifrostEnvelope.tryParse('{not json'), isNull);
      });

      test('JSON array instead of object', () {
        expect(BifrostEnvelope.tryParse('[1,2,3]'), isNull);
      });

      test('missing event', () {
        expect(BifrostEnvelope.tryParse('{"data":{}}'), isNull);
      });

      test('empty event', () {
        expect(BifrostEnvelope.tryParse('{"event":""}'), isNull);
      });

      test('non-string event', () {
        expect(BifrostEnvelope.tryParse('{"event":123}'), isNull);
      });

      test('data is wrong type', () {
        expect(BifrostEnvelope.tryParse('{"event":"x","data":"bad"}'), isNull);
      });

      test('requestId is non-string', () {
        expect(
          BifrostEnvelope.tryParse('{"event":"x","requestId":42}'),
          isNull,
        );
      });

      test('requestId is empty string', () {
        expect(
          BifrostEnvelope.tryParse('{"event":"x","requestId":""}'),
          isNull,
        );
      });
    });

    group('loaded fixtures', () {
      test('malformed_json.txt returns null', () {
        final env = BifrostEnvelope.tryParse(
          _loadFixture('_envelope/malformed_json.txt'),
        );
        expect(env, isNull);
      });

      test('missing_event.json returns null', () {
        final env = BifrostEnvelope.tryParse(
          _loadFixture('_envelope/missing_event.json'),
        );
        expect(env, isNull);
      });

      test('unknown_action.json parses (router handles dispatch)', () {
        final env = BifrostEnvelope.tryParse(
          _loadFixture('_envelope/unknown_action.json'),
        );
        expect(env, isNotNull);
        expect(env!.event, 'thisActionDoesNotExist');
      });

      test('openUrl/request.valid.json parses with url in data', () {
        final env = BifrostEnvelope.tryParse(
          _loadFixture('openUrl/request.valid.json'),
        );
        expect(env, isNotNull);
        expect(env!.event, 'openUrl');
        expect(env.data['url'], startsWith('https://'));
      });

      test('closeWebView/request.no_data.json parses with empty data', () {
        final env = BifrostEnvelope.tryParse(
          _loadFixture('closeWebView/request.no_data.json'),
        );
        expect(env, isNotNull);
        expect(env!.event, 'closeWebView');
        expect(env.data, isEmpty);
      });
    });
  });

  group('BifrostError.tryParse', () {
    test('parses a minimum valid error', () {
      final err = BifrostError.tryParse({'code': 'X', 'message': 'y'});
      expect(err, isNotNull);
      expect(err!.code, 'X');
      expect(err.message, 'y');
      expect(err.retryable, isFalse);
      expect(err.details, isNull);
    });

    test('parses details and retryable', () {
      final err = BifrostError.tryParse({
        'code': 'X',
        'message': 'y',
        'details': {'field': 'url'},
        'retryable': true,
      });
      expect(err!.details, {'field': 'url'});
      expect(err.retryable, isTrue);
    });

    test('returns null when code missing', () {
      expect(BifrostError.tryParse({'message': 'y'}), isNull);
    });

    test('returns null when message missing', () {
      expect(BifrostError.tryParse({'code': 'X'}), isNull);
    });

    test('returns null for non-map', () {
      expect(BifrostError.tryParse('string'), isNull);
      expect(BifrostError.tryParse(null), isNull);
    });
  });

  group('toJson round-trips', () {
    test('envelope without optionals omits them', () {
      final env = BifrostEnvelope(event: 'x', data: const {'k': 1});
      expect(env.toJson(), {
        'event': 'x',
        'data': {'k': 1},
      });
    });

    test('envelope with everything', () {
      final env = BifrostEnvelope(
        event: 'x',
        data: const {'k': 1},
        requestId: 'r',
        error: const BifrostError(code: 'E', message: 'm', retryable: true),
      );
      expect(env.toJson(), {
        'event': 'x',
        'data': {'k': 1},
        'requestId': 'r',
        'error': {'code': 'E', 'message': 'm', 'retryable': true},
      });
    });
  });
}
