import 'package:flutter/material.dart';

import '../services/server_requests/language_http.dart';
import '../utils/enums.dart';

class PreferredLanguageProvider extends ChangeNotifier {
  List<LanguageData> _languages = [];

  bool _isLoading = false;

  List<LanguageData> get languages => _languages;

  bool get isLoading => _isLoading;

  Future<void> loadLanguages() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await LanguageHttp.fetchLanguages();
      if (response != null) {
        _languages = response.data
            .map<LanguageData>((e) => LanguageData.fromMap(e))
            .toList();
      } else {
        // Handle error from server
      }
    } catch(e) {
      debugPrint("$e");
      // DO NOTHING
    }

    _isLoading = false;
    notifyListeners();
  }
}

class LanguageData {
  final String nameNative;
  final String name;
  final String obj;
  final String iconText1;
  final String iconText2;

  LanguageData({
    required this.nameNative,
    required this.name,
    required this.obj,
    required this.iconText1,
    required this.iconText2,
  });

  // Optional: Factory constructor to create LanguageData from a map
  factory LanguageData.fromMap(Map<String, dynamic> map) {
    return LanguageData(
      nameNative: map['name_native'] as String,
      name: map['name'] as String,
      obj: map['obj'],
      iconText1: map['icon_text1'] as String,
      iconText2: map['icon_text2'] as String,
    );
  }
}