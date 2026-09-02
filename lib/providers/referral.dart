import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../services/runner_http.dart';
import '../utils/enums.dart';
import '../services/globals.dart';
import 'contest_data_provider.dart';

class ReferralDataProvider with ChangeNotifier {
  ReferralData? referralData;
  bool loading = true;
  String? error;
  MonthlyData? monthlyData;

  void reset() {
    referralData = null;
    loading = true;
    error = null;
  }

  void setLoading(bool val) {
    if (loading == val) {
      return;
    }
    loading = val;
    Future(() {
      notifyListeners();
    });
  }

  Future<void> getReferralDetails({bool setLoadingFalse = true}) async {
    /// [setLoadingFalse] is used to control if loading = false should be set after api call or not.
    /// This is used for avoid jarring effect on screen during back to back api calls
    setLoading(true);
    try {
      Response? response = await RunnerHttp.runnerReferralsDetails();
      if (response != null && response.statusCode == 200) {
        error = null;
        final data = response.data;
        referralData = ReferralData.fromMap(data);

        // Set contest data in ContestDataProvider if diwaliContest is not null
        _setContestDataIfAvailable();
      } else {
        error = "Server error - ${response?.statusCode}";
      }
    } catch (e) {
      error = "Something went wrong - $e";
    }
    if (setLoadingFalse) {
      setLoading(false);
    }
  }

  Future<void> getReferrals({Map<String, dynamic>? queryParameters}) async {
    setLoading(true);
    try {
      Response? response = await RunnerHttp.runnerReferrals(
        queryParameters: queryParameters,
      );
      if (response != null && response.statusCode == 200) {
        monthlyData = MonthlyData.fromMap(response.data);
      }
    } catch (e) {
      // DO NOTHING
    }
    setLoading(false);
  }

  void _setContestDataIfAvailable() {
    if (referralData?.activeContest != null) {
      final context = GlobalState().navigatorKey.currentContext;
      if (context != null) {
        try {
          final contestDataProvider =
              Provider.of<ContestDataProvider>(context, listen: false);
          contestDataProvider.setContestData(referralData!.activeContest!);
        } catch (_) {
          // Provider not found in tree; ignore safely
        }
      }
    }
  }
}

class ReferralData {
  int? referralAmount;
  int? totalEarnings;
  int? dueAmount;
  DateTime? dueDate;
  int? referralThreshold;
  int? totalReferrals;
  bool? hasReferred;
  String? videoUrl;
  String? thumbnailUrl;
  List<Campaign>? campaigns;
  Map<String, dynamic>? expiryText;
  List<HowItWorksStep>? howItWorksSteps;
  List<Earner>? earners;
  String? headerImage;
  List<RunnerReferral>? campaignReferrals;
  ContestModel? activeContest;
  bool? allowWithdrawal;
  List<ReferralShiftCampaignData>? shiftReferralCampaigns;

  ReferralData({
    this.referralAmount,
    this.totalEarnings,
    this.dueAmount,
    this.dueDate,
    this.referralThreshold,
    this.totalReferrals,
    this.hasReferred,
    this.videoUrl,
    this.thumbnailUrl,
    this.campaigns,
    this.expiryText,
    this.howItWorksSteps,
    this.earners,
    this.headerImage,
    this.campaignReferrals,
    this.activeContest,
    this.allowWithdrawal,
    this.shiftReferralCampaigns,
  });

