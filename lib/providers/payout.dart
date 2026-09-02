import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/payout_home_assets.dart';
import 'package:snabbit_runner/utils/enums.dart';

import '../utils/common_methods.dart';
import 'attendance.dart';
import 'user_profile.dart';

class PayoutProvider with ChangeNotifier {
  PayoutPeriod payoutPeriod = PayoutPeriod.monthly;
  Attendance? attendance;
  Earnings? earnings;
  Payslip? payslip;
  Overtime? overtimeDetails;
  Deduction? deductionDetails;
  Ratings? ratings;
  Incentives? incentives;
  bool loading = false;

  void updateLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  void reset() {
    loading = false;
  }

  void setPayoutPeriod(PayoutPeriod newPayoutPeriod) {
    payoutPeriod = newPayoutPeriod;
    notifyListeners();
  }

  void setAttendance(Map<String, dynamic>? attendanceMap) {
    if (attendanceMap != null) {
      attendance = Attendance.fromMap(attendanceMap);
    } else {
      attendance = null;
    }
    // notifyListeners();
  }

  void setEarnings(Map<String, dynamic>? earningsMap) {
    if (earningsMap != null) {
      earnings = Earnings.fromMap(earningsMap);
    } else {
      earnings = null;
    }
    // notifyListeners();
  }

  void setPayslip(Map<String, dynamic>? payslipMap) {
    if (payslipMap != null) {
      payslip = Payslip.fromMap(payslipMap);
    } else {
      payslip = null;
    }
    // notifyListeners();
  }

  void setOvertimeDetails(Map<String, dynamic>? overtimeDetailsMap) {
    if (overtimeDetailsMap != null) {
      overtimeDetails = Overtime.fromMap(overtimeDetailsMap);
    } else {
      overtimeDetails = null;
    }
    // notifyListeners();
  }

  void setDeductionDetails(Map<String, dynamic>? deductionDetailsMap) {
    if (deductionDetailsMap != null) {
      deductionDetails = Deduction.fromMap(deductionDetailsMap);
    } else {
      deductionDetails = null;
    }
    // notifyListeners();
  }

  void setRatings(Map<String, dynamic>? ratingsMap) {
    if (ratingsMap != null) {
      ratings = Ratings.fromMap(ratingsMap);
    } else {
      ratings = null;
    }
    // notifyListeners();
  }

  void setIncentives(Map<String, dynamic>? incentivesMap) {
    if (incentivesMap != null) {
      incentives = Incentives.fromMap(incentivesMap);
    } else {
      incentives = null;
    }
    // notifyListeners();
  }

  void notifyPayoutListeners() {
    notifyListeners();
  }
}

class BannerText {
  String? key;
  String? text;
  List<dynamic>? data;

  BannerText({
    this.key,
    this.text,
    this.data,
  });

  factory BannerText.fromMap(Map<String, dynamic> data) {
    return BannerText(
      key: data['key'],
      text: data['text'],
      data: data['data'],
    );
  }
}

class Banner {
  BannerText? title;
  BannerText? subtitle;

  Banner({
    this.title,
    this.subtitle,
  });

  factory Banner.fromMap(Map<String, dynamic> data) {
    return Banner(
      title: data['title'] != null ? BannerText.fromMap(data['title']) : null,
      subtitle: data['subtitle'] != null
          ? BannerText.fromMap(data['subtitle'])
          : null,
    );
  }
}

class ServiceAssuranceBannerData {
  String? bannerImageUrl;
  String? pdfUrl;

  ServiceAssuranceBannerData({
    this.bannerImageUrl,
    this.pdfUrl,
  });

  factory ServiceAssuranceBannerData.fromMap(Map<String, dynamic> data) {
    return ServiceAssuranceBannerData(
      bannerImageUrl: data['banner_image_url'],
      pdfUrl: data['pdf_url'],
    );
  }
}

class Earnings {
  double? netEarning;
  double? earning;
  CashCollected? cashCollected;
  double? otMins;
  int? otEarning;
  double? avgRating;
  int? totalPresentDays;
  int? deduction;
  double? totalIncentive;
  DailyAttendanceStatus? dailyAttendanceStatus;
  bool? isFinalized;

