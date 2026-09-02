import 'package:flutter/cupertino.dart';

import '../models/wallet_data.dart';
import '../services/referral_http.dart';

class WalletProvider with ChangeNotifier {
  bool loading = false;
  WalletData? _walletData;

  WalletData? get walletData => _walletData;

  set walletData(WalletData? value) {
    _walletData = value;
    notifyListeners();
  }

  Future<void> getWalletData() async {
    try {
      loading = true;
      notifyListeners();
      final response = await ReferralHttp.getWalletData();
      if (response?.statusCode == 200) {
        _walletData = WalletData.fromJson(response?.data);
      }
    } catch (_) {}
    loading = false;
    notifyListeners();
  }
}
