/**
 * Unit tests for lib/referrals/models/wallet_item.dart
 *
 * COVERAGE REQUIREMENTS (from repository standards):
 * - ✅ **Branch Coverage: 100% (REQUIRED)** - Every if/switch/case must be tested
 * - 📊 **Line Coverage: 60%** - Models (business logic only)
 *
 * Testing Philosophy:
 * - 100% branch coverage (strict requirement)
 * - Pragmatic line coverage for models (60%)
 * - Fewer, comprehensive tests over many small tests
 * - Test all branches: switch cases, null handling
 *
 * All tests follow:
 * - AAA pattern (Arrange-Act-Assert)
 * - Builder pattern for test data
 * - group() for organizing related tests
 *
 * CRITICAL REQUIREMENTS:
 * 1. 100% branch coverage - test ALL switch cases + default paths
 * 2. Test null handling - DateTime.tryParse, fromString with invalid data
 * 3. Test edge cases - invalid enums, null values, malformed JSON
 * 4. No external dependencies to mock (pure model logic)
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/referrals/models/wallet_item.dart';
import 'wallet_item_builder.dart';

void main() {
  group('WalletItemType', () {
    group('fromString', () {
      test('returns credit when given "CREDIT"', () {
        // Arrange & Act
        final result = WalletItemType.fromString('CREDIT');

        // Assert
        expect(result, equals(WalletItemType.credit));
      });

      test('returns debit when given "DEBIT"', () {
        // Arrange & Act
        final result = WalletItemType.fromString('DEBIT');

        // Assert
        expect(result, equals(WalletItemType.debit));
      });

      test('returns null when given invalid string', () {
        // Arrange & Act - testing the default case
        final result = WalletItemType.fromString('INVALID');

        // Assert
        expect(result, isNull);
      });

      test('returns null when given null', () {
        // Arrange & Act - testing null input
        final result = WalletItemType.fromString(null);

        // Assert
        expect(result, isNull);
      });

      test('returns null when given lowercase "credit"', () {
        // Arrange & Act - testing case sensitivity
        final result = WalletItemType.fromString('credit');

        // Assert
        expect(result, isNull);
      });
    });

    group('presentationKey', () {
      test('returns "credited" for credit type', () {
        // Arrange
        final type = WalletItemType.credit;

        // Act
        final result = type.presentationKey;

        // Assert
        expect(result, equals('credited'));
      });

      test('returns "withdrawal" for debit type', () {
        // Arrange
        final type = WalletItemType.debit;

        // Act
        final result = type.presentationKey;

        // Assert
        expect(result, equals('withdrawal'));
      });
    });
  });

  group('WalletItem', () {
    group('constructor', () {
      test('creates instance with all required fields', () {
        // Arrange & Act
        final item = WalletItem(
          id: 1,
          date: DateTime(2025, 11, 26),
          type: WalletItemType.credit,
          amount: 100,
        );

        // Assert
        expect(item.id, equals(1));
        expect(item.date, equals(DateTime(2025, 11, 26)));
        expect(item.type, equals(WalletItemType.credit));
        expect(item.amount, equals(100));
      });

      test('creates instance with only id (other fields null)', () {
        // Arrange & Act
        final item = WalletItem(id: 1);

        // Assert
        expect(item.id, equals(1));
        expect(item.date, isNull);
        expect(item.type, isNull);
        expect(item.amount, isNull);
      });
    });

    group('fromJson', () {
      test('parses valid JSON with all fields correctly', () {
        // Arrange
        final json = {
          'id': 123,
          'date': '2025-11-26T10:30:00.000Z',
          'type': 'CREDIT',
          'amount': 150,
        };

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.id, equals(123));
        expect(item.date, isNotNull);
        expect(item.date!.year, equals(2025));
        expect(item.date!.month, equals(11));
        expect(item.date!.day, equals(26));
        expect(item.type, equals(WalletItemType.credit));
        expect(item.amount, equals(150));
      });

      test('parses JSON with DEBIT type correctly', () {
        // Arrange - testing different branch for type
        final json = WalletItemBuilder.jsonWith(type: 'DEBIT');

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.type, equals(WalletItemType.debit));
      });

      test('handles invalid date string gracefully', () {
        // Arrange - DateTime.tryParse returns null for invalid dates
        final json = WalletItemBuilder.jsonWith(date: 'invalid-date');

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.date, isNull); // DateTime.tryParse returns null
      });

      test('handles invalid type string by setting type to null', () {
        // Arrange - testing default case in WalletItemType.fromString
        final json = WalletItemBuilder.jsonWith(type: 'INVALID_TYPE');

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.type, isNull);
      });

      test('handles string amount using anyValueToInt', () {
        // Arrange - amount can be string in JSON
        final json = WalletItemBuilder.jsonWith(amount: '250');

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.amount, equals(250));
      });

      test('handles null amount gracefully', () {
        // Arrange
        final json = WalletItemBuilder.jsonWith(amount: null);

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.amount, isNull);
      });

      test('parses minimal valid JSON with only id', () {
        // Arrange - edge case with minimal data
        final json = {'id': 999};

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.id, equals(999));
        expect(item.date, isNull);
        expect(item.type, isNull);
        expect(item.amount, isNull);
      });

      test('handles empty date string', () {
        // Arrange - edge case
        final json = WalletItemBuilder.jsonWith(date: '');

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.date, isNull);
      });

      test('handles zero amount', () {
        // Arrange - boundary condition
        final json = WalletItemBuilder.jsonWith(amount: 0);

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.amount, equals(0));
      });

      test('handles negative amount', () {
        // Arrange - boundary condition (though business logic might prevent this)
        final json = WalletItemBuilder.jsonWith(amount: -50);

        // Act
        final item = WalletItem.fromJson(json);

        // Assert
        expect(item.amount, equals(-50));
      });
    });
  });
}