  //NOTE: earnings breakdown properties
  int? amountDue;
  int? referralEarnings;
  TDS? tds;
  double? loanAmount;
  bool? pendingPayment;
  DateTime? payoutDate;
  EarningDetails? earningDetails;
  AdjustmentDetails? adjustmentDetails;
  double? customerTipsEarning;
  double? taxes;
  List<EarningsDeduction>? deductions;
  double? netEarnings;
  EarlyPayout? earlyPayout;
  RemainingPayout? remainingPayout;
  double? netPayout;
  List<OtherPayout>? otherPendingPayouts;
  List<AdditionalPayout>? additionalPayouts;
  PayoutHomeAssets? assets;
  Banner? banner;
  bool? isProcessing;
  ServiceAssuranceBannerData? serviceAssuranceBannerData;
  Earnings({
    this.netEarning,
    this.earning,
    this.cashCollected,
    this.otMins,
    this.otEarning,
    this.avgRating,
    this.totalPresentDays,
    this.deduction,
    this.totalIncentive,
    this.dailyAttendanceStatus,
    this.isFinalized,
    this.amountDue,
    this.referralEarnings,
    this.tds,
    this.loanAmount,
    this.pendingPayment,
    this.payoutDate,
    this.earningDetails,
    this.adjustmentDetails,
    this.customerTipsEarning,
    this.taxes,
    this.deductions,
    this.netEarnings,
    this.earlyPayout,
    this.remainingPayout,
    this.netPayout,
    this.otherPendingPayouts,
    this.additionalPayouts,
    this.assets,
    this.banner,
    this.isProcessing,
    this.serviceAssuranceBannerData,
  });

  factory Earnings.fromMap(Map<String, dynamic> data) {
    return Earnings(
      netEarning: anyValueToDouble(data['total_earning']),
      earning: anyValueToDouble(data['total_daily_earning']),
      cashCollected: data['cash_collected'] != null
          ? CashCollected.fromMap(data['cash_collected'])
          : null,
      otMins: data['ot_mins'],
      otEarning: anyValueToInt(data['ot_earning']),
      avgRating: data['avg_rating'],
      totalPresentDays: data['total_present_days'],
      deduction: anyValueToInt(data['deduction']),
      totalIncentive: anyValueToDouble(data['monthly_bonus_earning']),
      dailyAttendanceStatus:
          getDailyAttendanceStatusFromString(data['daily_attendance_status']),
      isFinalized: data['is_finalized'],
      amountDue: anyValueToInt(data['amount_due']),
      referralEarnings: anyValueToInt(data['refer_and_earn_earning']),
      tds: data['tds'] != null ? TDS.fromMap(data['tds']) : null,
      loanAmount: anyValueToDouble(data['loan_amount']),
      pendingPayment: data['pending_payment'],
      payoutDate: data['paid_on'] != null
          ? DateTime.tryParse(data['paid_on'].toString())
          : null,
      earningDetails: data['earning_details'] != null
          ? EarningDetails.fromMap(data['earning_details'])
          : null,
      adjustmentDetails: data['adjustment_details'] != null
          ? AdjustmentDetails.fromMap(data['adjustment_details'])
          : null,
      customerTipsEarning: anyValueToDouble(data['customer_tips']),
      taxes: anyValueToDouble(data['taxes']),
      deductions: data['deductions'] != null
          ? (data['deductions'] as List)
              .map((item) => EarningsDeduction.fromMap(item))
              .toList()
          : null,
      netEarnings: anyValueToDouble(data['net_earnings']),
      earlyPayout: data['early_payout'] != null
          ? EarlyPayout.fromMap(data['early_payout'])
          : null,
      remainingPayout: data['remaining_payout'] != null
          ? RemainingPayout.fromMap(data['remaining_payout'])
          : null,
      netPayout: anyValueToDouble(data['net_payout']),
      otherPendingPayouts: data['other_pending_payouts'] != null
          ? (data['other_pending_payouts'] as List)
              .map((item) => OtherPayout.fromMap(item))
              .toList()
          : null,
      additionalPayouts: data['additional_payout'] != null
          ? (data['additional_payout'] as List)
              .map((item) => AdditionalPayout.fromMap(item))
              .toList()
          : null,
      assets: data['assets'] != null
          ? PayoutHomeAssets.fromJson(data['assets'])
          : null,
      banner: data['banner'] != null ? Banner.fromMap(data['banner']) : null,
      isProcessing: data['is_processing'],
      serviceAssuranceBannerData: data['show_snabbit_mini_banner'] != null
          ? ServiceAssuranceBannerData.fromMap(data['show_snabbit_mini_banner'])
          : null,
    );
  }
}

class TDS {
  double? amount;
  Map<String, dynamic>? subtitle;
  int? interestRate;
  String? tooltip;

  TDS({
    this.amount,
    this.subtitle,
    this.interestRate,
    this.tooltip,
  });

  factory TDS.fromMap(Map<String, dynamic> data) {
    return TDS(
      amount: anyValueToDouble(data['total']),
      subtitle: data['subtitle'],
      interestRate: anyValueToInt(data['interest_rate']),
      tooltip: data['tooltip'],
    );
  }
}

class CashCollected {
  double? amount;
  List<CashCollectedSummaryItem>? summaryItems;

  CashCollected({
    this.amount,
    this.summaryItems,
  });

