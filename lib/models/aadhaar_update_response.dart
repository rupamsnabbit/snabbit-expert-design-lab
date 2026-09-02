import 'package:snabbit_runner/utils/common_methods.dart';

/// Response body of `POST /api/v1/verification/aadhaar/update` (Aadhaar re-KYC).
///
/// The 200 body is bare — `{ document_id, status, aadhaar_number }` — so the
/// client maps each [status] to its own result UI. `status` is one of
/// `verified`, `rejected`, or `name_mismatched`.
class AadhaarUpdateResponse {
  final int? documentId;
  final String? status;
  final String? aadhaarNumber;

  AadhaarUpdateResponse({
    this.documentId,
    this.status,
    this.aadhaarNumber,
  });

  factory AadhaarUpdateResponse.fromJson(Map<String, dynamic> json) {
    return AadhaarUpdateResponse(
      documentId: anyValueToInt(json['document_id']),
      status: json['status']?.toString(),
      aadhaarNumber: json['aadhaar_number']?.toString(),
    );
  }

  String? get _normalizedStatus => status?.toLowerCase().trim();

  bool get isVerified => _normalizedStatus == 'verified';

  bool get isRejected => _normalizedStatus == 'rejected';

  bool get isNameMismatched => _normalizedStatus == 'name_mismatched';
}
