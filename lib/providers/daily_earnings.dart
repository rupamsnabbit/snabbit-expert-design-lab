import 'package:flutter/material.dart';

import '../services/daily_earnings_http.dart';
import '../utils/common_methods.dart';
import '../utils/enums.dart';

/// Provider for the Daily Earnings List
class DailyEarningsListProvider with ChangeNotifier {
  bool _loading = false;
  String? _error;
  List<DailyEarningListItem> _earningsList = [];
  int _totalEarnings = 0;

  bool get loading => _loading;

  String? get error => _error;

  List<DailyEarningListItem> get earningsList => _earningsList;

  int get totalEarnings => _totalEarnings;

  Future<void> fetchMonthlyEarnings(
      DateTime monthStart, DateTime monthEnd) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await DailyEarningsHttp.getMonthlyEarningsList(
        startDate: monthStart,
        endDate: monthEnd,
      );

      if (response == null) {
        _error = 'Failed to fetch data';
        _loading = false;
        notifyListeners();
        return;
      }

      final data = response.data;
      _earningsList = (data['earning_list'] as List)
          .map<DailyEarningListItem>(
              (item) => DailyEarningListItem.fromJson(item))
          .toList();

      // Sort earnings list by date in descending order (newest first)
      _earningsList.sort((a, b) {
        return b.date.compareTo(a.date);
      });

      // Use total earnings directly from API
      _totalEarnings = anyValueToInt(data['total_range_earning']) ?? 0;

      _loading = false;
      notifyListeners();
    } catch (e, st) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  // void _calculateTotalEarnings() {
  //   _totalEarnings =
  //       _earningsList.fold(0, (sum, item) => sum + (item.amount ?? 0));
  // }
  //
  // // Generate mock data for testing
  // List<DailyEarningListItem> _generateMockData(DateTime month) {
  //   final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  //   final List<DailyEarningListItem> items = [];
  //
  //   // Generate data for each day of the month, in descending order (newest first)
  //   for (int day = daysInMonth; day >= 17; day--) {
  //     final date = DateTime(month.year, month.month, day);
  //     final weekday = date.weekday;
  //
  //     // Set different statuses based on weekday patterns
  //     AttendanceStatus status;
  //     if (weekday == 7) {
  //       // Sunday
  //       status = AttendanceStatus.NO_SHOW;
  //     } else if (weekday == 6) {
  //       // Saturday
  //       status =
  //       day % 4 == 0 ? AttendanceStatus.ABSENT : AttendanceStatus.PRESENT;
  //     } else if (day % 15 == 0) {
  //       status = AttendanceStatus.FALSE_ATTENDANCE;
  //     } else if (day % 5 == 0) {
  //       status = AttendanceStatus.FALSE_ATTENDANCE_WARNING;
  //     } else if (day % 7 == 0) {
  //       status = AttendanceStatus.ABSENT;
  //     } else {
  //       status = AttendanceStatus.PRESENT;
  //     }
  //
  //     // Generate amount based on status
  //     int? amount;
  //     List<String>? tags;
  //
  //     switch (status) {
  //       case AttendanceStatus.PRESENT:
  //         amount = weekday == 6 ? 350 : (50 + (day * 10));
  //         if (day % 6 == 0) {
  //           amount = -50; // Some present days have negative amount
  //         }
  //         break;
  //       case AttendanceStatus.ABSENT:
  //         amount = 0;
  //         break;
  //       case AttendanceStatus.FALSE_ATTENDANCE_WARNING:
  //         amount = 0;
  //         break;
  //       case AttendanceStatus.FALSE_ATTENDANCE:
  //         amount = -300;
  //         tags = ["PROVISIONAL", "MORNING"];
  //         break;
  //       case AttendanceStatus.NO_SHOW:
  //         amount = -500;
  //         tags = ["PROVISIONAL", "MORNING", "LOGIN"];
  //         break;
  //     }
  //
  //     items.add(DailyEarningListItem(
  //       date: date,
  //       amount: amount,
  //       status: status,
  //     ));
  //   }
  //
  //   return items;
  // }
}

/// Model class for a daily earning list item
class DailyEarningListItem {
  final DateTime date;
  final int? amount;
  final AttendanceStatus? status;
  final bool? isMingEligible;

  DailyEarningListItem({
    required this.date,
    this.amount,
    this.status,
    this.isMingEligible,
  });

  factory DailyEarningListItem.fromJson(Map<String, dynamic> json) {
    return DailyEarningListItem(
      date: DateTime.parse(json['date']),
      amount: anyValueToInt(json['total_earning']),
      status: getAttendanceStatusFromString(json['attendance_status']),
      isMingEligible: json['is_ming_eligible'],
    );
  }
}