  factory ReferralData.fromMap(Map<String, dynamic> data) {
    return ReferralData(
      referralAmount: anyValueToInt(data['referral_bonus']),
      totalEarnings: anyValueToInt(data['total_earnings']),
      dueAmount: anyValueToInt(data['amount_due']),
      dueDate: DateTime.tryParse(data['payment_date'].toString()),
      referralThreshold: data['referral_threshold'],
      totalReferrals: anyValueToInt(data['total_referrals']),
      hasReferred: data['has_referred'],
      videoUrl: data['video_url'],
      thumbnailUrl: data['thumbnail_url'],
      howItWorksSteps: data['how_it_works_steps'] != null
          ? List<HowItWorksStep>.from(
              data['how_it_works_steps'].map((e) => HowItWorksStep.fromMap(e)))
          : null,
      expiryText: data['expiry_text'],
      campaigns: data['campaigns'] != null
          ? List<Campaign>.from(
              data['campaigns'].map((e) => Campaign.fromMap(e)))
          : null,
      earners: data['earners'] != null
          ? List<Earner>.from(data['earners'].map((e) => Earner.fromMap(e)))
          : null,
      headerImage: data['header_image'],
      campaignReferrals: data['campaign_referrals'] != null
          ? List<RunnerReferral>.from(
              data['campaign_referrals'].map((e) => RunnerReferral.fromMap(e)))
          : null,
      activeContest: data['active_contest'] != null
          ? ContestModel.fromMap(data['active_contest'])
          : null,
      allowWithdrawal: data['allow_withdrawal'] ?? true,
      shiftReferralCampaigns: data['shift_referral_campaigns'] != null
          ? List<ReferralShiftCampaignData>.from(
              data['shift_referral_campaigns']
                  .map((e) => ReferralShiftCampaignData.fromJson(e)))
          : null,
    );
  }
}

class Earner {
  List<EarnerDetails>? items;

  Earner({
    this.items,
  });

  factory Earner.fromMap(Map<String, dynamic> map) {
    return Earner(
      items: map['items'] != null
          ? List<EarnerDetails>.from(
              map['items']?.map((e) => EarnerDetails.fromMap(e)))
          : null,
    );
  }
}

class EarnerDetails {
  RemoteImage? icon;
  Map<String, dynamic>? title;

  EarnerDetails({
    this.icon,
    this.title,
  });

  factory EarnerDetails.fromMap(Map<String, dynamic> map) {
    return EarnerDetails(
      icon: map['icon'] != null ? RemoteImage.fromJson(map['icon']) : null,
      title: map['title'],
    );
  }
}

class HowItWorksStep {
  int? order;
  Map<String, dynamic>? title;

  HowItWorksStep({
    this.order,
    this.title,
  });

  factory HowItWorksStep.fromMap(Map<String, dynamic> data) {
    return HowItWorksStep(
      order: anyValueToInt(data['order']),
      title: data['title'],
    );
  }
}

class Campaign {
  Map<String, dynamic>? title;
  Map<String, dynamic>? amountText;
  Map<String, dynamic>? subtitle;

  Campaign({
    this.title,
    this.amountText,
    this.subtitle,
  });

  factory Campaign.fromMap(Map<String, dynamic> data) {
    return Campaign(
      title: data['title'],
      amountText: data['amount_text'],
      subtitle: data['subtitle'],
    );
  }
}

class RunnerReferral {
  // int id;
  String? name;
  String? phone;
  int? bonus;
  List<BonusSummaryItem>? bonusSummary;
  int? netPayable;
  List<StepData> referralSteps;
  StatusData? statusData;
  String? image;
  MilestoneConfig? milestoneConfig;

  RunnerReferral({
    // required this.id,
    this.name,
    this.phone,
    this.bonus,
    this.bonusSummary,
    this.netPayable,
    this.referralSteps = const [],
    this.statusData,
    this.image,
    this.milestoneConfig,
  });

  factory RunnerReferral.fromMap(Map<String, dynamic> data) {
    return RunnerReferral(
      // id: data['id'],
      name: data['referral_name'],
      phone: data['referral_phone_number'],
      bonus: anyValueToInt(data['referral_bonus']),
      bonusSummary: data['summary'] != null
          ? List<BonusSummaryItem>.from(
              data['summary'].map((e) => BonusSummaryItem.fromMap(e)))
          : null,
      netPayable: anyValueToInt(data['net_payable']),
      milestoneConfig: data['milestone_config'] != null
          ? MilestoneConfig.fromMap(data['milestone_config'])
          : null,
      referralSteps: getSortedSteps(data['referral_steps']),
      statusData: data['status_data'] != null
          ? StatusData.fromMap(data['status_data'])
          : null,
      image: data['image'] ?? AssetConstants.avatarImagePlaceholder,
    );
  }
}

