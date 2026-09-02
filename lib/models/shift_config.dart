import '../utils/common_methods.dart';

enum BadShiftStatusEnum {
  normal,
  waivedOff;

  static BadShiftStatusEnum? fromString(String? status) {
    switch (status) {
      case 'waived_off':
        return BadShiftStatusEnum.waivedOff;
      case 'normal':
        return BadShiftStatusEnum.normal;
      default:
        return BadShiftStatusEnum.normal;
    }
  }
}

enum GoodShiftStatusEnum {
  ming,
  higher_base_pay;

  static GoodShiftStatusEnum? fromString(String? status) {
    switch (status) {
      case 'higher_base_pay':
        return GoodShiftStatusEnum.higher_base_pay;
      case 'ming':
        return GoodShiftStatusEnum.ming;
      default:
        return GoodShiftStatusEnum.ming;
    }
  }
}

class ShiftConfig {
  final BadShiftStatusEnum waivedOffStatus;
  final String imageUrl;
  final GoodShiftStatusEnum shiftEarningType;
  final double? ming;
  final double? basePay;
  final double? higherBasePay;

  ShiftConfig({
    required this.waivedOffStatus,
    required this.imageUrl,
    required this.shiftEarningType,
    required this.ming,
    required this.basePay,
    required this.higherBasePay,
  });

  factory ShiftConfig.fromJson(Map<String, dynamic> json) {
    // Parse waivedOffStatus with backward compatibility
    BadShiftStatusEnum waivedOffStatus = BadShiftStatusEnum.normal;
    final waivedOffValue = json['bad_shift_status'];
    if (waivedOffValue is bool) {
      waivedOffStatus = waivedOffValue
          ? BadShiftStatusEnum.waivedOff
          : BadShiftStatusEnum.normal;
    } else if (waivedOffValue is String) {
      waivedOffStatus = BadShiftStatusEnum.fromString(waivedOffValue) ??
          BadShiftStatusEnum.normal;
    }

    // Parse shiftEarningType with backward compatibility
    GoodShiftStatusEnum shiftEarningType = GoodShiftStatusEnum.ming;
    final gtMingValue = json['good_shift_status'];
    if (gtMingValue is bool) {
      shiftEarningType = gtMingValue
          ? GoodShiftStatusEnum.higher_base_pay
          : GoodShiftStatusEnum.ming;
    } else if (gtMingValue is String) {
      shiftEarningType = GoodShiftStatusEnum.fromString(gtMingValue) ??
          GoodShiftStatusEnum.ming;
    }

    return ShiftConfig(
      waivedOffStatus: waivedOffStatus,
      imageUrl: json['image_url'] ?? '',
      shiftEarningType: shiftEarningType,
      ming: anyValueToDouble(json['ming']),
      basePay: anyValueToDouble(json['base_pay']),
      higherBasePay: anyValueToDouble(json['higher_base_pay']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bad_shift_status': waivedOffStatus == BadShiftStatusEnum.waivedOff
          ? 'waived_off'
          : 'normal',
      'image_url': imageUrl,
      'good_shift_status':
          shiftEarningType == GoodShiftStatusEnum.higher_base_pay
              ? 'higher_base_pay'
              : 'ming',
      'ming': ming,
      'base_pay': basePay,
      'higher_base_pay': higherBasePay,
    };
  }
}
