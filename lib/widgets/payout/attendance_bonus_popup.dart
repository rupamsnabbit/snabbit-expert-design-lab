import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';

import '../../pages/payout/attendance.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import '../../utils/enums.dart';
import 'custom_progress_bar.dart';

void showAttendanceBonusDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        elevation: 0,
        child: Badge(
          largeSize: 27.r,
          padding: EdgeInsets.all(4.r),
          backgroundColor: const Color(0xffA9A9A9),
          label: InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Icon(
              Icons.close,
              size: 20.r,
            ),
          ),
          child: const AttendanceBonusPopup(),
        ),
      );
    },
  );
}

class AttendanceBonusPopup extends StatefulWidget {
  const AttendanceBonusPopup({super.key});

  @override
  State<AttendanceBonusPopup> createState() => AttendanceBonusPopupState();
}

class AttendanceBonusPopupState extends State<AttendanceBonusPopup> {
  bool init = true;
  late LanguageProvider languageProvider;
  late PayoutProvider payoutProvider;

  String get asset {
    if (hasViolations) {
      return AssetConstants.treasureChest0;
    } else if (isEarned) {
      return AssetConstants.fullyOpen;
    } else if (attendanceProgress >= 0.75) {
      return AssetConstants.treasureChest75;
    } else if (attendanceProgress >= 0.5) {
      return AssetConstants.treasureChest;
    } else if (attendanceProgress >= 0.25) {
      return AssetConstants.treasureChest;
    } else {
      return AssetConstants.treasureChest0;
    }
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  int get target {
    // Get the attendance target from incentives if available
    return payoutProvider.incentives?.attendanceIncentives?.rewardTarget ?? 0;
  }

  int get current {
    // Get current attendance from incentives if available
    return payoutProvider.incentives?.attendanceIncentives?.daysPresent ?? 0;
  }

  int get bonus {
    // Get max attendance bonus amount
    return payoutProvider.incentives?.attendanceIncentives?.maxReward ?? 0;
  }

  int? get absentDays {
    // Get max attendance bonus amount
    return payoutProvider.incentives?.attendanceIncentives?.absentDays;
  }

  int? get maxAbsentDays {
    // Get max attendance bonus amount
    return payoutProvider.incentives?.attendanceIncentives?.maxAbsentDays;
  }

  double get attendanceProgress {
    if (target <= 0) return 0.0;
    double progress = current / target;
    return progress <= 1.0 ? progress : 1.0;
  }

  bool get excessAbsent {
    try {
      return absentDays != null &&
          maxAbsentDays != null &&
          absentDays! > maxAbsentDays!;
    } catch (e) {
      return false;
    }
  }

  List<String> get weekDays {
    return payoutProvider.incentives?.attendanceIncentives?.weekDays ?? [];
  }

  String? get weekDaysInText {
    return constructDaysSentence(weekDays,languageProvider);
  }

  List<String> get absentWeekDays {
    return payoutProvider.incentives?.attendanceIncentives?.absentWeekDays ?? [];
  }

  String? get absentWeekDaysInText {
    return constructDaysSentence(absentWeekDays,
      languageProvider,);
  }

  PaymentState? get paymentState {
    return payoutProvider.incentives?.attendanceIncentives?.paymentState;
  }

  bool get isEarned {
    return paymentState == PaymentState.earned;
  }

  bool get hasViolations => excessAbsent || absentWeekDays.isNotEmpty || paymentState == PaymentState.missed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Image.asset(
              !hasViolations
                  ? AssetConstants.attendanceBonusBg
                  : AssetConstants.disabledBonusBg,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          width: 350.r,
          constraints: BoxConstraints(
            minHeight: 416.r,
          ),
          decoration: BoxDecoration(
            // color: const Color(0xFF32237C),
            borderRadius: BorderRadius.circular(8.r),
          ),
          padding: EdgeInsets.only(
            top: 24.h,
            bottom: 12.h,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.getMessage(
                    "attendance_bonus", "Attendance Bonus"),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: hasViolations ? const Color(0xFF535353) :  AppColors.n0,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: 11.h),
              if (isEarned)
                Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Text(
                    formatIndianCurrency(bonus),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 42.sp,
                          color: AppColors.n0,
                        ),
                  ),
                ),

              // Image - will shrink to accommodate the expanded container
              Image.asset(
                asset,
                fit: BoxFit.contain,
                height: (isEarned) ? 80.h : 122.h,
              ),
              SizedBox(height: 7.h),

