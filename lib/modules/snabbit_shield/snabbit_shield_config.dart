import 'package:snabbit_runner/utils/common_methods.dart';

/// Generic API result that distinguishes permanent failures (discard) from
/// transient failures (retry later).
///
/// Permanent failures (400, 409) indicate the server will never accept this
/// entry — e.g. duplicate recording, wrong booking, file too large.
class ShieldApiResult<T> {
  final T? data;
  final int? statusCode;
  final String? errorMessage;

  bool get isSuccess => data != null;
  bool get isPermanentFailure =>
      statusCode != null && (statusCode == 400 || statusCode == 409);

  ShieldApiResult.success(this.data) : statusCode = null, errorMessage = null;
  ShieldApiResult.failure({this.statusCode, this.errorMessage}) : data = null;
}

class PresignedUrlResponse {
  final String presignedUrl;
  final String s3Key;
  final int expiresInSeconds;
  final int maxFileSizeBytes;
  final List<String> allowedContentTypes;

  PresignedUrlResponse({
    required this.presignedUrl,
    required this.s3Key,
    required this.expiresInSeconds,
    required this.maxFileSizeBytes,
    required this.allowedContentTypes,
  });

  factory PresignedUrlResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUrlResponse(
      presignedUrl: json['presigned_url'] as String,
      s3Key: json['s3_key'] as String,
      expiresInSeconds: anyValueToInt(json['expires_in_seconds'])!,
      maxFileSizeBytes: anyValueToInt(json['max_file_size_bytes'])!,
      allowedContentTypes: json['allowed_content_types'] != null
          ? List<String>.from(json['allowed_content_types'] as List)
          : const [],
    );
  }
}

class UploadConfirmResponse {
  final int recordingId;
  final int bookingId;
  final int timestamp;
  final String status;
  final String? expiresAt;
  final bool isSos;
  final bool isEncrypted;

  UploadConfirmResponse({
    required this.recordingId,
    required this.bookingId,
    required this.timestamp,
    required this.status,
    this.expiresAt,
    required this.isSos,
    this.isEncrypted = false,
  });

  factory UploadConfirmResponse.fromJson(Map<String, dynamic> json) {
    return UploadConfirmResponse(
      recordingId: anyValueToInt(json['recording_id'])!,
      bookingId: anyValueToInt(json['booking_id'])!,
      timestamp: anyValueToInt(json['timestamp'])!,
      status: json['status'] as String,
      expiresAt: json['expires_at'] as String?,
      isSos: json['is_sos'] as bool? ?? false,
      isEncrypted: json['is_encrypted'] as bool? ?? false,
    );
  }
}

class ShieldEncryptionMetadata {
  final String encryptedKey;
  final String iv;
  final String authTag;
  final bool isCompressed;

  ShieldEncryptionMetadata({
    required this.encryptedKey,
    required this.iv,
    required this.authTag,
    required this.isCompressed,
  });

  Map<String, dynamic> toJson() => {
        'encrypted_key': encryptedKey,
        'iv': iv,
        'auth_tag': authTag,
        'is_compressed': isCompressed,
      };

  /// Serialization for the upload-complete API request body.
  /// Differs from [toJson] which is used for local DB persistence.
  Map<String, dynamic> toApiJson() => {
        'encrypted_key': encryptedKey,
        'iv': iv,
        'auth_tag': authTag,
        'algorithm': 'AES-256-GCM',
        'key_wrap_algorithm': 'RSA-OAEP-256',
        'key_version': 'v1',
      };

  factory ShieldEncryptionMetadata.fromJson(Map<String, dynamic> json) {
    return ShieldEncryptionMetadata(
      encryptedKey: json['encrypted_key'] as String,
      iv: json['iv'] as String,
      authTag: json['auth_tag'] as String,
      isCompressed: json['is_compressed'] as bool? ?? false,
    );
  }
}