class MilestoneConfig {
  int? milestoneBonus;
  bool? isAchieved;

  MilestoneConfig({
    this.milestoneBonus,
    this.isAchieved,
  });

  factory MilestoneConfig.fromMap(Map<String, dynamic> data) {
    return MilestoneConfig(
      milestoneBonus: anyValueToInt(data['milestone_bonus']),
      isAchieved: data['is_achieved'] ?? false,
    );
  }
}

class StatusData {
  ReferralStatus? status;
  int? maxValue;
  int? currentValue;
  bool? isCompleted;
  Map<String, dynamic>? title;

  StatusData({
    this.status,
    this.maxValue,
    this.currentValue,
    this.isCompleted,
    this.title,
  });

  factory StatusData.fromMap(Map<String, dynamic> data) {
    return StatusData(
      status: getReferralStatusFromString(data['status']),
      maxValue: anyValueToInt(data['max_value']),
      currentValue: anyValueToInt(data['current_value']),
      isCompleted: data['is_completed'],
      title: data['title'],
    );
  }
}

List<StepData> getSortedSteps(List<dynamic>? data) {
  try {
    List<StepData> steps = data != null
        ? List<StepData>.from(data.map((e) => StepData.fromMap(e)))
        : [];
    steps.sort((a, b) {
      if (a.order != null && b.order != null) {
        return a.order!.compareTo(b.order!);
      } else {
        return a.id.compareTo(b.id);
      }
    });
    return steps;
  } catch (e) {
    return [];
  }
}

class StepData {
  int id;
  Map<String, dynamic>? title;
  int? order;
  ReferralStepStatus? referralStepStatus;
  int? maxValue;
  int? currentValue;
  int? amount;
  Map<String, dynamic>? earningText;
  ReferralShiftType? shiftType;

  StepData({
    required this.id,
    this.title,
    this.referralStepStatus,
    this.order,
    this.maxValue,
    this.currentValue,
    this.amount,
    this.earningText,
    this.shiftType,
  });

  factory StepData.fromMap(Map<String, dynamic> json) {
    return StepData(
      id: json['id'],
      order: json['order'],
      title: json["title"],
      // Sample - {"text": json['name'], "alignment": "left"}
      referralStepStatus: getReferralStepStatusFromString(json['status']),
      maxValue: anyValueToInt(json['max_value']),
      currentValue: anyValueToInt(json['current_value']),
      amount: anyValueToInt(json['amount']),
      earningText: json['earning_text'],
      shiftType: ReferralShiftType.fromKey(json['shift_type'])
    );
  }
}

class MonthlyData {
  double? dueAmount;
  DateTime? dueDate;
  double? totalEarnings;
  double? taxAmount;
  int? taxPercentage;
  List<RunnerReferral>? referrals;
  Map<String, dynamic>? taxSubtitle;
  String? taxTooltip;

  MonthlyData({
    this.dueAmount,
    this.dueDate,
    this.totalEarnings,
    this.taxAmount,
    this.referrals,
    this.taxPercentage,
    this.taxSubtitle,
    this.taxTooltip,
  });

  factory MonthlyData.fromMap(Map<String, dynamic> data) {
    return MonthlyData(
      dueAmount: anyValueToDouble(data['amount_due']),
      dueDate: DateTime.tryParse(data['payment_date'].toString()),
      totalEarnings: anyValueToDouble(data['total_earnings']),
      taxAmount: anyValueToDouble(data['tax_amount']),
      referrals: data['referrals'] != null
          ? List<RunnerReferral>.from(
              data['referrals'].map((e) => RunnerReferral.fromMap(e)))
          : null,
      taxPercentage: anyValueToInt(data['tax_percentage']),
      taxSubtitle: data['tax_subtitle'],
      taxTooltip: data['tax_tooltip'],
    );
  }
}

class BonusSummaryItem {
  Map<String, dynamic>? title;
  Map<String, dynamic>? subtitle;
  int? amount;

