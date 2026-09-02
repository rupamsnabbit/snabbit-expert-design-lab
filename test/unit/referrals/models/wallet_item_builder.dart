/**
 * Builder classes for wallet_item test data.
 *
 * This file contains builders (following Python agent pattern):
 * 1. Entity Builders - For constructing WalletItem instances
 * 2. JSON Builders - For constructing test JSON input data
 *
 * The builder pattern makes test input-output relationships crystal clear:
 * - Input: Built with fluent API showing exactly what's being tested
 * - Output: Assertions verify expected behavior based on input
 *
 * Example:
 *   // Clear input construction
 *   final item = WalletItemBuilder()
 *       .withType(WalletItemType.credit)
 *       .withAmount(100)
 *       .build();
 *
 *   // Clear JSON construction for fromJson tests
 *   final json = WalletItemBuilder.jsonWith(
 *     type: 'CREDIT',
 *     amount: 100,
 *   );
 *
 * Benefits:
 * - Maintainable: Change WalletItem structure? Update builder once
 * - Readable: Fluent API makes test intent clear
 * - Reusable: Share builders across test cases
 *
 * Generated following Python agent pattern
 */

import 'package:snabbit_runner/referrals/models/wallet_item.dart';

// Sentinel class to distinguish between "use default" and "explicit null"
class _Default {
  const _Default();
}

class WalletItemBuilder {
  int _id = 1;
  DateTime? _date = DateTime(2025, 11, 26);
  WalletItemType? _type = WalletItemType.credit;
  int? _amount = 100;

  /// Set the wallet item ID
  WalletItemBuilder withId(int id) {
    _id = id;
    return this;
  }

  /// Set the transaction date
  WalletItemBuilder withDate(DateTime? date) {
    _date = date;
    return this;
  }

  /// Set the transaction type
  WalletItemBuilder withType(WalletItemType? type) {
    _type = type;
    return this;
  }

  /// Set the transaction amount
  WalletItemBuilder withAmount(int? amount) {
    _amount = amount;
    return this;
  }

  /// Build the WalletItem instance
  WalletItem build() {
    return WalletItem(
      id: _id,
      date: _date,
      type: _type,
      amount: _amount,
    );
  }

  // Scenario methods (following Python agent pattern)

  /// Configure as high-value credit scenario
  WalletItemBuilder asHighValueCredit() {
    _type = WalletItemType.credit;
    _amount = 5000;
    return this;
  }

  /// Configure as small debit scenario
  WalletItemBuilder asSmallDebit() {
    _type = WalletItemType.debit;
    _amount = 10;
    return this;
  }

  /// Configure as edge case (nulls and zeros)
  WalletItemBuilder asEdgeCase() {
    _date = null;
    _type = null;
    _amount = 0;
    return this;
  }

  /// Configure with only required fields
  WalletItemBuilder withOnlyRequiredFields() {
    _date = null;
    _type = null;
    _amount = null;
    return this;
  }

  // JSON Builder Methods (for fromJson tests)

  /// Create a default valid JSON map
  static Map<String, dynamic> defaultJson() {
    return {
      'id': 1,
      'date': '2025-11-26T10:30:00.000Z',
      'type': 'CREDIT',
      'amount': 100,
    };
  }

  /// Create a JSON map with custom values
  /// Use explicit null to override default values: jsonWith(amount: null)
  static Map<String, dynamic> jsonWith({
    int? id,
    Object? date = const _Default(),  // Can be String, null, or default
    String? type,
    Object? amount = const _Default(),  // Can be int, String, null, or default
  }) {
    final json = <String, dynamic>{};

    // ID is required
    json['id'] = id ?? 1;

    // Only set other fields if explicitly provided (not default)
    if (date is! _Default) {
      json['date'] = date;
    } else {
      json['date'] = '2025-11-26T10:30:00.000Z';
    }

    if (type != null) {
      json['type'] = type;
    } else {
      json['type'] = 'CREDIT';
    }

    if (amount is! _Default) {
      json['amount'] = amount;
    } else {
      json['amount'] = 100;
    }

    return json;
  }

  /// Create JSON for a credit transaction
  static Map<String, dynamic> creditJson({int amount = 100}) {
    return jsonWith(type: 'CREDIT', amount: amount);
  }

  /// Create JSON for a debit transaction
  static Map<String, dynamic> debitJson({int amount = 50}) {
    return jsonWith(type: 'DEBIT', amount: amount);
  }

  /// Create JSON with invalid data (for error testing)
  static Map<String, dynamic> invalidJson() {
    return {
      'id': 1,
      'date': 'not-a-date',
      'type': 'INVALID_TYPE',
      'amount': 'not-a-number',
    };
  }

  /// Create minimal JSON (only required fields)
  static Map<String, dynamic> minimalJson({int id = 1}) {
    return {'id': id};
  }
}
