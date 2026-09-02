import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/insurance_profile.dart';
import 'package:snabbit_runner/services/server_requests/insurance_http.dart';

class InsuranceProfileProvider extends ChangeNotifier {
  InsuranceProfile? _insuranceProfile;

  InsuranceProfile? get insuranceProfile => _insuranceProfile;

  bool loading = false;

  void setInsuranceProfile(Map<String,dynamic> json) {
    try {
      _insuranceProfile = InsuranceProfile.fromJson(json);
      notifyListeners();
    } catch (e){
      print(e);
    }
  }

  void clearInsuranceProfile() {
    // Future((){
      _insuranceProfile = null;
    //   notifyListeners();
    // });
  }

  void fetchData() async{
    if(loading) return; // Prevent multiple fetches
    Future(() async{
      // setInsuranceProfile(sampleJson);
      try {
        loading = true;
        notifyListeners();
        final response = await InsuranceHttp.getInsuranceTierInfo();
        if(response!=null){
          if(response.statusCode == 200){
            setInsuranceProfile(response.data);
          } else {
            print("Error fetching insurance profile: ${response.statusCode}");
          }
        } else {
          print("No response from server");
        }
        loading = false;
        notifyListeners();
      } catch (e) {
        print(e);
        loading = false;
        notifyListeners();
      }
    },
    );
  }

}
