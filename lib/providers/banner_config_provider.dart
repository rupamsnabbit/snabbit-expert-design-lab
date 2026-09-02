import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/banner_config.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

class BannerConfigProvider with ChangeNotifier {
  List<BannerConfig> _allBanners = [];
  bool _loaded = false;

  void loadBanners() {
    try {
      final jsonStr = RemoteConfigService.instance
          .getString(RemoteConfigKeys.genericExpertAppBanner);
      if (jsonStr.isEmpty) {
        _allBanners = [];
        _loaded = true;
        notifyListeners();
        return;
      }

      final List<dynamic> bannersJson = json.decode(jsonStr);

      _allBanners = bannersJson
          .map((b) => BannerConfig.fromJson(b as Map<String, dynamic>))
          .where((banner) => banner.placement != null && banner.isActiveNow)
          .toList();

      _loaded = true;
      notifyListeners();
    } catch (_) {
      _allBanners = [];
      _loaded = true;
      notifyListeners();
    }
  }

  BannerConfig? getBannerForPlacement(BannerPlacement placement) {
    try {
      return _allBanners.firstWhere((b) => b.placement == placement);
    } catch (_) {
      return null;
    }
  }

  /// Whether banners have been loaded at least once.
  bool get isLoaded => _loaded;
}
