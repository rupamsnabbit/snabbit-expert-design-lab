import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class LoginSelfieProvider with ChangeNotifier {
  LoginSelfie? _selfie;

  LoginSelfie? get selfie => _selfie;

  set selfie(LoginSelfie? newSelfie) {
    _selfie = newSelfie;
    notifyListeners();
  }

  void notifyLoginSelfieListeners() {
    notifyListeners();
  }
}

class LoginSelfie {
  double? lat;
  double? lng;
  XFile? selfie;
  XFile? gatePhoto;
  bool? isForMarkArrival;

  LoginSelfie(
      {this.lat, this.lng, this.selfie, this.gatePhoto, this.isForMarkArrival});

  factory LoginSelfie.fromMap(Map<String, dynamic> data) {
    return LoginSelfie(
        lat: data['lat'],
        lng: data['lng'],
        selfie: data['selfie'],
        gatePhoto: data['gatePhoto'],
        isForMarkArrival: data['isForMarkArrival']);
  }
}