  factory CashCollected.fromMap(Map<String, dynamic> data) {
    return CashCollected(
      amount: anyValueToDouble(data['total']),
      summaryItems: data['summary_items'] != null
          ? (data['summary_items'] as List)
              .map((item) => CashCollectedSummaryItem.fromMap(item))
              .toList()
          : null,
    );
  }
}

class CashCollectedSummaryItem {
  DateTime? date;
  int? jobId;
  double? amount;

  CashCollectedSummaryItem({
    this.date,
    this.jobId,
    this.amount,
  });

  factory CashCollectedSummaryItem.fromMap(Map<String, dynamic> data) {
    return CashCollectedSummaryItem(
      date: DateTime.tryParse(data['date'].toString()),
      jobId: anyValueToInt(data['job_id']),
      amount: anyValueToDouble(data['amount']),
    );
  }
}

class EarningDetails {
  double? total;
  List<EarningSummaryItem>? summaryItems;
  List<AdditionalEarning>? additionalItems;

  EarningDetails({
    this.total,
    this.summaryItems,
    this.additionalItems,
  });

  factory EarningDetails.fromMap(Map<String, dynamic> data) {
    return EarningDetails(
      total: anyValueToDouble(data['total']),
      summaryItems: data['summary_items'] != null
          ? (data['summary_items'] as List)
              .map((item) => EarningSummaryItem.fromMap(item))
              .toList()
          : null,
      additionalItems: data['additional_items'] != null
          ? (data['additional_items'] as List)
              .map((item) => AdditionalEarning.fromMap(item))
              .toList()
          : null,
    );
  }
}

class AdjustmentDetails {
  int? total;
  List<AdjustmentSummaryItem>? summaryItems;
  List<AdditionalAdjustments>? additionalItems;

  AdjustmentDetails({
    this.total,
    this.summaryItems,
    this.additionalItems,
  });

  factory AdjustmentDetails.fromMap(Map<String, dynamic> data) {
    return AdjustmentDetails(
      total: anyValueToInt(data['total']),
      summaryItems: data['summary_items'] != null
          ? (data['summary_items'] as List)
              .map((item) => AdjustmentSummaryItem.fromMap(item))
              .toList()
          : null,
      additionalItems: data['additional_items'] != null
          ? (data['additional_items'] as List)
              .map((item) => AdditionalAdjustments.fromMap(item))
              .toList()
          : null,
    );
  }
}

class EarningSummaryItem {
  String? key;
  int? value;

  EarningSummaryItem({
    this.key,
    this.value,
  });

  factory EarningSummaryItem.fromMap(Map<String, dynamic> data) {
    return EarningSummaryItem(
      key: data['key'],
      value: anyValueToInt(data['value']),
    );
  }
}

class AdditionalEarning {
  String? key;
  int? value;
  Map<String, dynamic>? bottomSheetText;

  AdditionalEarning({
    this.key,
    this.value,
    this.bottomSheetText,
  });

  factory AdditionalEarning.fromMap(Map<String, dynamic> data) {
    return AdditionalEarning(
      key: data['key'],
      value: anyValueToInt(data['value']),
      bottomSheetText: data['bottom_sheet_text'],
    );
  }
}

class AdditionalPayout {
  final String? key;
  final double? amount;
  final String? tooltip;
  final List<AdditionalPayoutSubitem>? subitems;

  AdditionalPayout({
    this.key,
    this.amount,
    this.tooltip,
    this.subitems,
  });

  factory AdditionalPayout.fromMap(Map<String, dynamic> data) {
    return AdditionalPayout(
      key: data['key'],
      amount: anyValueToDouble(data['amount']),
      tooltip: data['tooltip'],
      subitems: (data['subitems'] as List?)
          ?.map((item) => AdditionalPayoutSubitem.fromMap(item))
          .toList(),
    );
  }
}

class AdditionalPayoutSubitem {
  final String? title;
  final String? subtitle;
  final double? amount;

  AdditionalPayoutSubitem({
    this.title,
    this.subtitle,
    this.amount,
  });

  factory AdditionalPayoutSubitem.fromMap(Map<String, dynamic> data) {
    return AdditionalPayoutSubitem(
      title: data['title'],
      subtitle: data['subtitle'],
      amount: anyValueToDouble(data['amount']),
    );
  }
}

class AdjustmentSummaryItem {
  String? key;
  int? value;

  AdjustmentSummaryItem({
    this.key,
    this.value,
  });

  factory AdjustmentSummaryItem.fromMap(Map<String, dynamic> data) {
    return AdjustmentSummaryItem(
      key: data['key'],
      value: anyValueToInt(data['value']),
    );
  }
}

class AdditionalAdjustments {
  String? key;
  int? value;
  Map<String, dynamic>? bottomSheetText;

  AdditionalAdjustments({
    this.key,
    this.value,
    this.bottomSheetText,
  });

