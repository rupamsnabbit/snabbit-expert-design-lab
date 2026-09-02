import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/tnc_accept.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';

class ShiftTimingsPage extends StatefulWidget {
  static const String routeName = '/shift-timings';

  const ShiftTimingsPage({super.key});

  @override
  State<ShiftTimingsPage> createState() => _ShiftTimingsPageState();
}

class _ShiftTimingsPageState extends State<ShiftTimingsPage> {
  late List<ShiftDay> shiftDays;
  bool loading = true;
  late LanguageProvider languageProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      _prepareShiftData();
    });
  }

  void _prepareShiftData() {
    final userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final defaultShifts = userProfileProvider.user?.defaultShifts ?? [];

    // Map to store shifts by day (0-6)
    final Map<int, DefaultShift> shiftsByDay = {};
    for (var shift in defaultShifts) {
      shiftsByDay[shift.day] = shift;
    }

    // Find the most recent Monday (or today if it's Monday)
    final DateTime now = DateTime.now();
    // Weekday is 1-7 where 1 is Monday and 7 is Sunday
    final int daysToSubtract = (now.weekday - 1) % 7;
    final DateTime monday = now.subtract(Duration(days: daysToSubtract));

    // Create dates for Monday through Sunday
    final List<ShiftDay> weekDays = [];
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      // Convert to 0-6 format where 0 is Monday
      final dayOfWeek = (date.weekday - 1) % 7;

      // Get shift for this day
      final shift = shiftsByDay[dayOfWeek];

      // Add the day with either a real shift or null
      weekDays.add(ShiftDay(
        date: date,
        shift: shift,
      ));
    }

    setState(() {
      shiftDays = weekDays;
      loading = false;
    });
  }

  void _confirmShifts() {
    Navigator.of(context).pushReplacementNamed(TncAcceptPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);

    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        elevation: 5.r,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage("in_training", "In Training"),
          style: textTheme.bodyLarge,
        ),
      ),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: _confirmShifts,
            child: Text(
              languageProvider.getMessage("i_confirm", "I Confirm"),
            ),
          ),
        ),
      ],
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16.r),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 26.w,
                  vertical: 34.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.n0,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  children: [
                    Text(
                      languageProvider.getMessage("your_shift", "Your shift"),
                      style: textTheme.bodyLarge,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "Mon - Sun",
                      style: textTheme.displayLarge?.copyWith(
                        fontSize: 28.sp,
                        fontStyle: FontStyle.normal,
                        color: AppColors.n90,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        itemCount: shiftDays.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1.h,
                          color: Colors.grey.shade300,
                        ),
                        itemBuilder: (context, index) {
                          final day = shiftDays[index];
                          return ShiftDayItem(day: day);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class ShiftDayItem extends StatelessWidget {
  final ShiftDay day;

  const ShiftDayItem({
    super.key,
    required this.day,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Format date components using intl
    final dayAbbr = DateFormat('E').format(day.date).substring(0, 2);
    final dateNum = day.date.day;
    final month = DateFormat('MMM').format(day.date).toUpperCase();

    // Format time for display or show dash if no shift
    final String timeDisplay;
    if (day.shift != null) {
      final startTime = _formatTimeForDisplay(day.shift!.startTime);
      final endTime = _formatTimeForDisplay(day.shift!.endTime);
      timeDisplay = "$startTime - $endTime";
    } else {
      timeDisplay = "-";
    }

    // Full date format
    final fullDate =
        DateFormat('EEEE, d\'${getDaySuffix(dateNum)}\' MMMM, yyyy')
            .format(day.date);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        children: [
          // Day abbreviation and date
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAF1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayAbbr,
                  style: textTheme.displayLarge?.copyWith(
                    color: AppColors.n90,
                    fontStyle: FontStyle.normal,
                    fontSize: 22.sp,
                  ),
                ),
                // Text(
                //   "$dateNum $month",
                //   style: textTheme.titleLarge?.copyWith(
                //     color: AppColors.n70,
                //   ),
                // ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          // Shift time and date details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeDisplay,
                  style: textTheme.headlineSmall,
                ),
                // SizedBox(height: 10.h),
                // Text(
                //   fullDate,
                //   style: textTheme.bodyLarge?.copyWith(
                //     color: AppColors.n60,
                //     fontWeight: FontWeight.w400,
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeForDisplay(String time) {
    // Convert from "08:00:00" format to "08:00 AM" format
    final parts = time.split(':');
    if (parts.length < 2) return time;

    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';

    if (hour > 12) {
      hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }

    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}

class ShiftDay {
  final DateTime date;
  final DefaultShift? shift;

  ShiftDay({
    required this.date,
    this.shift,
  });
}
