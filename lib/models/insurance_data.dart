import 'package:snabbit_runner/utils/enums.dart';

class InsuranceData{
  String? spouseName;
  DateTime? spouseDob;
  String? firstChildName;
  DateTime? firstChildDob;
  Gender? firstChildGender;
  String? secondChildName;
  DateTime? secondChildDob;
  Gender? secondChildGender;

  InsuranceData({
    this.spouseName,
    this.spouseDob,
    this.firstChildDob,
    this.firstChildName,
    this.firstChildGender,
    this.secondChildDob,
    this.secondChildName,
    this.secondChildGender,
  });

  Map<String, dynamic> toMap() {
    return {
      'spouse_name': spouseName,
      'spouse_dob': spouseDob?.toIso8601String(),
      'first_child_name': firstChildName,
      'first_child_dob': firstChildDob?.toIso8601String(),
      'first_child_gender': firstChildGender?.toJson(),
      'second_child_name': secondChildName,
      'second_child_dob': secondChildDob?.toIso8601String(),
      'second_child_gender': secondChildGender?.toJson(),
    };
  }

  factory InsuranceData.fromMap(Map<String, dynamic> map) {
    return InsuranceData(
      spouseName: map['spouse_name'],
      spouseDob: map['spouse_dob'] != null ? DateTime.tryParse(map['spouse_dob']) : null,
      firstChildName: map['first_child_name'],
      firstChildDob: map['first_child_dob'] != null ? DateTime.tryParse(map['first_child_dob']) : null,
      firstChildGender: getGenderFromString(map['first_child_gender']),
      secondChildName: map['second_child_name'],
      secondChildDob: map['second_child_dob'] != null ? DateTime.tryParse(map['second_child_dob']) : null,
      secondChildGender: getGenderFromString(map['second_child_gender']),
    );
  }
}