              // Progress container - will take as much space as needed
              Flexible(
                // flex: 40,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: Container(
                    width: 1.sw,
                    padding: EdgeInsets.symmetric(
                      vertical: 20.h,
                      horizontal: 28.w,
                    ),
                    decoration: BoxDecoration(
                      color: !hasViolations
                          ? const Color(0xFF1A0C5D)
                          : const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$current/$target Days",
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppColors.n0,
                                      fontSize: 21.5.sp,
                                    ),
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    languageProvider.getMessage(
                                      "unlock",
                                      "Unlock ",
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.n0,
                                        ),
                                  ),
                                  Text(
                                    formatIndianCurrency(bonus),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: !hasViolations
                                              ? AppColors.y40
                                              : AppColors.n0,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          CustomProgressBar(
                            progress: !hasViolations
                                ? attendanceProgress
                                : 0,
                            lockPosition: 0,
                            addEndCircle: false,
                            color: hasViolations
                                ? AppColors.n0
                                : excessAbsent
                                    ? AppColors.r40
                                    : null,
                          ),
                          SizedBox(height: 13.h),
                          Center(
                            child: isEarned
                                    ? RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: Theme.of(context)
                                              .textTheme
                                              .displaySmall
                                              ?.copyWith(
                                                color: AppColors.n0,
                                              ),
                                          children: [
                                            TextSpan(
                                              text: "${
                                            languageProvider.getMessage(
                                              "congratulations",
                                              "Congratulations!",
                                            )
                                          } ",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displaySmall
                                                  ?.copyWith(
                                                    color: AppColors.y40,
                                                  ),
                                            ),
                                            TextSpan(
                                              text: languageProvider
                                                  .getMessage(
                                                      'bonus_unlocked',
                                                      'Bonus Unlocked'),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          excessAbsent ?
                                          Text(
                                                  languageProvider.getFormattedMessage(
                                                  "x_days_absent",
                                                      "{{absent_count}} days absent",
                                                      {
                                                        'absent_count':absentDays,
                                                      }
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .displaySmall
                                                      ?.copyWith(
                                                    color: const Color(0xFFFF0000),
                                                  ),
                                                )
                                              :
                                          RichText(
                                            softWrap: true,
                                            text: TextSpan(
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displaySmall
                                                  ?.copyWith(
                                                    color: AppColors.n0,
                                                  ),
                                              children: [
                                                TextSpan(
                                                  text: "${languageProvider
                                                          .getMessage(
                                                        "work",
                                                        "Work",
                                                      )}\n",
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: AppColors.n0,
                                                      ),
                                                ),
                                                TextSpan(
                                                  text: languageProvider
                                                      .getFormattedMessage(
                                                    "days_to_unlock",
                                                    "{{remaining_target_days}} days",
                                                    {
                                                      'remaining_target_days':
                                                          target - current,
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          //a widget will always be displayed on the left
                                          if(absentWeekDays.isNotEmpty || weekDays.isNotEmpty)
                                          Container(
                                            height: 24.h,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 18.w,
                                            ),
                                            child: const VerticalDivider(
                                              thickness: 2,
                                              width: 2,
                                              color: AppColors.n60,
                                            ),
                                          ),
                                          if(absentWeekDays.isNotEmpty || weekDays.isNotEmpty)
                                          Flexible(
                                            child: RichText(
                                              softWrap: true,
                                              text: TextSpan(
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displaySmall
                                                    ?.copyWith(
                                                      color: absentWeekDays
                                                              .isEmpty
                                                          ? AppColors.n0
                                                          : const Color(
                                                              0xFFFF0000),
                                                    ),
                                                children: [
                                                  TextSpan(
                                                    text: "${absentWeekDays
                                                                .isNotEmpty
                                                            ? languageProvider
                                                                .getMessage(
                                                                "absent_on",
                                                                "Absent on",
                                                              )
                                                            : languageProvider
                                                                .getMessage(
                                                                "do_not_miss",
                                                                "Do not miss",
                                                              )}\n",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: absentWeekDays
                                                                  .isEmpty
                                                              ? AppColors.n0
                                                              : const Color(
                                                                  0xFFFF0000),
                                                        ),
                                                  ),
                                                  TextSpan(
                                                    text: absentWeekDays
                                                            .isEmpty
                                                        ? weekDaysInText
                                                        : absentWeekDaysInText,
                                                  ),
                                                ],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 13.h),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(Attendance.routeName);
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.n90,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(1000.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 13.w,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      languageProvider.getMessage(
                        "track_attendance",
                        "Track Attendance",
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.n0,
                          ),
                    ),
                    SizedBox(width: 8.w),
                    SvgPicture.asset(
                      AssetConstants.doubleArrowRight,
                      height: 10.h,
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
