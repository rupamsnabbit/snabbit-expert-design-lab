/// Model class representing a transaction type
class TransactionType {
  final int? transactionTypeId;
  final String? typeName;

  TransactionType({
    this.transactionTypeId,
    this.typeName,
  });

  /// Factory constructor to create a [TransactionType] instance from a JSON map
  factory TransactionType.fromJson(Map<String, dynamic> json) {
    return TransactionType(
      transactionTypeId: json['transaction_type_id'],
      typeName: json['type_name'],
    );
  }

  /// Converts the [TransactionType] instance to a JSON map
  static Map<String, dynamic> toJson(TransactionType transactionType) {
    return {
      'transaction_type_id': transactionType.transactionTypeId,
      'type_name': transactionType.typeName,
    };
  }
}