  factory AdditionalAdjustments.fromMap(Map<String, dynamic> data) {
    return AdditionalAdjustments(
      key: data['key'],
      value: anyValueToInt(data['value']),
      bottomSheetText: data['bottom_sheet_text'],
    );
  }
}

class Payslip {
  int? netEarnings;
  PayslipEarnings? earnings;
  PayslipOvertime? overtime;
  PayslipIncentives? incentives;
  PayslipDeductions? deductions;
  PayslipMinG? minG;
  NetEarningData? grossEarning;
  NetEarningData? grossDeduction;

  Payslip({
    this.netEarnings,
    this.earnings,
    this.overtime,
    this.incentives,
    this.deductions,
    this.minG,
    this.grossEarning,
    this.grossDeduction,
  });

  factory Payslip.fromMap(Map<String, dynamic> data) {
    return Payslip(
      netEarnings: anyValueToInt(data['net_earning'].toString()),
      earnings: data['earning'] != null
          ? PayslipEarnings.fromMap(data['earning'])
          : null,
      overtime: data['overtime'] != null
          ? PayslipOvertime.fromMap(data['overtime'])
          : null,
      incentives: data['incentives'] != null
          ? PayslipIncentives.fromMap(data['incentives'])
          : null,
      deductions: data['deductions'] != null
          ? PayslipDeductions.fromMap(data['deductions'])
          : null,
      minG: data['ming'] != null ? PayslipMinG.fromMap(data['ming']) : null,
      grossEarning: data['gross_earning'] != null
          ? NetEarningData.fromMap(data['gross_earning'])
          : null,
      grossDeduction: data['gross_deduction'] != null
          ? NetEarningData.fromMap(data['gross_deduction'])
          : null,
    );
  }
}

class NetEarningData {
  String? title;
  dynamic value;

  NetEarningData({
    this.title,
    this.value,
  });

  factory NetEarningData.fromMap(Map<String, dynamic> data) {
    return NetEarningData(
      title: data['title'],
      value: data['value'],
    );
  }
}

class PayslipEarnings {
  String? title;
  NetEarningData? total;
  List<NetEarningData>? breakdown;

  PayslipEarnings({
    this.title,
    this.total,
    this.breakdown,
  });

  factory PayslipEarnings.fromMap(Map<String, dynamic> data) {
    return PayslipEarnings(
      title: data['title'],
      total:
          data['total'] != null ? NetEarningData.fromMap(data['total']) : null,
      breakdown: data['breakdown']
          ?.map<NetEarningData>((e) => NetEarningData.fromMap(e))
          .toList(),
    );
  }
}

class PayslipOvertime {
  String? title;
  NetEarningData? total;
  List<NetEarningData>? breakdown;

  PayslipOvertime({
    this.title,
    this.total,
    this.breakdown,
  });

  factory PayslipOvertime.fromMap(Map<String, dynamic> data) {
    return PayslipOvertime(
        title: data['title'],
        total: data['total'] != null
            ? NetEarningData.fromMap(data['total'])
            : null,
        breakdown: data['breakdown']
            ?.map<NetEarningData>((e) => NetEarningData.fromMap(e))
            .toList());
  }
}

class PayslipMinG {
  String? title;
  NetEarningData? total;
  List<NetEarningData>? breakdown;

  PayslipMinG({
    this.title,
    this.total,
    this.breakdown,
  });

  factory PayslipMinG.fromMap(Map<String, dynamic> data) {
    return PayslipMinG(
        title: data['title'],
        total: data['total'] != null
            ? NetEarningData.fromMap(data['total'])
            : null,
        breakdown: data['breakdown']
            ?.map<NetEarningData>((e) => NetEarningData.fromMap(e))
            .toList());
  }
}

class PayslipIncentives {
  String? title;
  NetEarningData? total;
  List<NetEarningData>? breakdown;

  PayslipIncentives({
    this.title,
    this.total,
    this.breakdown,
  });

  factory PayslipIncentives.fromMap(Map<String, dynamic> data) {
    return PayslipIncentives(
        title: data['title'],
        total: data['total'] != null
            ? NetEarningData.fromMap(data['total'])
            : null,
        breakdown: data['breakdown']
            ?.map<NetEarningData>((e) => NetEarningData.fromMap(e))
            .toList());
  }
}

class PayslipDeductions {
  String? title;
  NetEarningData? total;
  List<NetEarningData>? breakdown;

  PayslipDeductions({
    this.title,
    this.total,
    this.breakdown,
  });

  factory PayslipDeductions.fromMap(Map<String, dynamic> data) {
    return PayslipDeductions(
        title: data['title'],
        total: data['total'] != null
            ? NetEarningData.fromMap(data['total'])
            : null,
        breakdown: data['breakdown']
            ?.map<NetEarningData>((e) => NetEarningData.fromMap(e))
            .toList());
  }
}

class Overtime {
  int? total;
  int? otMins;
  List<OvertimeData>? otData;

