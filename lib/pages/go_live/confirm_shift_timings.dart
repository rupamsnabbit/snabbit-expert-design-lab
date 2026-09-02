import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/potential_earnings.dart';
import 'package:snabbit_runner/pages/go_live/cluster_details.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/potential_earnings_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/date_time_extension.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/go_live/shift_overview.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class ConfirmShiftTimings extends StatefulWidget {
  static const String routeName = '/confirm-shift-timings';

  const ConfirmShiftTimings({super.key});

  @override
  State<ConfirmShiftTimings> createState() => _ConfirmShiftTimingsState();
}

class _ConfirmShiftTimingsState extends State<ConfirmShiftTimings> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late PotentialEarningsProvider earningsProvider;
  bool init = true;
  bool loading = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      earningsProvider =
          Provider.of<PotentialEarningsProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  Future<void> _onConfirm() async {
    Navigator.pushReplacementNamed(context, ClusterDetailsPage.routeName);
  }

  Shift? get regularShift => earningsProvider.selectedRegularShiftDuration;

  Shift? get weekendShift => earningsProvider.selectedWeekendShiftDuration;

  int get totalPotential => weekendShift != null
      ? (earningsProvider.weekendRegularEarnings +
          earningsProvider.weekendEarnings)
      : earningsProvider.regularEarnings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        elevation: 5.r,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage(
            "in_training",
            "In Training",
          ),
          style: textTheme.bodyLarge,
        ),
      ),
      persistentFooterButtons: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: 173.w,
              height: 48.h,
              child: OutlinedButton(
                onPressed:
                    loading ? null : () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.brand),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  backgroundColor: AppColors.n0,
                ),
                child: Text(
                  languageProvider.getMessage('go_back', 'Go back'),
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.brand,
                    letterSpacing: -0.24,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              width: 172.5.w,
              height: 48.h,
              child: ElevatedButton(
                onPressed: loading ? null : _onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  languageProvider.getMessage('confirm', 'Confirm'),
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.n0,
                    letterSpacing: -0.24,
                  ),
                ),
              ),
            ),
          ],
        )
      ],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // AppBar
            SizedBox(height: 24.h),
            // Card
            Center(
              child: Container(
                width: 360.w,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getMessage('confirm_shift_timings',
                          'Confirm your shift timings'),
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.24,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    if (userProfileProvider.user?.workSchedule?.value ==
                        WorkSchedule.everyday) ...[
                      ShiftOverview(
                        startDay:
                            languageProvider.getMessage('monday', 'Monday'),
                        endDay: weekendShift != null
                            ? languageProvider.getMessage('friday', 'Friday')
                            : languageProvider.getMessage('sunday', 'Sunday'),
                        startTime: earningsProvider.selectedRegularStartTime
                                ?.to12HoursMinutes() ??
                            '--',
                        duration: regularShift?.durationHours ?? 0,
                        topSectionColor: const Color(0xFFDCF2EA),
                        bottomSectionColor: const Color(0xFF5AD448),
                        foregroundColor: const Color(0xFF317159),
                      ),
                      SizedBox(height: 16.h),
                    ],
                    // Weekday shift
                    if (userProfileProvider.user?.workSchedule?.value ==
                            WorkSchedule.weekendOnly ||
                        weekendShift != null)
                      ShiftOverview(
                        startDay:
                            languageProvider.getMessage('saturday', 'Saturday'),
                        endDay: languageProvider.getMessage('sunday', 'Sunday'),
                        startTime: (userProfileProvider
                                            .user?.workSchedule?.value ==
                                        WorkSchedule.weekendOnly
                                    ? earningsProvider.selectedRegularStartTime
                                    : earningsProvider.selectedWeekendStartTime)
                                ?.to12HoursMinutes() ??
                            '--',
                        duration:
                            (userProfileProvider.user?.workSchedule?.value ==
                                        WorkSchedule.weekendOnly
                                    ? regularShift?.durationHours
                                    : weekendShift?.durationHours) ??
                                0,
                        topSectionColor: const Color(0xFFFFEFD2),
                        bottomSectionColor: const Color(0xFFFBBC05),
                        foregroundColor: const Color(0xFF66460D),
                      ),
                    SizedBox(height: 24.h),
                    Divider(
                      color: const Color(0xFFD8DAE5),
                      thickness: 1,
                      height: 32.h,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          languageProvider.getMessage(
                              'potential_earnings', 'Potential Earnings:'),
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          formatIndianCurrency(totalPotential),
                          style: textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.n90,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 120.h),
          ],
        ),
      ),
    );
  }
}
