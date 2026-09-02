/// Model class representing expert bank details from the API
class ExpertBankDetails {
  /// Unique identifier for the bank details record
  final int? id;

  /// Expert/Runner ID associated with this bank account
  final int? expertId;

  /// Instrument ID (payment gateway identifier)
  final String? instrumentId;

  /// Bank account number
  final String? accountNumber;

  /// IFSC code of the bank
  final String? ifscCode;

  /// UPI ID if UPI account
  final String? upiId;

  /// Beneficiary name on the account
  final String? beneficiaryName;

  /// Verification status of the bank account
  final bool? verificationStatus;

  /// Additional metadata as a dictionary
  final Map<String, dynamic>? meta;

  /// Whether this bank account is currently active
  final bool? isActive;

  /// Timestamp when the record was created
  final DateTime? createdAt;

  /// Timestamp when the record was last updated
  final DateTime? updatedAt;

  ExpertBankDetails({
    this.id,
    this.expertId,
    this.instrumentId,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.beneficiaryName,
    this.verificationStatus,
    this.meta,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to create an [ExpertBankDetails] instance from a JSON map
  factory ExpertBankDetails.fromJson(Map<String, dynamic> json) {
    return ExpertBankDetails(
      id: json['id'],
      expertId: json['expert_id'],
      instrumentId: json['instrument_id'],
      accountNumber: json['account_number'],
      ifscCode: json['ifsc_code'],
      upiId: json['upi_id'],
      beneficiaryName: json['beneficiary_name'],
      verificationStatus: json['verification_status'],
      meta:
          json['meta'] != null ? Map<String, dynamic>.from(json['meta']) : null,
      isActive: json['is_active'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Converts the [ExpertBankDetails] instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expert_id': expertId,
      'instrument_id': instrumentId,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'upi_id': upiId,
      'beneficiary_name': beneficiaryName,
      'verification_status': verificationStatus,
      'meta': meta,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Gets the last 4 digits of the account number for display
  String? get accountNumberLast4 {
    if (accountNumber == null || accountNumber!.isEmpty) {
      return null;
    }
    if (accountNumber!.length >= 4) {
      return accountNumber!.substring(accountNumber!.length - 4);
    }
    return accountNumber;
  }

  /// Checks if this is a UPI account
  bool get isUpiAccount => upiId != null && upiId!.isNotEmpty;

  /// Checks if this is a bank account
  bool get isBankAccount => accountNumber != null && accountNumber!.isNotEmpty;
}