  Overtime({
    this.total,
    this.otMins,
    this.otData,
  });

  factory Overtime.fromMap(Map<String, dynamic> data) {
    return Overtime(
      total: anyValueToInt(data['total_ot_earning']),
      otMins: anyValueToInt(data['total_ot_mins']),
      otData: data['daily_ots']
          ?.map<OvertimeData>((e) => OvertimeData.fromMap(e))
          .toList(),
    );
  }
}

class OvertimeData {
  DateTime? date;
  int? otMins;
  String? otTime;
  int? otPay;

  OvertimeData({
    this.date,
    this.otMins,
    this.otTime,
    this.otPay,
  });

  factory OvertimeData.fromMap(Map<String, dynamic> data) {
    return OvertimeData(
      date: getDateTimeFromServerString(data['date']),
      otMins: anyValueToInt(data['ot_mins']),
      otTime: data['ot_time'],
      otPay: anyValueToInt(data['ot_pay']),
    );
  }
}

class Deduction {
  int? total;
  DeductionItems? deductions;
  DeductionItems? cash;

  Deduction({
    this.total,
    this.deductions,
    this.cash,
  });

  factory Deduction.fromMap(Map<String, dynamic> data) {
    return Deduction(
      total: anyValueToInt(data['total_deduction']),
      deductions: DeductionItems.fromMap(data['deductions']),
      cash: DeductionItems.fromMap(data['cash_collected']),
    );
  }
}

class DeductionItems {
  String? title;
  int? total;
  List<DeductionData>? items;

  DeductionItems({
    this.title,
    this.total,
    this.items,
  });

  factory DeductionItems.fromMap(Map<String, dynamic> data) {
    return DeductionItems(
      title: data['title'],
      total: anyValueToInt(data['total_deduction']),
      items: data['deductions']
          ?.map<DeductionData>((e) => DeductionData.fromMap(e))
          .toList(),
    );
  }
}

class DeductionData {
  DateTime? date;
  String? name;
  int? amount;
  DeductionState? status;
  double? deductionTarget;

  DeductionData({
    this.date,
    this.name,
    this.amount,
    this.status,
    this.deductionTarget,
  });

  factory DeductionData.fromMap(Map<String, dynamic> data) {
    return DeductionData(
      date: getDateTimeFromServerString(data['date']),
      amount: anyValueToInt(data['amount']),
      name: data['name'],
      status: DeductionState.fromString(data['status']),
      deductionTarget: data['target_value'],
    );
  }
}

class Ratings {
  double? ratingCurrentMonth;

  // double? ratingOverall;
  List<String?>? accolades;
  List<String?>? improvements;
  int? ratedJobs;
  List<RatingBreakdown>? ratingBreakdown;

  Ratings({
    this.ratingCurrentMonth,
    // this.ratingOverall,
    this.accolades,
    this.improvements,
    this.ratedJobs,
    this.ratingBreakdown,
  });

  factory Ratings.fromMap(Map<String, dynamic> data) {
    return Ratings(
      ratingCurrentMonth: data['avg_rating'],
      // ratingOverall: data['overall_rating'],
      accolades: data['accolades']?.map<String?>((e) => e.toString()).toList(),
      improvements:
          data['improvements']?.map<String?>((e) => e.toString()).toList(),
      ratedJobs: data['rated_jobs'],
      ratingBreakdown: data['rating_breakdown']
          ?.map<RatingBreakdown>((e) => RatingBreakdown.fromMap(e))
          .toList(),
    );
  }
}

class RatingBreakdown {
  int? rating;
  int? count;

  RatingBreakdown({
    this.rating,
    this.count,
  });

  factory RatingBreakdown.fromMap(Map<String, dynamic> data) {
    return RatingBreakdown(
      rating: anyValueToInt(data['title']),
      count: data['value'],
    );
  }
}

class SuperBonusTarget {
  int? target;
  int? amount;
  bool? isAchieved;
  PaymentState? paymentState;

  SuperBonusTarget({
    this.target,
    this.amount,
    this.isAchieved,
    this.paymentState,
  });

  factory SuperBonusTarget.fromMap(Map<String, dynamic> data) {
    return SuperBonusTarget(
      target: anyValueToInt(data['target']),
      amount: anyValueToInt(data['amount']),
      isAchieved: data['is_achieved'],
      paymentState: PaymentState.fromString(data['status']),
    );
  }
}

class SuperBonus {
  int? achievedValue;
  double? minRating;
  double? currentRating;
  DateTime? endDate;
  DateTime? paymentDate;
  List<SuperBonusTarget>? targets;
  ExpiryType? expiryType;
  int? totalValue;
  int? targetAmount;
  bool? rateCardOrShiftChanges;
  GoodShiftDetails? goodShiftDetails;

