import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/payout/custom_progress_bar.dart';

import '../../constants/assets_constants.dart';
import '../../utils/colors.dart';

// JackpotData model
class JackpotData {
  final int? targetDays;
  final int? totalDays;
  final double? targetRating;
  final int? currentDays;
  final double? progress;
  final PaymentState? status;
  final bool? showJackpot;
  final bool? attendanceWarning;
  final bool? ratingWarning;
  final int? jackpotAmount;

  JackpotData({
    this.targetDays,
    this.totalDays,
    this.targetRating,
    this.currentDays,
    this.progress,
    this.status,
    this.showJackpot,
    this.attendanceWarning,
    this.ratingWarning,
    this.jackpotAmount,
  });

  factory JackpotData.fromJson(Map<String, dynamic> json) {
    return JackpotData(
      targetDays: anyValueToInt(json['target_days']),
      totalDays: anyValueToInt(json['total_days']),
      targetRating: json['target_rating'] != null
          ? (json['target_rating'] as num).toDouble()
          : null,
      currentDays: anyValueToInt(json['current_days']),
      progress: json['progress'] != null
          ? (json['progress'] as num).toDouble()
          : null,
      status: PaymentState.fromString(json['status']),
      showJackpot: json['show_jackpot'],
      attendanceWarning: json['attendance_warning'],
      ratingWarning: json['rating_warning'],
      jackpotAmount: anyValueToInt(json['jackpot_amount']),
    );
  }
}

// JackpotHttp service
class JackpotHttp {
  static Future<JackpotData?> getJackpotData({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/payouts/me/jackpot"),
        headers: headers ?? {},
      );

      //  revert below line
      if (response.statusCode == 200) {
        // if (true) {
        //  revert below line
        final Map<String, dynamic> data = response.data;
        // Sample response data for development/testing
        // final Map<String, dynamic> data = {
        //   'target_days': 60,
        //   'total_days': 70,
        //   'target_rating': 4.6,
        //   'current_days': 25,
        //   'progress': 0.42,
        //   'status':
        //       'EARNED', // Add 'EARNED', 'PENDING', or 'MISSED' for testing
        // };
        return JackpotData.fromJson(data);
      } else {
        // print('Failed to load jackpot data: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // print('Error fetching jackpot data: $e');
      return null;
    }
  }
}

// Jackpot Widget
class Jackpot extends StatefulWidget {
  const Jackpot({super.key});

  @override
  State<Jackpot> createState() => _JackpotState();
}

