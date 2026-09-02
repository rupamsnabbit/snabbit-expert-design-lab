import 'package:flutter/cupertino.dart';
import 'package:snabbit_runner/home/models/info_banner.dart';
import 'package:snabbit_runner/services/runner_http.dart';

class InfoBannerProvider with ChangeNotifier {
  List<InfoBannerModel>? infoBanners;

  Future<void> fetchBanners() async {
    try {
      infoBanners?.clear();
      final response = await RunnerHttp.fetchInfoBanners();
      if (response != null) {
        infoBanners = response.data
            .map<InfoBannerModel>((e) => InfoBannerModel.fromJson(e))
            .toList();
      }
      notifyListeners();
    } catch (_) {}
  }
}
