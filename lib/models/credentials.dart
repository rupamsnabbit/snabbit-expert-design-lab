class Credentials {
  final String? aadhaarValidationUsername;
  final String? aadhaarValidationPassword;
  final String? aadhaarValidationOrganizationId;

  Credentials({
    this.aadhaarValidationUsername,
    this.aadhaarValidationPassword,
    this.aadhaarValidationOrganizationId,
  });

  factory Credentials.fromJson(Map<String, dynamic> json) {
    return Credentials(
      aadhaarValidationUsername: json['aadhaar_validation_username'],
      aadhaarValidationPassword: json['aadhaar_validation_password'],
      aadhaarValidationOrganizationId:
          json['aadhaar_validation_organization_id'],
    );
  }
}
