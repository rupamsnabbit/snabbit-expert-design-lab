
import 'package:snabbit_runner/utils/common_methods.dart';

class EarningModel {
  final String? adm;
  final EarningDetail? weekday;
  final EarningDetail? weekend;

  EarningModel({
    this.adm,
    this.weekday,
    this.weekend,
  });

  factory EarningModel.fromJson(Map<String, dynamic> json) {
    return EarningModel(
      adm: json['adm'],
      weekday: json['weekday'] != null
          ? EarningDetail.fromJson(json['weekday'] as Map<String, dynamic>)
          : null,
      weekend: json['weekend'] != null
          ? EarningDetail.fromJson(json['weekend'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'adm': adm,
      'weekday': weekday?.toJson(),
      'weekend': weekend?.toJson(),
    };
  }
}

class EarningDetail {
  final int? hourlyRate;
  final int? maxEarning;

  EarningDetail({
    this.hourlyRate,
    this.maxEarning,
  });

  factory EarningDetail.fromJson(Map<String, dynamic> json) {
    return EarningDetail(
      hourlyRate: anyValueToInt(json['hourly_rate']),
      maxEarning: anyValueToInt(json['max_earning']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hourly_rate': hourlyRate,
      'max_earning': maxEarning,
    };
  }
}