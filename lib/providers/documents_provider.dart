import 'package:flutter/foundation.dart';

class DocumentsProvider with ChangeNotifier {
  String? _aadhaarFrontImage;
  String? _aadhaarBackImage;
  String? _panImage;


  String? get aadhaarFrontImage => _aadhaarFrontImage;
  String? get aadhaarBackImage => _aadhaarBackImage;
  String? get panImage => _panImage;



  set aadhaarFrontImage(String? value) {
    _aadhaarFrontImage = value;
    notifyListeners();
  }


  set aadhaarBackImage(String? value) {
    _aadhaarBackImage = value;
    notifyListeners();
  }

  set panImage(String? value) {
    _panImage = value;
    notifyListeners();
  }



  // Optional: Add a method to reset all values
  void reset() {
    _aadhaarFrontImage = null;
    _aadhaarBackImage = null;
    _panImage = null;
    notifyListeners();
  }
}