  BonusSummaryItem({
    this.title,
    this.subtitle,
    this.amount,
  });

  factory BonusSummaryItem.fromMap(Map<String, dynamic> data) {
    return BonusSummaryItem(
      title: data['title'],
      subtitle: data['subtitle'],
      amount: anyValueToInt(data['amount']),
    );
  }
}

class ContestModel {
  int? id;
  Map<String, dynamic>? unit;
  Map<String, dynamic>? title;
  Map<String, dynamic>? displayTitle;
  Map<String, dynamic>? displayPrize;
  Map<String, dynamic>? description;
  RemoteImage? bannerImage;
  RemoteImage? prizeImage;
  DateTime? endDate;
  ContestStatus? status;
  List<HowItWorksStep>? rules;
  List<ContestStandingDetail>? standingDetail;

  ContestModel({
    this.id,
    this.unit,
    this.title,
    this.displayTitle,
    this.displayPrize,
    this.description,
    this.bannerImage,
    this.prizeImage,
    this.endDate,
    this.status,
    this.rules,
    this.standingDetail,
  });

  factory ContestModel.fromMap(Map<String, dynamic> data) {
    return ContestModel(
      id: anyValueToInt(data['id']),
      unit: data['unit'],
      title: data['title'],
      displayTitle: data['display_title'],
      displayPrize: data['display_prize'],
      description: data['description'],
      bannerImage: data['banner_image'] != null
          ? RemoteImage.fromJson(data['banner_image'])
          : null,
      prizeImage: data['prize_image'] != null
          ? RemoteImage.fromJson(data['prize_image'])
          : null,
      endDate: DateTime.tryParse(data['end_date'].toString()),
      status: getContestStatusFromString(data['status']),
      rules: data['rules'] != null
          ? List<HowItWorksStep>.from(
              data['rules'].map((e) => HowItWorksStep.fromMap(e)))
          : null,
      standingDetail: data['standing_detail'] != null
          ? List<ContestStandingDetail>.from(data['standing_detail']
              .map((e) => ContestStandingDetail.fromMap(e)))
          : null,
    );
  }
}

class ContestStandingDetail {
  int? order;
  String? icon;
  Map<String, dynamic>? title;
  String? value;

  ContestStandingDetail({
    this.order,
    this.icon,
    this.title,
    this.value,
  });

  factory ContestStandingDetail.fromMap(Map<String, dynamic> data) {
    return ContestStandingDetail(
      order: anyValueToInt(data['order']),
      icon: data['icon'],
      title: data['title'],
      value: data['value'],
    );
  }
}

class ReferralShiftCampaignData {
  final bool? isNewCampaign;
  final ReferralShiftType? referralShiftType;
  final int? shiftDurationMinHours;
  final int? shiftDurationMaxHours;
  final int? referralAmount;
  final bool showLearnMore;
  final int? maxEarnings;
  final int? daysOfValidity;
  final String? referralText;

  ReferralShiftCampaignData({
    this.isNewCampaign,
    this.referralShiftType,
    this.shiftDurationMinHours,
    this.shiftDurationMaxHours,
    this.referralAmount,
    this.showLearnMore = false,
    this.maxEarnings,
    this.daysOfValidity,
    this.referralText,
  });

  /// The fromJson factory to parse the FastAPI response
  factory ReferralShiftCampaignData.fromJson(Map<String, dynamic> json) {
    return ReferralShiftCampaignData(
      isNewCampaign: json['is_new_campaign'],
      referralShiftType: ReferralShiftType.fromKey(json['referral_shift_type']),
      shiftDurationMinHours: anyValueToInt(json['shift_duration_min_hours']),
      shiftDurationMaxHours: anyValueToInt(json['shift_duration_max_hours']),
      referralAmount: anyValueToInt(json['referral_amount']),
      showLearnMore: json['show_learn_more'] ?? false,
      maxEarnings: anyValueToInt(json['max_earnings']),
      daysOfValidity: anyValueToInt(json['days_of_validity']),
      referralText: json['referral_text'],
    );
  }
}
