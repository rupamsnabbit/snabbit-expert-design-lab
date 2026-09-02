import 'package:snabbit_runner/utils/common_methods.dart';

enum WalletItemType {
  credit,
  debit;

  static WalletItemType? fromString(String? data) {
    switch (data) {
      case "CREDIT":
        return WalletItemType.credit;
      case "DEBIT":
        return WalletItemType.debit;
      default:
        return null;
    }
  }

  String? get presentationKey {
    switch (this) {
      case WalletItemType.credit:
        return 'credited';
      case WalletItemType.debit:
        return 'withdrawal';
      default:
        return null;
    }
  }
}

class WalletItem {
  int id;
  DateTime? date;
  WalletItemType? type;
  int? amount;

  WalletItem({
    required this.id,
    this.date,
    this.type,
    this.amount,
  });

  factory WalletItem.fromJson(Map<String, dynamic> json) {
    return WalletItem(
      id: json['id'],
      date: DateTime.tryParse(json['date'].toString()),
      type: WalletItemType.fromString(json['type']),
      amount: anyValueToInt(json['amount']),
    );
  }
}
