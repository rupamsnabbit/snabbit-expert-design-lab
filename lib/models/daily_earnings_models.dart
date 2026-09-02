import 'package:snabbit_runner/models/shift_performance_details.dart';

import '../utils/common_methods.dart';

class MingDetail {
  final String? key;
  final bool? value;
  final List<dynamic>? details;

  MingDetail({
    this.key,
    this.value,
    this.details,
  });

  factory MingDetail.fromJson(Map<String, dynamic> json) {
    return MingDetail(
      key: json['key'],
      value: json['value'] as bool?,
      details: json['details'] as List<dynamic>?,
    );
  }
}

class AdditionalDetail {
  final String? key;
  final int? value;
  final String? image;

  AdditionalDetail({
    this.key,
    this.value,
    this.image,
  });

  factory AdditionalDetail.fromJson(Map<String, dynamic> json) {
    return AdditionalDetail(
      key: json['criteria'],
      value: anyValueToInt(json['amount']),
      image: json['img'],
    );
  }
}

class LoginLocation {
  final String? key;
  final String? text;
  final LoginLocationData? data;

  LoginLocation({
    this.key,
    this.text,
    this.data,
  });

  factory LoginLocation.fromJson(Map<String, dynamic> json) {
    return LoginLocation(
      key: json['key'],
      text: json['text'],
      data: json['data'] != null
          ? LoginLocationData.fromJson(json['data'])
          : null,
    );
  }
}

class LoginLocationData {
  final String? location;

  LoginLocationData({
    this.location,
  });

  factory LoginLocationData.fromJson(Map<String, dynamic> json) {
    return LoginLocationData(
      location: json['location'],
    );
  }
}

class DailyEarningsResponse {
  final AttendanceDetails? attendanceDetails;
  final BasePay? basePay;
  final bool? mingEligible;
  final List<MingDetail>? mingDetails;
  final int? mingAmount;
  final DailyEarnings? dailyEarnings;
  final LoginLocation? loginLocation;
  final List<JobDetail>? jobDetails;
  final bool allowReportIssue; // Always true as per new API
  final bool allowIssueHistory; // Always true as per new API
  final ShiftPerformanceDetails? shiftPerformanceDetails;

  DailyEarningsResponse({
    this.attendanceDetails,
    this.basePay,
    this.mingEligible,
    this.mingDetails,
    this.mingAmount,
    this.dailyEarnings,
    this.loginLocation,
    this.jobDetails,
    this.allowReportIssue = false,
    this.allowIssueHistory = false,
    this.shiftPerformanceDetails,
  });

  factory DailyEarningsResponse.fromJson(Map<String, dynamic> json) {
    BasePay? basePayData;
    if (json['base_pay'] != null) {
      basePayData = BasePay.fromJson(json['base_pay']);
    }

    // Process ming_details
    List<MingDetail> mingDetailsList = [];
    if (json['ming_details'] != null) {
      for (var detail in json['ming_details']) {
        if (detail is Map<String, dynamic>) {
          mingDetailsList.add(MingDetail.fromJson(detail));
        }
      }
    }

    return DailyEarningsResponse(
      attendanceDetails: json['attendance_details'] != null
          ? AttendanceDetails.fromJson(json['attendance_details'])
          : null,
      basePay: basePayData,
      mingEligible: json['ming_eligible'],
      mingAmount: anyValueToInt(json['ming_amount']),
      mingDetails: mingDetailsList,
      dailyEarnings: json['daily_earnings'] != null
          ? DailyEarnings.fromJson(json['daily_earnings'])
          : null,
      loginLocation: json['login_location'] != null
          ? LoginLocation.fromJson(json['login_location'])
          : null,
      jobDetails: json['job_details'] != null
          ? List<JobDetail>.from(
              json['job_details'].map((job) => JobDetail.fromJson(job)))
          : null,
      allowReportIssue: json['allow_report_issue'] ?? false,
      allowIssueHistory: json['allow_issue_history'] ?? false,
      shiftPerformanceDetails: json['shift_performance_details'] != null
          ? ShiftPerformanceDetails.fromJson(json['shift_performance_details'])
          : null,
    );
  }
}

class AttendanceDetails {
  final String? attendance;

  AttendanceDetails({this.attendance});

  factory AttendanceDetails.fromJson(Map<String, dynamic> json) {
    return AttendanceDetails(
      attendance: json['attendance'],
    );
  }
}

