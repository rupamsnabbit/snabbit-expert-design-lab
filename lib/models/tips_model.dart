import 'package:snabbit_runner/utils/common_methods.dart';

/// Model class for a single tip item
class TipItem {
  final DateTime? date;
  final int? amount;

  TipItem({
    this.date,
    this.amount,
  });

  factory TipItem.fromJson(Map<String, dynamic> json) {
    return TipItem(
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      amount: anyValueToInt(json['amount']),
    );
  }
}

/// Model class for tips response
class TipsResponse {
  final int? totalTips;
  final List<TipItem>? tipsList;

  TipsResponse({
    this.totalTips,
    this.tipsList,
  });

  factory TipsResponse.fromJson(Map<String, dynamic> json) {
    return TipsResponse(
      totalTips: anyValueToInt(json['total_tips']),
      tipsList: json['tips_list'] != null
          ? (json['tips_list'] as List)
              .map<TipItem>((item) => TipItem.fromJson(item))
              .toList()
          : null,
    );
  }
}
