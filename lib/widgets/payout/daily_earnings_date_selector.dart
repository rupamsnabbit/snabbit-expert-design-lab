import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class DailyEarningsDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const DailyEarningsDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavigationButton(context, false),
          SizedBox(width: 8.w),
          _buildDateDisplay(context),
          SizedBox(width: 8.w),
          _buildNavigationButton(context, true),
        ],
      ),
    );
  }

  Widget _buildDateDisplay(BuildContext context) {
    final day = selectedDate.day;
    final month = selectedDate.month;
    final year = selectedDate.year;

    return Column(
      children: [
        Text(
          _getDayName(selectedDate),
          style: TextStyle(
            fontFamily: 'Metropolis',
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.24,
            color: const Color(0xFF40515B),
          ),
        ),
        Text(
          "${day}${_getDaySuffix(day)} ${_getMonthName(month)} $year",
          style: TextStyle(
            fontFamily: 'Metropolis',
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.24,
            color: const Color(0xFF40515B),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButton(BuildContext context, bool isForward) {
    return Container(
      width: 28.r,
      height: 28.r,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: AppColors.n50),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          isForward ? Icons.chevron_right : Icons.chevron_left,
          color: AppColors.n90,
          size: 16.r,
        ),
        onPressed: () {
          onDateChanged(selectedDate.add(
            Duration(days: isForward ? 1 : -1),
          ));
        },
      ),
    );
  }

  String _getDayName(DateTime date) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
  }

  String _getMonthName(int month) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }

    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