  SuperBonus({
    this.achievedValue,
    this.minRating,
    this.currentRating,
    this.endDate,
    this.paymentDate,
    this.targets,
    this.expiryType,
    this.totalValue,
    this.targetAmount,
    this.rateCardOrShiftChanges,
    this.goodShiftDetails,
  });

  int? get amount {
    // return the highest amount from targets even if one of the paymentState is non-null and pending
    // if none of the paymentState is not equal to pending then return the amount for which isAchieved is true
    int? pendingAmount;
    try {
      pendingAmount = targets
          ?.lastWhere((e) => e.paymentState == PaymentState.pending)
          .amount;
    } catch (_) {}
    if (pendingAmount == null) {
      try {
        return targets?.where((e) => e.isAchieved == true).fold(
            0, (previous, element) => (previous ?? 0) + (element.amount ?? 0));
      } catch (_) {
        return null;
      }
    } else {
      return targets?.fold(
          0, (previous, element) => (previous ?? 0) + (element.amount ?? 0));
    }
  }

  PaymentState? get paymentState {
    PaymentState? pendingState;
    try {
      pendingState = targets
          ?.lastWhere((e) => e.paymentState == PaymentState.pending)
          .paymentState;
    } catch (_) {}
    if (pendingState == null) {
      try {
        return targets?.lastWhere((e) => e.isAchieved == true).paymentState;
      } catch (_) {
        return null;
      }
    } else {
      return pendingState;
    }
  }

  bool get isAchievedOrPending {
    try {
      return isAchieved || paymentState == PaymentState.pending;
    } catch (e) {
      return false;
    }
  }

  bool get isAchieved {
    try {
      return targets?.firstWhere((e) => e.isAchieved == true) != null;
    } catch (e) {
      return false;
    }
  }

  SuperBonusTarget? get nearestPendingTarget {
    try {
      return targets?.firstWhere((e) =>
          e.paymentState == PaymentState.pending && e.isAchieved != true);
    } catch (_) {
      return null;
    }
  }

  SuperBonusTarget? get nearestTarget {
    try {
      return targets?.firstWhere((e) => e.target! > achievedValue!);
    } catch (_) {
      return null;
    }
  }

  SuperBonusTarget? get lastTarget {
    try {
      return targets?.last;
    } catch (_) {
      return null;
    }
  }

  factory SuperBonus.fromMap(Map<String, dynamic> data) {
    List<SuperBonusTarget>? targets = data['targets']
        ?.map<SuperBonusTarget>((e) => SuperBonusTarget.fromMap(e))
        .toList();
    try {
      targets?.sort((a, b) {
        if (a.target != null && b.target != null) {
          return a.target!.compareTo(b.target!);
        } else {
          return 0;
        }
      });
    } catch (_) {}
    return SuperBonus(
      achievedValue: anyValueToInt(data['achieved_value']),
      minRating: data['min_rating'],
      currentRating: data['current_rating'],
      endDate: getDateTimeFromServerString(data['end_date']),
      paymentDate: getDateTimeFromServerString(data['payment_date']),
      targets: targets,
      expiryType: ExpiryType.fromString(data['expiry_type']),
      totalValue: anyValueToInt(data['total_value']),
      targetAmount: anyValueToInt(data['target_amount']),
      rateCardOrShiftChanges: data['rate_card_or_shift_changes'],
      goodShiftDetails: data['good_shift_details'] != null
          ? GoodShiftDetails.fromMap(data['good_shift_details'])
          : null,
    );
  }
}

class Incentives {
  NetEarningData? totalIncentives;
  AttendanceIncentives? attendanceIncentives;
  RatingsIncentives? ratingsIncentives;
  SpecialIncentives? specialIncentives;
  List<OtherIncentive?>? otherIncentives;
  JoiningBonus? joiningBonus;
  SuperBonus? superBonus;

  Incentives({
    this.totalIncentives,
    this.attendanceIncentives,
    this.ratingsIncentives,
    this.specialIncentives,
    this.otherIncentives,
    this.joiningBonus,
    this.superBonus,
  });

  static List<OtherIncentive>? getSortedOtherIncentives(
      Map<String, dynamic> data) {
    try {
      List<OtherIncentive>? items = data['other_incentives']
          ?.map<OtherIncentive>((e) => OtherIncentive.fromMap(e))
          .toList();
      try {
        items?.sort((a, b) {
          if (a.order != null && b.order != null) {
            return a.order!.compareTo(b.order!);
          } else {
            return 0;
          }
        });
        return items;
      } catch (e) {
        return items;
      }
    } catch (e) {
      return null;
    }
  }

