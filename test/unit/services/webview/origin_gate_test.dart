import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/origin_gate.dart';

void main() {
  group('OriginGate.isAllowed', () {
    test('allows the exact initial origin', () {
      final gate = OriginGate(initialUrl: 'https://coins.snabbit.com/rates');
      expect(gate.isAllowed('https://coins.snabbit.com/anything'), isTrue);
    });

    test('allows an additional origin', () {
      final gate = OriginGate(
        initialUrl: 'https://coins.snabbit.com/',
        additionalOrigins: const ['https://auth.snabbit.com'],
      );
      expect(gate.isAllowed('https://auth.snabbit.com/cb'), isTrue);
    });

    test('denies a different host', () {
      final gate = OriginGate(initialUrl: 'https://coins.snabbit.com/');
      expect(gate.isAllowed('https://merch.snabbit.com/'), isFalse);
    });

    test('denies a crafted subdomain attack (coins.snabbit.com.attacker.com)',
        () {
      final gate = OriginGate(initialUrl: 'https://coins.snabbit.com/');
      expect(
        gate.isAllowed('https://coins.snabbit.com.attacker.com/steal'),
        isFalse,
      );
    });

    test('denies scheme downgrade (http vs https)', () {
      final gate = OriginGate(initialUrl: 'https://coins.snabbit.com/');
      expect(gate.isAllowed('http://coins.snabbit.com/'), isFalse);
    });

    test('denies different port', () {
      final gate = OriginGate(initialUrl: 'https://coins.snabbit.com/');
      expect(gate.isAllowed('https://coins.snabbit.com:8443/'), isFalse);
    });

    test('denies null', () {
      final gate = OriginGate(initialUrl: 'https://coins.snabbit.com/');
      expect(gate.isAllowed(null), isFalse);
    });

    test('denies empty string', () {
      final gate = OriginGate(initialUrl: 'https://coins.snabbit.com/');
      expect(gate.isAllowed(''), isFalse);
    });

    test('denies unparseable URL', () {
      final gate = OriginGate(initialUrl: 'https://coins.snabbit.com/');
      expect(gate.isAllowed('::::::not a url'), isFalse);
    });

    test('empty allowlist denies everything', () {
      final gate = OriginGate(initialUrl: 'not-a-url');
      expect(gate.allowedOrigins, isEmpty);
      expect(gate.isAllowed('https://coins.snabbit.com/'), isFalse);
    });
  });

  group('OriginGate.allowedOrigins', () {
    test('exposes normalised origins', () {
      final gate = OriginGate(
        initialUrl: 'https://coins.snabbit.com/rates?foo=bar',
        additionalOrigins: const ['https://auth.snabbit.com/'],
      );
      expect(
        gate.allowedOrigins,
        {'https://coins.snabbit.com', 'https://auth.snabbit.com'},
      );
    });
  });
}
