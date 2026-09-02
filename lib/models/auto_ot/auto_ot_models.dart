import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';

/// Auto-OT (Auto Overtime) models for handling overtime shift requests
///
/// These models represent the data structure for Auto-OT feature,
/// including shift details, expiry information, and state management.

/// Enum representing the current state of the Auto-OT flow
enum AutoOtState {
  /// No Auto-OT request active
  idle,

  /// Initial state when Auto-OT request is received
  initial,

  /// User has clicked to confirm the request
  confirm,

  /// API call is in progress
  loading,

  /// Auto-OT request was successfully accepted
  success,

  /// Auto-OT request has expired (time-based or cancellation)
  expired,

  /// Auto-OT request failed (API error)
  failure,
}

/// Enum representing the reason for denying an Auto-OT request
enum AutoOtDenyReason {
  /// User manually rejected the request
  rejected,

  /// Request was cancelled due to job assignment taking priority
  cancelledDueToJobAssignment,

  ///Request dismissed due to other reasons
  dismissed;

  /// Converts the enum value to the API-expected string format
  @override
  String toString() {
    switch (this) {
      case AutoOtDenyReason.rejected:
        return 'REJECTED';
      case AutoOtDenyReason.cancelledDueToJobAssignment:
        return 'CANCELLED_DUE_TO_JOB_ASSIGNMENT';
      case AutoOtDenyReason.dismissed:
        return 'DISMISSED';
    }
  }
}

/// Model representing shift timing and earnings details
class ShiftDetails {
  /// Start time of the shift
  final DateTime? startTime;

  /// End time of the shift
  final DateTime? endTime;

  /// Minimum guarantee earnings for the shift
  final double? ming;

  /// Duration of overtime shift in hours (only for OT shift)
  final int? duration;

  ShiftDetails({
    this.startTime,
    this.endTime,
    this.ming,
    this.duration,
  });

  /// Creates a ShiftDetails instance from JSON data
  ///
  /// Handles snake_case keys and nullable values.
  /// DateTime fields are parsed from ISO 8601 strings.
  factory ShiftDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ShiftDetails();
    }

    return ShiftDetails(
      startTime: DateTime.tryParse(json['start_time'])?.toLocal(),
      endTime: DateTime.tryParse(json['end_time'])?.toLocal(),
      ming: anyValueToDouble(json['ming']),
      duration: anyValueToInt(json['duration']),
    );
  }

  /// Converts ShiftDetails to JSON format
  Map<String, dynamic> toJson() {
    return {
      if (startTime != null) 'start_time': startTime!.toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toIso8601String(),
      if (ming != null) 'ming': ming,
      if (duration != null) 'duration': duration,
    };
  }
}

/// Model representing Auto-OT status information (optional)
class AutoOtStatus {
  /// Icon URL or identifier for the status
  final String? icon;

  /// Title text for the status
  final String? title;

  /// Background color in hex format
  final Color? bgColor;

  /// Text color in hex format
  final Color? textColor;

  AutoOtStatus({
    this.icon,
    this.title,
    this.bgColor,
    this.textColor,
  });

  /// Creates an AutoOtStatus instance from JSON data
  factory AutoOtStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AutoOtStatus();
    }

    return AutoOtStatus(
      icon: json['icon'],
      title: json['title'],
      bgColor: json['bg_color'] != null ? hexToColor(json['bg_color']) : null,
      textColor:
          json['text_color'] != null ? hexToColor(json['text_color']) : null,
    );
  }
}

/// Main model representing Auto-OT details from the backend
///
/// This model contains all information about the overtime request,
/// including regular shift details, overtime shift details, expiry duration,
/// and optional status information.
class AutoOtDetails {
  /// request id
  final int? requestId;

  /// OT type — post_shift (overtime) or pre_shift (early start).
  /// Defaults to postShift for backward compatibility with old backend responses.
  final OtType otType;

  /// Details of the regular shift
  final ShiftDetails? regularShift;

  /// Details of the overtime shift
  final ShiftDetails? otShift;

  /// Expiry duration in minutes
  final int? expiryDuration;

  /// Optional status information
  final AutoOtStatus? status;

  AutoOtDetails({
    this.requestId,
    this.otType = OtType.EndOt,
    this.regularShift,
    this.otShift,
    this.expiryDuration,
    this.status,
  });

  /// Creates an AutoOtDetails instance from JSON data
  ///
  /// Handles snake_case keys and nullable values.
  /// Only parses nested objects if the key value is not null.
  factory AutoOtDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AutoOtDetails();
    }

    return AutoOtDetails(
      requestId: anyValueToInt(json['request_id']),
      otType: OtType.fromKey(json['ot_type'] ?? ''),
      regularShift: json['regular_shift'] != null
          ? ShiftDetails.fromJson(json['regular_shift'])
          : null,
      otShift: json['ot_shift'] != null
          ? ShiftDetails.fromJson(json['ot_shift'])
          : null,
      expiryDuration: anyValueToInt(json['expiry_duration']),
      status:
          json['status'] != null ? AutoOtStatus.fromJson(json['status']) : null,
    );
  }
}
