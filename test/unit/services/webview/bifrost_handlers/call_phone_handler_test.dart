import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/call_phone_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_logger.dart';

const _logger = NullBifrostLogger();

void main() {
  group('CallPhoneHandler', () {
    test('forwards a valid phone number to the initiator', () async {
      String? received;
      final handler = CallPhoneHandler(logger: _logger,
        callInitiator: ({required phoneNumber, required callSourceLabel}) async {
          received = phoneNumber;
        },
      );

      await handler.handle({'phoneNumber': '+91 98765-43210'});

      expect(received, '+91 98765-43210');
    });

    test('rejects malformed phone numbers (letters, punctuation)', () async {
      int callCount = 0;
      final handler = CallPhoneHandler(logger: _logger,
        callInitiator: ({required phoneNumber, required callSourceLabel}) async {
          callCount++;
        },
      );

      await handler.handle({'phoneNumber': 'tel:+911234'});
      await handler.handle({'phoneNumber': 'abc'});
      await handler.handle({'phoneNumber': '; rm -rf /'});

      expect(callCount, 0);
    });

    test('rejects missing / empty / non-string phone number', () async {
      int callCount = 0;
      final handler = CallPhoneHandler(logger: _logger,
        callInitiator: ({required phoneNumber, required callSourceLabel}) async {
          callCount++;
        },
      );

      await handler.handle(const {});
      await handler.handle({'phoneNumber': ''});
      await handler.handle({'phoneNumber': 1234567890});

      expect(callCount, 0);
    });

    test('accepts spaces, parens, dashes, and leading +', () async {
      final received = <String>[];
      final handler = CallPhoneHandler(logger: _logger,
        callInitiator: ({required phoneNumber, required callSourceLabel}) async {
          received.add(phoneNumber);
        },
      );

      for (final p in ['+1 (555) 123-4567', '555 1234', '+91-98765-43210']) {
        await handler.handle({'phoneNumber': p});
      }

      expect(received, hasLength(3));
    });
  });
}
