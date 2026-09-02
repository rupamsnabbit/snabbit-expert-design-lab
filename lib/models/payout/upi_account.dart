/// Model class representing a UPI account
class UpiAccount {
  final int? upiAccountId;
  final String? upiId;
  final String? providerName;
  final String? iconUrl;
  final bool? isPrimary;

  UpiAccount({
    this.upiAccountId,
    this.upiId,
    this.providerName,
    this.iconUrl,
    this.isPrimary,
  });

  /// Factory constructor to create a [UpiAccount] instance from a JSON map
  factory UpiAccount.fromJson(Map<String, dynamic> json) {
    return UpiAccount(
      upiAccountId: json['upi_account_id'],
      upiId: json['upi_id'],
      providerName: json['provider_name'],
      iconUrl: json['icon_url'],
      isPrimary: json['is_primary'],
    );
  }

  /// Converts the [UpiAccount] instance to a JSON map
  static Map<String, dynamic> toJson(UpiAccount upiAccount) {
    return {
      'upi_account_id': upiAccount.upiAccountId,
      'upi_id': upiAccount.upiId,
      'provider_name': upiAccount.providerName,
      'icon_url': upiAccount.iconUrl,
      'is_primary': upiAccount.isPrimary,
    };
  }
}
