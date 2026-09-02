import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';

class InsuranceProfile {
  final QualifierInfo? qualifierInfo;
  final TierBenefits? tierBenefits;

  InsuranceProfile({
    this.qualifierInfo,
    this.tierBenefits,
  });

  factory InsuranceProfile.fromJson(Map<String, dynamic> json) {
    return InsuranceProfile(
      qualifierInfo: json['qualifier_info'] != null
          ? QualifierInfo.fromJson(
              json['qualifier_info'] as Map<String, dynamic>)
          : null,
      tierBenefits: json['tier_benefits'] != null
          ? TierBenefits.fromJson(json['tier_benefits'] as Map<String, dynamic>)
          : null,
    );
  }
}

class QualifierInfo {
  final Tier? nextTier;
  final DowngradeWarning? downgradeWarning;

  QualifierInfo({
    this.nextTier,
    this.downgradeWarning,
  });

  factory QualifierInfo.fromJson(Map<String, dynamic> json) {
    return QualifierInfo(
      nextTier: Tier.fromString(json['next_tier']),
      downgradeWarning: json['downgrade_warning'] != null
          ? DowngradeWarning.fromJson(
              json['downgrade_warning'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DowngradeWarning {
  final String? title;
  final List<ConditionalPoints>? conditions;
  final String? image;

  DowngradeWarning({
    this.title,
    this.conditions,
    this.image,
  });

  factory DowngradeWarning.fromJson(Map<String, dynamic> json) {
    return DowngradeWarning(
      title: json['title'],
      conditions: json['conditions'] != null
          ? (json['conditions'] as List<dynamic>?)
              ?.map<ConditionalPoints>(
                  (condition) => ConditionalPoints.fromJson(condition))
              .toList()
          : null,
      image: json['image'],
    );
  }
}

class TierBenefits {
  final InsuranceCoverageInfo? insuranceCoverageInfo;
  final TierUpgradeInfo? tierUpgradeInfo;
  final CongratulatoryMessage? congratulatoryMessage;

  TierBenefits({
    this.insuranceCoverageInfo,
    this.tierUpgradeInfo,
    this.congratulatoryMessage,
  });

  factory TierBenefits.fromJson(Map<String, dynamic> json) {
    return TierBenefits(
      insuranceCoverageInfo: json['insurance_coverage_info'] != null
          ? InsuranceCoverageInfo.fromJson(
              json['insurance_coverage_info'] as Map<String, dynamic>)
          : null,
      tierUpgradeInfo: json['tier_upgrade_info'] != null
          ? TierUpgradeInfo.fromJson(
              json['tier_upgrade_info'] as Map<String, dynamic>)
          : null,
      congratulatoryMessage: json['congratulatory_message'] != null
          ? CongratulatoryMessage.fromJson(
              json['congratulatory_message'] as Map<String, dynamic>)
          : null,
    );
  }
}

class InsuranceCoverageInfo {
  final String? amount;
  final int? childrenCount;
  final int? childrenAge;
  final Color? borderColor;

  InsuranceCoverageInfo({
    this.amount,
    this.borderColor,
    this.childrenCount,
    this.childrenAge,
  });

  factory InsuranceCoverageInfo.fromJson(Map<String, dynamic> json) {
    return InsuranceCoverageInfo(
      amount: json['amount'],
      childrenCount: json['children_count'],
      childrenAge: json['children_age'],
      borderColor: json['border_color'] != null
          ? hexToColor(json['border_color'])
          : null,
    );
  }
}

class TierUpgradeInfo {
  final String? image;
  final List<ConditionalPoints>? conditionalPoints;
  final Color? borderColor;

  TierUpgradeInfo({
    this.image,
    this.conditionalPoints,
    this.borderColor,
  });

  factory TierUpgradeInfo.fromJson(Map<String, dynamic> json) {
    return TierUpgradeInfo(
      image: json['image'],
      conditionalPoints: (json['conditions'] as List<dynamic>?)
          ?.map((e) => ConditionalPoints.fromJson(e as Map<String, dynamic>))
          .toList(),
      borderColor: json['border_color'] != null
          ? hexToColor(json['border_color'])
          : null,
    );
  }
}

class ConditionalPoints {
  final String? name;
  final bool? isAchieved;
  final dynamic value; // Assuming value can be of any type, adjust as necessary

  ConditionalPoints({
    this.name,
    this.isAchieved,
    this.value,
  });

  factory ConditionalPoints.fromJson(Map<String, dynamic> json) {
    return ConditionalPoints(
      name: json['name'],
      isAchieved: json['is_achieved'] ?? false,
      value: json['value'],
    );
  }
}

class CongratulatoryMessage {
  final String? message;
  final String? image;
  final String? gif;

  CongratulatoryMessage({
    this.message,
    this.image,
    this.gif,
  });

  factory CongratulatoryMessage.fromJson(Map<String, dynamic> json) {
    return CongratulatoryMessage(
      message: json['message'],
      image: json['image'],
      gif: json['gif'],
    );
  }
}
