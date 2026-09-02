import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

import 'snabbit_shield_config.dart';

class ShieldHttp {
  static Future<void> _logShieldApiFailure({
    required String api,
    required String endpoint,
    int? statusCode,
    int? bookingId,
    bool? isSos,
    String? reason,
    String? errorMessage,
  }) async {
    final payload = <String, dynamic>{
      'api': api,
      'endpoint': endpoint,
      if (statusCode != null) 'status_code': statusCode,
      if (bookingId != null) 'job_id': bookingId,
      if (isSos != null) 'is_sos': isSos,
      if (reason != null) 'reason': reason,
      if (errorMessage != null) 'error': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await MonitoringServiceHelper.logError(
      'Snabbit Shield API failure',
      payload,
    );
  }

  /// Gets a presigned S3 URL for uploading an encrypted audio recording.
  static Future<ShieldApiResult<PresignedUrlResponse>> getPresignedUrl({
    required int bookingId,
    required int timestamp,
    bool isSos = false,
  }) async {
    const endpointPath = 'api/v1/audio/presigned-url';
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(endpointPath),
        queryParameters: {
          'job_id': bookingId,
          'timestamp': timestamp,
          'is_sos': isSos,
        },
        headers: {},
      );
      if (response.statusCode == 200) {
        return ShieldApiResult.success(
            PresignedUrlResponse.fromJson(response.data));
      }
      unawaited(
        _logShieldApiFailure(
          api: 'get_presigned_url',
          endpoint: endpointPath,
          statusCode: response.statusCode,
          bookingId: bookingId,
          isSos: isSos,
          reason: 'non_200',
          errorMessage: '${response.data}',
        ),
      );
      return ShieldApiResult.failure(
        statusCode: response.statusCode,
        errorMessage: '${response.data}',
      );
    } catch (e) {
      unawaited(
        _logShieldApiFailure(
          api: 'get_presigned_url',
          endpoint: endpointPath,
          bookingId: bookingId,
          isSos: isSos,
          reason: 'exception',
          errorMessage: '$e',
        ),
      );
      return ShieldApiResult.failure(errorMessage: '$e');
    }
  }

  /// Uploads encrypted audio bytes directly to S3 via a presigned URL.
  /// Uses a raw Dio instance (no auth headers — S3 rejects them).
  static Future<({bool success, int? statusCode})> uploadToS3(
    String presignedUrl,
    Uint8List fileBytes,
    String contentType,
  ) async {
    try {
      final dio = Dio();
      final response = await dio.put(
        presignedUrl,
        data: Stream.fromIterable([fileBytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': fileBytes.length,
          },
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return (success: response.statusCode == 200, statusCode: response.statusCode);
    } catch (e) {
      await _logShieldApiFailure(
        api: 'upload_to_s3',
        endpoint: 's3_presigned_url',
        reason: 'exception',
        errorMessage: '$e',
      );
      return (success: false, statusCode: null);
    }
  }

  /// Confirms a successful S3 upload and sends encryption metadata.
  static Future<ShieldApiResult<UploadConfirmResponse>> confirmUpload({
    required int bookingId,
    required int timestamp,
    required String s3Key,
    required int durationSeconds,
    required ShieldEncryptionMetadata encryptionMetadata,
    bool isSos = false,
    bool isCompressed = false,
  }) async {
    const endpointPath = 'api/v1/audio/upload-complete';
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(endpointPath),
        headers: {},
        data: {
          'job_id': bookingId,
          'timestamp': timestamp,
          's3_key': s3Key,
          'is_sos': isSos,
          'encryption': encryptionMetadata.toApiJson(),
          'duration_seconds': durationSeconds,
          'file_extension': 'm4a',
          'is_compressed': isCompressed,
        },
      );
      if (response.statusCode == 200) {
        return ShieldApiResult.success(
            UploadConfirmResponse.fromJson(response.data));
      }
      unawaited(
        _logShieldApiFailure(
          api: 'confirm_upload',
          endpoint: endpointPath,
          statusCode: response.statusCode,
          bookingId: bookingId,
          isSos: isSos,
          reason: 'non_200',
          errorMessage: '${response.data}',
        ),
      );
      return ShieldApiResult.failure(
        statusCode: response.statusCode,
        errorMessage: '${response.data}',
      );
    } catch (e) {
      unawaited(
        _logShieldApiFailure(
          api: 'confirm_upload',
          endpoint: endpointPath,
          bookingId: bookingId,
          isSos: isSos,
          reason: 'exception',
          errorMessage: '$e',
        ),
      );
      return ShieldApiResult.failure(errorMessage: '$e');
    }
  }

  /// Stores Safety Shield consent for the runner.
  /// Returns the Response on success, null on failure.
  static Future<Response?> activateSnabbitShield() async {
    const endpointPath = 'api/v1/runners/me/safety-shield/consent';
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(endpointPath),
        headers: {},
        data: {'consent': true, 'consent_version': '1.0'},
      );
      if (response.statusCode != 200) {
        unawaited(
          _logShieldApiFailure(
            api: 'activate_consent',
            endpoint: endpointPath,
            statusCode: response.statusCode,
            reason: 'non_200',
            errorMessage: '${response.data}',
          ),
        );
      }
      return response;
    } catch (e) {
      unawaited(
        _logShieldApiFailure(
          api: 'activate_consent',
          endpoint: endpointPath,
          reason: 'exception',
          errorMessage: '$e',
        ),
      );
      return null;
    }
  }
}
