import 'package:snabbit_runner/utils/common_methods.dart';

/// Model class representing a transaction
class Transaction {
  final int? transactionId;
  final DateTime? transactionDate;
  final int? transactionTypeId;
  final double? amount;
  final String? currency;
  final String? description;
  final int? bankAccountId;
  final int? upiAccountId;
  final String? externalReferenceId;

  Transaction({
    this.transactionId,
    this.transactionDate,
    this.transactionTypeId,
    this.amount,
    this.currency,
    this.description,
    this.bankAccountId,
    this.upiAccountId,
    this.externalReferenceId,
  });

  /// Factory constructor to create a [Transaction] instance from a JSON map
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      transactionId: json['transaction_id'],
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'])
          : null,
      transactionTypeId: json['transaction_type_id'],
      amount: json['amount'] != null ? anyValueToDouble(json['amount']) : null,
      currency: json['currency'],
      description: json['description'],
      bankAccountId: json['bank_account_id'],
      upiAccountId: json['upi_account_id'],
      externalReferenceId: json['external_reference_id'],
    );
  }

  /// Converts the [Transaction] instance to a JSON map
  static Map<String, dynamic> toJson(Transaction transaction) {
    return {
      'transaction_id': transaction.transactionId,
      'transaction_date': transaction.transactionDate,
      'transaction_type_id': transaction.transactionTypeId,
      'amount': transaction.amount,
      'currency': transaction.currency,
      'description': transaction.description,
      'bank_account_id': transaction.bankAccountId,
      'upi_account_id': transaction.upiAccountId,
      'external_reference_id': transaction.externalReferenceId,
    };
  }
}