class _JackpotState extends State<Jackpot> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  JackpotData? jackpotData;

  // Define colors based on the CSS
  final Color missedBackgroundColor = const Color(0xFF929292);
  final Color missedTextColor = const Color(0xFF4B4848);
  final Color missedDottedLineColor = const Color(0xFFCECECE);
  final Color missedProgressColor = const Color(0xFF4B4848);
  final Color missedProgressBgColor = const Color(0xFFCECECE);

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    try {
      jackpotData = await JackpotHttp.getJackpotData();
    } catch (e) {
      // Handle error - maybe show a snackbar or error state
      // print('Error loading jackpot data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return SizedBox if loading is false but jackpotData is null
    if ((!loading && jackpotData == null) ||
        jackpotData?.showJackpot == null ||
        jackpotData?.showJackpot == false) {
      return const SizedBox();
    }

    // Check if status is missed
    final bool isMissed = jackpotData?.status == PaymentState.missed;
    final bool isAchieved = jackpotData?.status == PaymentState.earned;

    if (isAchieved) {
      return Container(
        width: 1.sw,
        padding: EdgeInsets.only(bottom: 24.h),
        child: Stack(
          children: [
            Image.asset(
              AssetConstants.jackpotAchieved,
              // height: 81.h,
            ),
            Positioned.fill(
              right: 33.w,
              child: Align(
                alignment: Alignment.topRight,
                child: FittedBox(
                  child: Text(
                    formatIndianCurrency(jackpotData?.jackpotAmount),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.n0,
                        ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    flex: 80,
                    child: Padding(
                      padding: EdgeInsets.only(left: 28.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            languageProvider.getMessage(
                              'you_hit_jackpot',
                              'YOU HIT JACKPOT',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: Colors.black),
                          ),
                          Text(
                            languageProvider.getMessage(
                              'congratulations_capital',
                              'CONGRATULATIONS.',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18.sp),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 20,
                    child: SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      // height: 81.h,
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: isMissed ? missedBackgroundColor : Colors.black,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
            color: isMissed
                ? missedBackgroundColor
                : jackpotData?.attendanceWarning == true ||
                        jackpotData?.ratingWarning == true
                    ? AppColors.r40
                    : const Color(0xffD4AF37),
            width: 2.r),
        boxShadow: isMissed
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  offset: Offset(0, 0.63.h),
                  blurRadius: 0.63.r,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  offset: Offset(0.63.w, 0.63.h),
                  blurRadius: 0.63.r,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: Offset(0.31.w, 0.94.h),
                  blurRadius: 0.94.r,
                )
              ]
            : null,
      ),
      child: loading
          ? const Center(child: CupertinoActivityIndicator())
          : Row(
              children: [
                Expanded(
                  flex: 65,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 14.w,
                      top: 10.h,
                      bottom: 10.h,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.hourglass_bottom_rounded,
                              color: isMissed
                                  ? missedTextColor
                                  : jackpotData?.attendanceWarning == true
                                      ? AppColors.r40
                                      : AppColors.n0,
                              size: 16.sp,
                            ),
                            Text(
                              languageProvider.getFormattedMessage(
                                'maintain_jackpot_attendance',
                                'ATTEND {{target_days}} DAYS IN {{total_days}} DAYS',
                                {
                                  'target_days': jackpotData?.targetDays ?? 0,
                                  'total_days': jackpotData?.totalDays ?? 0,
                                },
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: isMissed
                                        ? missedTextColor
                                        : jackpotData?.attendanceWarning == true
                                            ? AppColors.r40
                                            : AppColors.n0,
                                    letterSpacing: 1.r,
                                  ),
                            ),
                          ],
                        ),
                        if (jackpotData?.targetRating != null)
                          Padding(
                            padding: EdgeInsets.only(
                              right: 55.w,
                              top: 6.h,
                              bottom: 6.h,
                            ),
                            child: DottedLine(
                              lineThickness: 2.h,
                              dashLength: 5.w,
                              dashColor: isMissed
                                  ? missedDottedLineColor
                                  : const Color(0xffD4AF37),
                            ),
                          ),
                        if (jackpotData?.targetRating != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.star_outline_rounded,
                                color: isMissed
                                    ? missedTextColor
                                    : jackpotData?.ratingWarning == true
                                        ? AppColors.r40
                                        : AppColors.n0,
                                size: 16.sp,
                              ),
                              Text(
                                languageProvider.getFormattedMessage(
                                  'maintain_jackpot_rating',
                                  'MAINTAIN {{target_rating}}+ RATING',
                                  {
                                    'target_rating':
                                        jackpotData?.targetRating ?? 0.0,
                                  },
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: isMissed
                                          ? missedTextColor
                                          : jackpotData?.ratingWarning == true
                                              ? AppColors.r40
                                              : AppColors.n0,
                                      letterSpacing: 1.r,
                                    ),
                              ),
                            ],
                          ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        "${jackpotData?.currentDays ?? 0}/${jackpotData?.targetDays ?? 0} ",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: isMissed
                                              ? missedTextColor
                                              : AppColors.n0,
                                          letterSpacing: 1.r,
                                        ),
                                  ),
                                  TextSpan(
                                    text: languageProvider.getMessage(
                                      'days_capital',
                                      'DAYS',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: isMissed
                                              ? missedTextColor
                                              : AppColors.n0,
                                          fontSize: 7.sp,
                                          letterSpacing: 1.r,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: isMissed
                                  ? CustomProgressBar(
                                      progress: jackpotData?.progress ?? 0.0,
                                      lockPosition: 0,
                                      addEndCircle: false,
                                      addMileStoneLock: false,
                                      color: missedProgressColor,
                                    )
                                  : CustomProgressBar(
                                      progress: jackpotData?.progress ?? 0.0,
                                      lockPosition: 0,
                                      addEndCircle: false,
                                      addMileStoneLock: false,
                                      color: jackpotData?.attendanceWarning ==
                                                  true ||
                                              jackpotData?.ratingWarning == true
                                          ? AppColors.r40
                                          : const Color(0xffD4AF37),
                                    ),
                            ),
                            SizedBox(width: 12.w),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 35,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: ColorFiltered(
                      colorFilter: isMissed
                          ? const ColorFilter.mode(
                              Color(0xFFBBBBBB), BlendMode.modulate)
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.srcOver),
                      child: Stack(
                        children: [
                          Image.asset(AssetConstants.jackpot),
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: FittedBox(
                                child: Text(
                                  formatIndianCurrency(
                                      jackpotData?.jackpotAmount),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.n0,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
