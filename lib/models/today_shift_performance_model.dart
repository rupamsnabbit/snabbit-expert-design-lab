import 'dart:ui';

import 'package:snabbit_runner/models/shift_config.dart';
import 'package:snabbit_runner/models/shift_performance_details.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/payout/shift_performance_breakdown_card.dart';

class TodayShiftPerformance {
  final WidgetData widgetData;
  final ShiftPerformanceDetails shiftPerformanceDetails;

  TodayShiftPerformance({
    required this.widgetData,
    required this.shiftPerformanceDetails,
  });

  factory TodayShiftPerformance.fromMap(Map<String, dynamic> map) {
    return TodayShiftPerformance(
      widgetData: WidgetData.fromMap(map['widget_data'] ?? {}),
      shiftPerformanceDetails: ShiftPerformanceDetails.fromJson(
          map['shift_performance_details'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'widget_data': widgetData.toMap(),
      'shift_performance_details': shiftPerformanceDetails.toJson(),
    };
  }
}

class WidgetData {
  final String imageUrl;
  final String bgImageUrl;
  final String bannerImageUrl;
  final List<Map<String, dynamic>?>? bannerSubtitle;

  WidgetData({
    required this.imageUrl,
    required this.bgImageUrl,
    required this.bannerImageUrl,
    required this.bannerSubtitle,
  });

  factory WidgetData.fromMap(Map<String, dynamic> map) {
    return WidgetData(
      imageUrl: map['image_url'] ?? '',
      bgImageUrl: map['bg_image_url'] ?? '',
      bannerImageUrl: map['banner_image_url'] ?? '',
      bannerSubtitle: map['banner_subtitle'] != null
          ? List<Map<String, dynamic>?>.from((map['banner_subtitle'] as List)
              .map((item) =>
                  item != null ? Map<String, dynamic>.from(item) : null))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'image_url': imageUrl,
      'bg_image_url': bgImageUrl,
      'banner_image_url': bannerImageUrl,
      'banner_subtitle': bannerSubtitle,
    };
  }
}

extension TodayShiftPerformanceExtension on TodayShiftPerformance {
  Color getBackgroundColor() {
    switch (shiftPerformanceDetails.shiftPerformance) {
      case ShiftPerformance.goodShift:
        return Color(0xFF5FB965);
      case ShiftPerformance.badShift:
        return Color(0xFF5C5C5C);
    }
  }

  String getFooterMessage({required LanguageProvider languageProvider}) {
    switch (shiftPerformanceDetails.shiftPerformance) {
      case ShiftPerformance.goodShift:
        if (shiftPerformanceDetails.shiftConfig.shiftEarningType ==
            GoodShiftStatusEnum.higher_base_pay) {
          return languageProvider.getMessage(
            "good_shift_footer_message_higher_base_pay",
            "Continue doing Good Shift and earn more.",
          );
        } else {
          return languageProvider.getMessage(
            "good_shift_footer_message_ming",
            "Continue doing Good Shift and earn more.",
          );
        }
      case ShiftPerformance.badShift:
        if (shiftPerformanceDetails.shiftConfig.waivedOffStatus ==
            BadShiftStatusEnum.waivedOff) {
          return languageProvider.getMessage(
            "bad_shift_footer_message_waived_off",
            "Follow all rules tomorrow to unlock higher earnings 👍🏻",
          );
        } else {
          return languageProvider.getMessage(
            "bad_shift_footer_message_normal",
            "Follow all rules tomorrow to unlock higher earnings 👍🏻",
          );
        }
      default:
        return "";
    }
  }

  String getHeaderMessage({required LanguageProvider languageProvider}) {
    switch (shiftPerformanceDetails.shiftPerformance) {
      case ShiftPerformance.goodShift:
        if (shiftPerformanceDetails.shiftConfig.shiftEarningType ==
            GoodShiftStatusEnum.higher_base_pay) {
          return languageProvider.getMessage(
            "good_shift_header_message_higher_base_pay",
            "Well done!\nGood shift completed.",
          );
        } else {
          return languageProvider.getMessage(
            "good_shift_header_message_ming",
            "Well done!\nGood shift completed.",
          );
        }
      case ShiftPerformance.badShift:
        if (shiftPerformanceDetails.shiftConfig.waivedOffStatus ==
            BadShiftStatusEnum.waivedOff) {
          return languageProvider.getMessage(
            "bad_shift_header_message_waived_off",
            "Normal Shift today.",
          );
        } else {
          return languageProvider.getMessage(
            "bad_shift_header_message_normal",
            "Normal Shift today.",
          );
        }
      default:
        return "";
    }
  }

  String getGoodShiftRateCardMessage(
      {required LanguageProvider languageProvider}) {
    if (shiftPerformanceDetails.shiftConfig.shiftEarningType ==
        GoodShiftStatusEnum.higher_base_pay) {
      return languageProvider.getMessage(
          "good_shift_rate_card_message_higher_base_pay",
          "You earned Higher Base Pay.");
    } else {
      return languageProvider.getMessage(
          "good_shift_rate_card_message_ming", "You earned MinG today.");
    }
  }

  String getBannerTitleMessage({required LanguageProvider languageProvider}) {
    switch (shiftPerformanceDetails.shiftPerformance) {
      case ShiftPerformance.goodShift:
        if (shiftPerformanceDetails.shiftConfig.shiftEarningType ==
            GoodShiftStatusEnum.higher_base_pay) {
          return languageProvider.getMessage(
            "good_shift_banner_title_message_higher_base_pay",
            "Good Shift today! You earned Higher Base Pay.",
          );
        } else {
          return languageProvider.getMessage(
            "good_shift_banner_title_message_ming",
            "Good Shift completed! You earned MinG today.",
          );
        }
      case ShiftPerformance.badShift:
        if (shiftPerformanceDetails.shiftConfig.waivedOffStatus ==
            BadShiftStatusEnum.waivedOff) {
          return languageProvider.getMessage(
            "bad_shift_banner_title_message_waived_off",
            "Normal Shift today.",
          );
        } else {
          return languageProvider.getMessage(
            "bad_shift_banner_title_message_normal",
            "Normal Shift today.",
          );
        }
      default:
        return "";
    }
  }
}
