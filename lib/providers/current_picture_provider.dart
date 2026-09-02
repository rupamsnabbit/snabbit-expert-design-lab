import 'dart:io';
import 'package:flutter/material.dart';

class CurrentPictureProvider extends ChangeNotifier {
  File? _currentPicture;

  File? get currentPicture => _currentPicture;

  void setCurrentPicture(File picture) {
    _currentPicture = picture;
    notifyListeners();
  }

  void clearCurrentPicture() {
    _currentPicture = null;
    notifyListeners();
  }
}