  factory Incentives.fromMap(Map<String, dynamic> data) {
    return Incentives(
      totalIncentives: data['total_incentive'] != null
          ? NetEarningData.fromMap(data['total_incentive'])
          : null,
      attendanceIncentives: data['attendance_incentive'] != null
          ? AttendanceIncentives.fromMap(data['attendance_incentive'])
          : null,
      ratingsIncentives: data['rating_incentive'] != null
          ? RatingsIncentives.fromMap(data['rating_incentive'])
          : null,
      joiningBonus: data['joining_incentive'] != null
          ? JoiningBonus.fromMap(data['joining_incentive'])
          : null,
      specialIncentives: data['special_incentive'] != null
          ? SpecialIncentives.fromMap(data['special_incentive'])
          : null,
      otherIncentives: getSortedOtherIncentives(data),
      superBonus: data['super_bonus'] != null
          ? SuperBonus.fromMap(data['super_bonus'])
          : null,
    );
  }
}

class AttendanceIncentives {
  int? daysPresent;

  /// [reward] is not being used in new payouts
  int? reward;
  int? maxReward;
  int? rewardTarget;
  int? lowTarget;
  int? absentDays;
  int? maxAbsentDays;
  int? nextMonthTarget;
  PaymentState? paymentState;
  List<String>? weekDays;
  List<String>? absentWeekDays;

  AttendanceIncentives({
    this.daysPresent,
    this.reward,
    this.maxReward,
    this.rewardTarget,
    this.lowTarget,
    this.absentDays,
    this.maxAbsentDays,
    this.nextMonthTarget,
    this.paymentState,
    this.weekDays,
    this.absentWeekDays,
  });

  factory AttendanceIncentives.fromMap(Map<String, dynamic> data) {
    return AttendanceIncentives(
      daysPresent: anyValueToInt(data['achieved_value']),
      reward: anyValueToInt(data['amount']),
      maxReward: anyValueToInt(data['target_amount']),
      rewardTarget: anyValueToInt(data['target_value']),
      lowTarget: anyValueToInt(data['redzone_target']),
      absentDays: anyValueToInt(data['absent_days']),
      maxAbsentDays: anyValueToInt(data['maximum_absent_allowed']),
      nextMonthTarget: anyValueToInt(data['next_month_target']),
      paymentState: PaymentState.fromString(data['status']),
      weekDays: data['week_days'] != null
          ? List<String>.from(data['week_days'])
          : null,
      absentWeekDays: data['absent_week_days'] != null
          ? List<String>.from(data['absent_week_days'])
          : null,
    );
  }
}

class RatingsIncentives {
  double? avgRating;
  double? rewardTarget;
  double? lowTarget;
  int? reward;
  int? maxReward;
  int? minAttendanceTarget;
  PaymentState? paymentState;
  bool? isAchieved;
  List<String>? absentWeekDays;
  List<Map<String, dynamic>>? requirements;
  LeaveDetails? leaveDetails;
  bool? rateCardOrShiftChanges;
  GoodShiftDetails? goodShiftDetails;

  RatingsIncentives({
    this.avgRating,
    this.rewardTarget,
    this.lowTarget,
    this.reward,
    this.maxReward,
    this.minAttendanceTarget,
    this.paymentState,
    this.isAchieved,
    this.absentWeekDays,
    this.requirements,
    this.leaveDetails,
    this.rateCardOrShiftChanges,
    this.goodShiftDetails,
  });

  factory RatingsIncentives.fromMap(Map<String, dynamic> data) {
    return RatingsIncentives(
      avgRating: data['achieved_value'],
      rewardTarget: data['target_value'],
      lowTarget: data['redzone_target'],
      reward: anyValueToInt(data['amount']),
      maxReward: anyValueToInt(data['target_amount']),
      minAttendanceTarget: anyValueToInt(data['minimum_attendance_target']),
      paymentState: PaymentState.fromString(data['status']),
      isAchieved: data['is_achieved'],
      absentWeekDays: data['absent_week_days'] != null
          ? List<String>.from(data['absent_week_days'])
          : null,
      requirements: data['requirements'] != null
          ? List<Map<String, dynamic>>.from(data['requirements']
              .map((item) => Map<String, dynamic>.from(item as Map)))
          : null,
      leaveDetails: data['leave_details'] != null
          ? LeaveDetails.fromMap(data['leave_details'])
          : null,
      rateCardOrShiftChanges: data['rate_card_or_shift_changes'],
      goodShiftDetails: data['good_shift_details'] != null
          ? GoodShiftDetails.fromMap(data['good_shift_details'])
          : null,
    );
  }
}

class SpecialIncentives {
  int? reward;
  PaymentState? paymentState;

  SpecialIncentives({
    this.reward,
    this.paymentState,
  });

  factory SpecialIncentives.fromMap(Map<String, dynamic> data) {
    return SpecialIncentives(
      reward: anyValueToInt(data['amount']),
      paymentState: PaymentState.fromString(data['status']),
    );
  }
}

class OtherIncentive {
  int? order;
  int? reward;
  String? title;
  String? subtitle;

