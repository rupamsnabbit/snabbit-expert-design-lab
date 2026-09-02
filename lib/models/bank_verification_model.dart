class BankVerificationResponse {
  final String? instrumentId;
  final String? referenceId;
  final String? status;
  final String? validationStatus;
  final String? validationReason;
  final String? message;
  final ValidationResults? validationResults;
  final String? upiId;
  final String? accountNumber;
  final String? ifscCode;

  BankVerificationResponse({
    this.instrumentId,
    this.referenceId,
    this.status,
    this.validationStatus,
    this.validationReason,
    this.message,
    this.validationResults,
    this.upiId,
    this.accountNumber,
    this.ifscCode,
  });

  factory BankVerificationResponse.fromJson(Map<String, dynamic> json) {
    return BankVerificationResponse(
      instrumentId: json['instrument_id'],
      referenceId: json['reference_id'],
      status: json['status'],
      validationStatus: json['validation_status'],
      validationReason: json['validation_reason'],
      message: json['message'],
      validationResults: json['validation_results'] != null
          ? ValidationResults.fromJson(json['validation_results'])
          : null,
      upiId: json['upi_id'],
      accountNumber: json['account_number'],
      ifscCode: json['ifsc_code'],
    );
  }
}

class ValidationResults {
  final String? accountStatus;
  final String? details;
  final String? nameMatchScore;
  final String? registeredName;

  ValidationResults({
    this.accountStatus,
    this.details,
    this.nameMatchScore,
    this.registeredName,
  });

  factory ValidationResults.fromJson(Map<String, dynamic> json) {
    return ValidationResults(
      accountStatus: json['account_status'],
      details: json['details'],
      nameMatchScore: json['name_match_score'],
      registeredName: json['registered_name'],
    );
  }
}
