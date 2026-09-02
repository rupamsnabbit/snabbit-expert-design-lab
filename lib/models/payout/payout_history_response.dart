import 'package:snabbit_runner/models/payout/assets.dart';
import 'package:snabbit_runner/models/payout/bank_account.dart';
import 'package:snabbit_runner/models/payout/transaction.dart';
import 'package:snabbit_runner/models/payout/transaction_type.dart';
import 'package:snabbit_runner/models/payout/upi_account.dart';

/// Model class representing the payout history response
class PayoutHistoryResponse {
  final List<TransactionType>? transactionTypes;
  final List<BankAccount>? bankAccounts;
  final List<UpiAccount>? upiAccounts;
  final List<Transaction>? transactions;
  final Assets? assets;

  PayoutHistoryResponse({
    this.transactionTypes,
    this.bankAccounts,
    this.upiAccounts,
    this.transactions,
    this.assets,
  });

  /// Factory constructor to create a [PayoutHistoryResponse] instance from a JSON map
  factory PayoutHistoryResponse.fromJson(Map<String, dynamic> json) {
    return PayoutHistoryResponse(
      transactionTypes: json['transaction_types'] != null
          ? (json['transaction_types'] as List)
              .map((item) => TransactionType.fromJson(item))
              .toList()
          : null,
      bankAccounts: json['bank_accounts'] != null
          ? (json['bank_accounts'] as List)
              .map((item) => BankAccount.fromJson(item))
              .toList()
          : null,
      upiAccounts: json['upi_accounts'] != null
          ? (json['upi_accounts'] as List)
              .map((item) => UpiAccount.fromJson(item))
              .toList()
          : null,
      transactions: json['transactions'] != null
          ? (json['transactions'] as List)
              .map((item) => Transaction.fromJson(item))
              .toList()
          : null,
      assets: json['assets'] != null ? Assets.fromJson(json['assets']) : null,
    );
  }

  /// Converts the [PayoutHistoryResponse] instance to a JSON map
  static Map<String, dynamic> toJson(PayoutHistoryResponse response) {
    return {
      'transaction_types': response.transactionTypes
          ?.map((item) => TransactionType.toJson(item))
          .toList(),
      'bank_accounts': response.bankAccounts
          ?.map((item) => BankAccount.toJson(item))
          .toList(),
      'upi_accounts':
          response.upiAccounts?.map((item) => UpiAccount.toJson(item)).toList(),
      'transactions': response.transactions
          ?.map((item) => Transaction.toJson(item))
          .toList(),
    };
  }
}