  OtherIncentive({
    this.order,
    this.reward,
    this.title,
    this.subtitle,
  });

  factory OtherIncentive.fromMap(Map<String, dynamic> data) {
    return OtherIncentive(
      order: anyValueToInt(data['order']),
      reward: anyValueToInt(data['amount']),
      title: data['name'],
      subtitle: data['description'],
    );
  }
}

class JoiningBonus {
  int? jb;
  int? jbEligibleDays;
  DateTime? joiningDate;
  DateTime? paymentDate;
  PaymentState? paymentState;

  JoiningBonus({
    this.jb,
    this.jbEligibleDays,
    this.joiningDate,
    this.paymentDate,
    this.paymentState,
  });

  factory JoiningBonus.fromMap(Map<String, dynamic> data) {
    return JoiningBonus(
      jb: anyValueToInt(data['target_amount']),
      jbEligibleDays: anyValueToInt(data['target_value']),
      joiningDate: data['start_date'] != null
          ? DateTime.tryParse(data['start_date'].toString())
          : null,
      paymentDate: data['payment_date'] != null
          ? DateTime.tryParse(data['payment_date'].toString())
          : null,
      paymentState: PaymentState.fromString(data['status']),
    );
  }
}

/// Model for deduction items in the Earnings deductions array
class EarningsDeduction {
  String? key;
  DateTime? date;
  String? description;
  int? amount;
  String? subtitle;
  String? tooltip;

  EarningsDeduction({
    this.key,
    this.date,
    this.description,
    this.amount,
    this.subtitle,
    this.tooltip,
  });

  factory EarningsDeduction.fromMap(Map<String, dynamic> data) {
    return EarningsDeduction(
      key: data['key'],
      date: data['date'] != null
          ? DateTime.tryParse(data['date'].toString())
          : null,
      description: data['description'],
      amount: anyValueToInt(data['amount']),
      subtitle: data['subtitle'],
      tooltip: data['tooltip'],
    );
  }
}

/// Model for early payout information
class EarlyPayout {
  double? amount;

  EarlyPayout({
    this.amount,
  });

  factory EarlyPayout.fromMap(Map<String, dynamic> data) {
    return EarlyPayout(
      amount: anyValueToDouble(data['amount']),
    );
  }
}

/// Model for remaining payout information
class RemainingPayout {
  double? amount;
  String? subtitle;
  String? title;
  Color? subtitleColor;
  bool? shouldBlink;

  RemainingPayout({
    this.amount,
    this.subtitle,
    this.title,
    this.subtitleColor,
    this.shouldBlink,
  });

  factory RemainingPayout.fromMap(Map<String, dynamic> data) {
    return RemainingPayout(
      amount: anyValueToDouble(data['amount']),
      subtitle: data['subtitle'],
      title: data['title'],
      subtitleColor: hexToColor(data['subtitle_color']),
      shouldBlink: data['should_blink'],
    );
  }
}

/// Model for custom bonus items in other pending payouts
class OtherPayout {
  String? title;
  String? subtitle;
  double? amount;

  OtherPayout({
    this.title,
    this.subtitle,
    this.amount,
  });

  factory OtherPayout.fromMap(Map<String, dynamic> data) {
    return OtherPayout(
      title: data['title_key'],
      subtitle: data['subtitle'],
      amount: anyValueToDouble(data['amount']),
    );
  }
}

/// Model for other pending payouts information
class OtherPendingPayouts {
  List<OtherPayout>? payouts;

  OtherPendingPayouts({
    this.payouts,
  });

  factory OtherPendingPayouts.fromMap(Map<String, dynamic> data) {
    return OtherPendingPayouts(
      payouts: data['other_pending_payouts'] != null
          ? (data['other_pending_payouts'] as List)
              .map((item) => OtherPayout.fromMap(item))
              .toList()
          : null,
    );
  }
}

class LeaveDetails {
  int? maxLeaveAllowedCount;
  int? currentLeaveCount;

  LeaveDetails({
    this.maxLeaveAllowedCount,
    this.currentLeaveCount,
  });

  factory LeaveDetails.fromMap(Map<String, dynamic> data) {
    return LeaveDetails(
      maxLeaveAllowedCount: anyValueToInt(data['max_leave_allowed_count']),
      currentLeaveCount: anyValueToInt(data['current_leave_count']),
    );
  }
}

class GoodShiftDetails {
  int? goodShiftCount;
  int? totalGoodShiftRequired;

  GoodShiftDetails({
    this.goodShiftCount,
    this.totalGoodShiftRequired,
  });

  factory GoodShiftDetails.fromMap(Map<String, dynamic> data) {
    return GoodShiftDetails(
      goodShiftCount: anyValueToInt(data['good_shift_count']),
      totalGoodShiftRequired: anyValueToInt(data['total_good_shift_required']),
    );
  }
}
