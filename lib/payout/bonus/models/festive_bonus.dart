import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

enum DeductionDayStatus {
  goodShift,
  badShift,
  critical,
  important,
  general;

  static DeductionDayStatus? fromString(String? status) {
    switch (status?.toLowerCase()) {
      case "good_shift":
        return DeductionDayStatus.goodShift;
      case "bad_shift":
        return DeductionDayStatus.badShift;
      case "critical":
        return DeductionDayStatus.critical;
      case "important":
        return DeductionDayStatus.important;
      case "general":
        return DeductionDayStatus.general;
      default:
        return null;
    }
  }
}

class FestiveBonus {
  BonusInfo? bonusInfo;
  FestivePaymentSummary? paymentSummary;
  DateWiseDeductions? dateWiseDeductions;

  FestiveBonus({
    this.bonusInfo,
    this.paymentSummary,
    this.dateWiseDeductions,
  });

  factory FestiveBonus.fromJson(Map<String, dynamic> json) {
    return FestiveBonus(
      bonusInfo: json['bonus_info'] != null
          ? BonusInfo.fromJson(json['bonus_info'])
          : null,
      paymentSummary: json['payment_summary'] != null
          ? FestivePaymentSummary.fromJson(json['payment_summary'])
          : null,
      dateWiseDeductions: json['date_wise_deductions'] != null
          ? DateWiseDeductions.fromJson(json['date_wise_deductions'])
          : null,
    );
  }
}

class BonusInfo {
  Map<String, dynamic>? title;
  Map<String, dynamic>? paymentDate;
  RemoteImage? bg;
  RemoteImage? icon;
  PaymentState? status;

  BonusInfo({
    this.title,
    this.paymentDate,
    this.bg,
    this.icon,
    this.status,
  });

  factory BonusInfo.fromJson(Map<String, dynamic> json) {
    return BonusInfo(
      title: json['title'],
      paymentDate: json['payment_date'],
      bg: json['bg_image'] != null ? RemoteImage.fromJson(json['bg_image']) : null,
      icon: json['icon'] != null ? RemoteImage.fromJson(json['icon']) : null,
      status: PaymentState.fromString(json['status']),
    );
  }
}

class FestivePaymentSummary {
  List<Element>? elements;
  Element? total;

  FestivePaymentSummary({
    this.elements,
    this.total,
  });

  factory FestivePaymentSummary.fromJson(Map<String, dynamic> json) {
    return FestivePaymentSummary(
      elements: (json['items'] as List<dynamic>?)
          ?.map((e) => Element.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] != null ? Element.fromJson(json['total']) : null,
    );
  }
}

class Element {
  Map<String, dynamic>? title;
  Map<String, dynamic>? subtitle;
  Map<String, dynamic>? value;

  Element({
    this.title,
    this.subtitle,
    this.value,
  });

  factory Element.fromJson(Map<String, dynamic> json) {
    return Element(
      title: json['title'],
      subtitle: json['subtitle'],
      value: json['value'],
    );
  }
}

class Item {
  Map<String, dynamic>? title;
  RemoteImage? icon;

  Item({
    this.title,
    this.icon,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      title: json['title'],
      icon: json['icon'] != null ? RemoteImage.fromJson(json['icon']) : null,
    );
  }
}

class TrackerInfo {
  Map<String, dynamic>? title;
  List<Item>? items;

  TrackerInfo({
    this.title,
    this.items,
  });

  factory TrackerInfo.fromJson(Map<String, dynamic> json) {
    return TrackerInfo(
      title: json['title'],
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => Item.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DateWiseDeductions {
  Map<String, dynamic>? trackerTitle;
  Map<String, dynamic>? breakdownTitle;
  List<DeductionDay>? days;
  TrackerInfo? goodShift;
  TrackerInfo? badShift;

  DateWiseDeductions({
    this.trackerTitle,
    this.breakdownTitle,
    this.days,
    this.goodShift,
    this.badShift,
  });

  factory DateWiseDeductions.fromJson(Map<String, dynamic> json) {
    return DateWiseDeductions(
      trackerTitle: json['tracker_title'],
      breakdownTitle: json['breakdown_title'],
      days: (json['days'] as List<dynamic>?)
          ?.map((e) => DeductionDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      goodShift: json['good_shift'] != null
          ? TrackerInfo.fromJson(json['good_shift'])
          : null,
      badShift: json['bad_shift'] != null
          ? TrackerInfo.fromJson(json['bad_shift'])
          : null,
    );
  }
}

class DeductionDay {
  DateTime? date;
  DeductionDayStatus? status;
  Map<String, dynamic>? value;
  RemoteImage? icon;
  bool? isBlinking;
  DetailsItem? details;

  DeductionDay({
    this.date,
    this.status,
    this.value,
    this.icon,
    this.isBlinking,
    this.details,
  });

  factory DeductionDay.fromJson(Map<String, dynamic> json) {
    return DeductionDay(
      date: json['date'] != null ? DateTime.tryParse(json['date'] ?? "") : null,
      status: DeductionDayStatus.fromString(json['status']),
      value: json['value'],
      icon: json['icon'] != null ? RemoteImage.fromJson(json['icon']) : null,
      isBlinking: json['is_blinking'],
      details: json['details'] != null
          ? DetailsItem.fromJson(json['details'])
          : null,
    );
  }
}

class DetailsItem {
  Map<String, dynamic>? title;
  List<DetailsItemIcon>? items;

  DetailsItem({
    this.title,
    this.items,
  });

  factory DetailsItem.fromJson(Map<String, dynamic> json) {
    return DetailsItem(
      title: json['title'],
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => DetailsItemIcon.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DetailsItemIcon {
  RemoteImage? icon;
  Map<String, dynamic>? title;
  List<DetailsItemDescription>? items;

  DetailsItemIcon({
    this.icon,
    this.title,
    this.items,
  });

  factory DetailsItemIcon.fromJson(Map<String, dynamic> json) {
    return DetailsItemIcon(
      icon: json['icon'] != null ? RemoteImage.fromJson(json['icon']) : null,
      title: json['title'],
      items: (json['items'] as List<dynamic>?)
          ?.map(
              (e) => DetailsItemDescription.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DetailsItemDescription {
  Map<String, dynamic>? title;

  DetailsItemDescription({
    this.title,
  });

  factory DetailsItemDescription.fromJson(Map<String, dynamic> json) {
    return DetailsItemDescription(
      title: json['title'],
    );
  }
}

class FestiveBanner {
  Map<String, dynamic>? title;
  Map<String, dynamic>? subtitle;
  Map<String, dynamic>? value;
  RemoteImage? bgImage;
  Footer? footer;

  FestiveBanner({
    this.title,
    this.subtitle,
    this.value,
    this.bgImage,
    this.footer,
  });

  factory FestiveBanner.fromJson(Map<String, dynamic> json) {
    return FestiveBanner(
      title: json['title'],
      subtitle: json['subtitle'],
      value: json['value'],
      bgImage: json['bg_image'] != null ? RemoteImage.fromJson(json['bg_image']) : null,
      footer: json['footer'] != null ? Footer.fromJson(json['footer']) : null,
    );
  }
}

class Footer {
  RemoteImage? icon;
  Map<String, dynamic>? title;

  Footer({this.icon, this.title,});

  factory Footer.fromJson(Map<String, dynamic> json) {
    return Footer(
      title: json['title'],
      icon: json['icon'] != null ? RemoteImage.fromJson(json['icon']) : null,
    );
  }

}