class BasePay {
  final double? minsWorked;
  final double? ratePerHour;
  final double? totalBasePay;

  BasePay({
    this.minsWorked,
    this.ratePerHour,
    this.totalBasePay,
  });

  factory BasePay.fromJson(Map<String, dynamic> json) {
    return BasePay(
      minsWorked:
          json['mins_worked'] is num ? json['mins_worked'].toDouble() : null,
      ratePerHour: json['rate_per_hour'] is num
          ? json['rate_per_hour'].toDouble()
          : null,
      totalBasePay: json['total_base_pay'] is num
          ? json['total_base_pay'].toDouble()
          : null,
    );
  }
}

class LineItemValue {
  final int? amount;
  final String? suffix;
  final int? count;
  final String? countAsset;

  LineItemValue({
    this.amount,
    this.suffix,
    this.count,
    this.countAsset,
  });

  factory LineItemValue.fromJson(Map<String, dynamic> json) {
    return LineItemValue(
      amount: anyValueToInt(json['amount']),
      suffix: json['suffix'],
      count: json['count'],
      countAsset: json['count_img'],
    );
  }
}

class LineItem {
  final String? key;
  final LineItemValue value;
  final String? subtitle;
  LineItem({
    this.key,
    required this.value,
    this.subtitle,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      key: json['key'],
      value: LineItemValue.fromJson(json['value']),
      subtitle: json['subtitle'],
    );
  }
}

class DailyEarnings {
  final List<LineItem>? lineItems;
  final double? totalAmount;
  final double? amountDue;
  final double? cashCollected;

  DailyEarnings({
    this.lineItems,
    this.totalAmount,
    this.amountDue,
    this.cashCollected,
  });

  factory DailyEarnings.fromJson(Map<String, dynamic> json) {
    List<LineItem>? lineItemsList;

    if (json['line_items'] != null) {
      lineItemsList = List<LineItem>.from(
          json['line_items'].map((item) => LineItem.fromJson(item)));
    }

    return DailyEarnings(
      lineItems: lineItemsList,
      totalAmount:
          json['total_amount'] is num ? json['total_amount'].toDouble() : null,
      amountDue:
          json['amount_due'] is num ? json['amount_due'].toDouble() : null,
      cashCollected: json['cash_collected'] is num
          ? json['cash_collected'].toDouble()
          : null,
    );
  }
}

class JobDetail {
  final int? jobId;
  final int? jobEarning;
  final int? cashCollected;
  final int? duration;
  final JobDetailInfo? details;

  JobDetail({
    this.jobId,
    this.jobEarning,
    this.cashCollected,
    this.duration,
    this.details,
  });

  factory JobDetail.fromJson(Map<String, dynamic> json) {
    return JobDetail(
      jobId: json['job_id'],
      jobEarning: anyValueToInt(json['job_earning']),
      cashCollected: anyValueToInt(json['cash_collected']),
      duration: anyValueToInt(json['duration']),
      details: json['details'] != null
          ? JobDetailInfo.fromJson(json['details'])
          : null,
    );
  }
}

class OvertimeInfo {
  final int? amount;
  final int? otMins;

  OvertimeInfo({this.amount, this.otMins});

  factory OvertimeInfo.fromJson(Map<String, dynamic> json) {
    return OvertimeInfo(
      amount: anyValueToInt(json['amount']),
      otMins: anyValueToInt(json['ot_mins']),
    );
  }
}

class JobDetailInfo {
  final List<AdditionalDetail>? additionalDetails;
  final int? onTime;
  final int? basePay;
  final int? longDistance;
  final OvertimeInfo? ot;

  JobDetailInfo({
    this.additionalDetails,
    this.onTime,
    this.basePay,
    this.longDistance,
    this.ot,
  });

  factory JobDetailInfo.fromJson(Map<String, dynamic> json) {
    // Process additional_details
    List<AdditionalDetail> detailsList = [];
    if (json['additional_details'] != null) {
      for (var detail in json['additional_details']) {
        if (detail is Map<String, dynamic>) {
          detailsList.add(AdditionalDetail.fromJson(detail));
        }
      }
    }

    return JobDetailInfo(
      additionalDetails: detailsList.isNotEmpty ? detailsList : null,
      onTime: anyValueToInt(json['on_time']),
      basePay: anyValueToInt(json['base_pay']),
      longDistance: anyValueToInt(json['long_distance']),
      ot: json['ot'] != null ? OvertimeInfo.fromJson(json['ot']) : null,
    );
  }
}
