/// Model class representing a bank account
class BankAccount {
  final int? bankAccountId;
  final String? bankName;
  final String? accountNumberLast4;
  final bool? isPrimary;
  final String? iconUrl;

  BankAccount({
    this.bankAccountId,
    this.bankName,
    this.accountNumberLast4,
    this.isPrimary,
    this.iconUrl,
  });

  /// Factory constructor to create a [BankAccount] instance from a JSON map
  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      bankAccountId: json['bank_account_id'],
      bankName: json['bank_name'],
      accountNumberLast4: json['account_number_last_4'],
      isPrimary: json['is_primary'],
      iconUrl: json['icon_url'],
    );
  }

  /// Converts the [BankAccount] instance to a JSON map
  static Map<String, dynamic> toJson(BankAccount bankAccount) {
    return {
      'bank_account_id': bankAccount.bankAccountId,
      'bank_name': bankAccount.bankName,
      'account_number_last_4': bankAccount.accountNumberLast4,
      'is_primary': bankAccount.isPrimary,
      'icon_url': bankAccount.iconUrl,
    };
  }
}
