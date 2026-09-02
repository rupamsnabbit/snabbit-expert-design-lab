import 'package:snabbit_runner/providers/user_profile.dart';

import '../utils/enums.dart';

class Attendance {
  int? reward;
  int? presentDays;
  List<DailyAttendance> dailyAttendanceList;

  Attendance({
    this.reward,
    this.presentDays,
    this.dailyAttendanceList = const [],
  });

  factory Attendance.fromMap(Map<String, dynamic> data) {
    return Attendance(
      reward: data['reward'],
      presentDays: data['present'],
      dailyAttendanceList: data["daily_attendance"]
          ?.map<DailyAttendance>((e) {
        return DailyAttendance.fromMap(e);
      }).toList(),
    );
  }
}

class DailyAttendance {
  DateTime date;
  DailyAttendanceStatus? status;

  DailyAttendance({
    required this.date,
    this.status,
  });

  factory DailyAttendance.fromMap(Map<String, dynamic> data) {
    return DailyAttendance(
      date: getDateTimeFromServerString(data['date']) ?? DateTime.now(),
      status: getDailyAttendanceStatusFromString(data['status']),
    );
  }
}
