import 'package:snabbit_runner/utils/common_methods.dart';

import 'wallet_item.dart';

class WalletData {
  List<WalletItem>? items;
  int? amount;
  bool? canWithdraw;
  Map<String, dynamic>? warning;
  Map<String, dynamic>? denialMessage;

  WalletData({
    this.items,
    this.amount,
    this.canWithdraw,
    this.warning,
    this.denialMessage,
  });

  factory WalletData.fromJson(Map<String, dynamic> json) {
    return WalletData(
      items: json['items'] != null
          ? List<WalletItem>.from(
              json['items'].map((e) => WalletItem.fromJson(e)))
          : null,
      amount: anyValueToInt(json['amount']),
      canWithdraw: json['can_withdraw'],
      warning: json['warning'],
      denialMessage: json['denial_message'],
    );
  }
}
