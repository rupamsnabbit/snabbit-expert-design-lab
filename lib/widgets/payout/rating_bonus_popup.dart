import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

import '../../pages/payout/performance.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import 'good_shift_details_view.dart';

// Create a custom star rating widget
class StarRating extends StatelessWidget {
  final double rating;
  final Color activeColor;
  final Color inactiveColor;
  final double size;
  final double spacing;
  final int starCount;

  const StarRating({
    super.key,
    required this.rating,
    this.activeColor = const Color(0xFFFF9720),
    this.inactiveColor = const Color(0xFFF2F2F2),
    this.size = 26.5,
    this.spacing = 8.8,
    this.starCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (index) {
        // Calculate the fill amount for this star
        double fill = (rating - index).clamp(0.0, 1.0);

        return Row(
          children: [
            if (index > 0) SizedBox(width: spacing),
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: StarPainter(
                  fillPercent: fill,
                  fillColor: activeColor,
                  backgroundColor: inactiveColor,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// Custom painter to draw a star with partial filling
class StarPainter extends CustomPainter {
  final double fillPercent;
  final Color fillColor;
  final Color backgroundColor;

  StarPainter({
    required this.fillPercent,
    required this.fillColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Create a star path
    final Path starPath = _createStarPath(size);

    // Draw the background (unfilled) star
    canvas.drawPath(starPath, backgroundPaint);

    // If there's any filling to do
    if (fillPercent > 0) {
      // Create a clip path for the fill portion
      final clipPath = Path();
      clipPath
          .addRect(Rect.fromLTRB(0, 0, size.width * fillPercent, size.height));

      // Save the canvas state, clip it, draw the filled portion, then restore
      canvas.save();
      canvas.clipPath(clipPath);
      canvas.drawPath(starPath, fillPaint);
      canvas.restore();
    }
  }

  Path _createStarPath(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Calculate the outer and inner radii of the star
    final outerRadius = size.width / 2;
    // Use a larger inner radius for a rounder star shape
    final innerRadius = outerRadius * 0.5;

    // Start at the top point of the star
    const startAngle = -pi / 2;

    // Points of the star
    final points = <Offset>[];

    // Generate points for the star
    for (int i = 0; i < 5; i++) {
      final outerAngle = startAngle + i * 2 * pi / 5;
      final innerAngle = outerAngle + pi / 5;

      // Outer point
      points.add(Offset(centerX + outerRadius * cos(outerAngle),
          centerY + outerRadius * sin(outerAngle)));

      // Inner point
      points.add(Offset(centerX + innerRadius * cos(innerAngle),
          centerY + innerRadius * sin(innerAngle)));
    }

    // Move to the first point
    path.moveTo(points[0].dx, points[0].dy);

    // Create a smoother star by using quadratic bezier curves
    for (int i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];

      // Calculate control point for the curve
      // This creates a rounded corner between points
      final controlPoint = Offset(
          (current.dx + next.dx) / 2 + (next.dy - current.dy) * 0.1,
          (current.dy + next.dy) / 2 - (next.dx - current.dx) * 0.1);

      // Draw a quadratic bezier curve
      path.quadraticBezierTo(
          controlPoint.dx, controlPoint.dy, next.dx, next.dy);
    }

    // Close the path to complete the star
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(StarPainter oldDelegate) {
    return oldDelegate.fillPercent != fillPercent ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

void showRatingBonusDialog(BuildContext context) {
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
          child: const RatingBonusPopup(),
        ),
      );
    },
  );
}

class RatingBonusPopup extends StatefulWidget {
  const RatingBonusPopup({super.key});

  @override
  State<RatingBonusPopup> createState() => RatingBonusPopupState();
}

class RatingBonusPopupState extends State<RatingBonusPopup> {
  bool init = true;
  late LanguageProvider languageProvider;
  late PayoutProvider payoutProvider;
  String? asset;
  Color? color;
  DeductionData? _ratingDeduction;
  List<Map<String, dynamic>>? requirements;
  late CurrentPeriodProvider currentPeriodProvider;
  late UserProfileProvider userProfileProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      int index = payoutProvider.deductionDetails?.deductions?.items
              ?.indexWhere(
                  (element) => element.name == AppStrings.ratingDeduction) ??
          -1;
      if (index != -1) {
        _ratingDeduction =
            payoutProvider.deductionDetails?.deductions?.items?[index];
      }
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      // Parse achievement conditions from backend
      if (payoutProvider.incentives?.ratingsIncentives?.requirements != null) {
        try {
          requirements = List<Map<String, dynamic>>.from(payoutProvider
              .incentives!.ratingsIncentives!.requirements!
              .map((item) => Map<String, dynamic>.from(item as Map)));
        } catch (e) {
          // Fallback to null if parsing fails
          requirements = null;
        }
      } else {
        requirements = null;
      }
      setWidgetParams();
    }
    super.didChangeDependencies();
  }

  void setWidgetParams() {
    if (progress >= 1.0 && isAchieved == true) {
      asset = AssetConstants.fullyOpen;
      color = AppColors.g30;
    } else if (progress >= 0.75) {
      asset = AssetConstants.treasureChest75;
      color = const Color(0xFFFFD522);
    } else if (progress >= 0.5) {
      asset = AssetConstants.treasureChest0;
      color = const Color(0xffFF9720);
    } else if (progress >= 0.25) {
      asset = AssetConstants.treasureChest0;
      color = AppColors.r40;
    } else {
      asset = AssetConstants.treasureChest0;
      color = AppColors.n0;
    }
    if (hasViolations ||
        payoutProvider.incentives?.ratingsIncentives?.paymentState ==
            PaymentState.missed) {
      asset = AssetConstants.treasureChest0;
      if (hasViolations) {
        color = AppColors.n0.withOpacity(0.4);
      }
    }
  }

  double get target {
    // Get the attendance target from incentives if available
    return payoutProvider.incentives?.ratingsIncentives?.rewardTarget ?? 4.6;
  }

  bool? get isAchieved {
    // Get the attendance target from incentives if available
    return payoutProvider.incentives?.ratingsIncentives?.isAchieved;
  }

  bool get isPending {
    return _ratingDeduction?.status == DeductionState.success
        ? false
        : payoutProvider.incentives?.ratingsIncentives?.paymentState ==
            PaymentState.pending;
  }

  double get current {
    // Get current attendance from incentives if available
    // forcefully returning 0 in case its the first day of the month
    return isFirstDayOfMonth
        ? 0
        : payoutProvider.incentives?.ratingsIncentives?.avgRating ?? 0;
  }

  int get bonus {
    // Get max attendance bonus amount
    return payoutProvider.incentives?.ratingsIncentives?.maxReward ?? 0;
  }

  double get progress {
    try {
      return current / target;
    } catch (e) {
      return 0;
    }
  }

  double get deductionTarget {
    return _ratingDeduction?.deductionTarget ?? 4;
  }

  List<String> get absentWeekDays {
    return payoutProvider.incentives?.ratingsIncentives?.absentWeekDays ?? [];
  }

  String? get absentWeekDaysInText {
    return constructDaysSentence(
      absentWeekDays,
      languageProvider,
    );
  }

  int get absentDays =>
      payoutProvider.incentives?.attendanceIncentives?.absentDays ?? 0;

  bool get attendanceViolation =>
      absentDays >
      (payoutProvider.incentives?.attendanceIncentives?.maxAbsentDays ?? 0);

  bool get hasViolations =>
      absentWeekDays.isNotEmpty ||
      attendanceViolation ||
      payoutProvider.incentives?.ratingsIncentives?.paymentState ==
          PaymentState.missed;

  bool get isFirstDayOfMonth =>
      currentPeriodProvider.currentDate.day ==
      currentPeriodProvider.monthStartDate.day;

  ColorFilter get filter =>
      ColorFilter.matrix(isFirstDayOfMonth || hasViolations
          ? [
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]
          : [
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]);

  bool get showDeductionThreshold =>
      userProfileProvider
          .user?.runnerAppConfig?.payoutConfig?.showRatingDeductionThreshold ==
      true;

  bool get showRewardThreshold =>
      userProfileProvider
          .user?.runnerAppConfig?.payoutConfig?.showRatingIncentiveThreshold ==
      true;

  bool get showProRataMessage {
    return payoutProvider
            .incentives?.ratingsIncentives?.rateCardOrShiftChanges ==
        true;
  }

  LeaveDetails? get leaveDetails {
    return payoutProvider.incentives?.ratingsIncentives?.leaveDetails;
  }

  int get currentLeaveCount {
    return leaveDetails?.currentLeaveCount ?? 0;
  }

  int get maxLeaveAllowedCount {
    return leaveDetails?.maxLeaveAllowedCount ?? 0;
  }

  GoodShiftDetails? get goodShiftDetails {
    return payoutProvider
        .incentives?.ratingsIncentives?.goodShiftDetails;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350.r,
      height:
          (requirements != null && requirements!.isNotEmpty) ? 650.r : 416.r,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              hasViolations
                  ? AssetConstants.disabledBonusBg
                  : AssetConstants.performanceBonus,
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 24.h,
              bottom: 12.h,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  child: Text(
                    languageProvider.getMessage(
                        "performance_bonus", "Performance Bonus"),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: hasViolations
                            ? const Color(0xFF535353)
                            : AppColors.n0,
                        fontWeight: FontWeight.w800,
                        fontSize: 25.sp),
                  ),
                ),
                SizedBox(height: 11.h),
                if (progress >= 1.0 && isAchieved == true)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: FittedBox(
                      child: Text(
                        formatIndianCurrency(bonus),
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontSize: 37.sp,
                                  color: AppColors.n0,
                                ),
                      ),
                    ),
                  ),

                // Image - will shrink to accommodate the expanded container
                if (asset != null)
                  Image.asset(
                    asset!,
                    fit: BoxFit.contain,
                    // height: progress >= 1.0 && isAchieved == true ? 80.h : 122.h,
                    width: hasViolations ? 111.w : 121.w,
                  ),
                SizedBox(height: 7.h),

                // Progress container - will take as much space as needed
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: SizedBox(
                      width: 1.sw,
                      child: LayoutBuilder(builder: (context, size) {
                        return Column(
                          children: [
                            Flexible(
                              flex: hasViolations ? 1 : 63,
                              fit: isFirstDayOfMonth
                                  ? FlexFit.loose
                                  : FlexFit.tight,
                              child: ColorFiltered(
                                colorFilter: filter,
                                child: Container(
                                  padding: isFirstDayOfMonth
                                      ? EdgeInsets.fromLTRB(
                                          12.w, 15.h, 12.w, 30.h)
                                      : EdgeInsets.symmetric(
                                          vertical: 15.h,
                                          horizontal: 12.w,
                                        ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: const Alignment(-1.0, 0.035),
                                      // Approximates 93.2 degrees
                                      end: const Alignment(1.0, -0.035),
                                      colors: getTitleBackgroundGradient(),
                                      stops: const [0.0464, 0.9222],
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10.r),
                                      topRight: Radius.circular(10.r),
                                      bottomLeft: Radius.circular(
                                          isFirstDayOfMonth ? 10.r : 0),
                                      bottomRight: Radius.circular(
                                          isFirstDayOfMonth ? 10.r : 0),
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Stack(
                                                children: [
                                                  Container(
                                                    height: 21.h,
                                                    decoration:
                                                        const BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment
                                                            .centerLeft,
                                                        end: Alignment
                                                            .centerRight,
                                                        colors: [
                                                          Color.fromRGBO(
                                                              181, 61, 10, 0.0),
                                                          // Transparent start
                                                          Color(0xFFB53D0A),
                                                          // Solid color end
                                                        ],
                                                        stops: [0.0, 1.0],
                                                      ),
                                                    ),
                                                  ),
                                                  if (_ratingDeduction != null)
                                                    Positioned.fill(
                                                      right: 4.5,
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: Text(
                                                          "- ${formatIndianCurrency(_ratingDeduction?.amount)}",
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .displayLarge
                                                              ?.copyWith(
                                                                color: AppColors
                                                                    .n0,
                                                                fontSize: 8.sp,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              SizedBox(height: 2.h),
                                              LayoutBuilder(
                                                  builder: (context, size) {
                                                num areaToCover;
                                                num remainingSpace;
                                                if (current > deductionTarget) {
                                                  areaToCover = 1;
                                                  remainingSpace = 0;
                                                } else {
                                                  areaToCover = current / 4.29;
                                                  remainingSpace =
                                                      1 - areaToCover;
                                                }
                                                return SizedBox(
                                                  height: 24.h,
                                                  child: Center(
                                                    child: SizedBox(
                                                      height: 10.h,
                                                      child: Stack(
                                                        children: [
                                                          Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppColors
                                                                  .n0
                                                                  .withOpacity(
                                                                      0.4),
                                                              borderRadius: BorderRadius
                                                                  .horizontal(
                                                                      left: Radius
                                                                          .circular(
                                                                              1000.r)),
                                                            ),
                                                          ),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                flex:
                                                                    (areaToCover *
                                                                            100)
                                                                        .ceil(),
                                                                child: Stack(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  clipBehavior:
                                                                      Clip.none,
                                                                  children: [
                                                                    Container(
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        borderRadius:
                                                                            BorderRadius.horizontal(left: Radius.circular(1000.r)),
                                                                        color: const Color(
                                                                            0xffC50F1F),
                                                                      ),
                                                                    ),
                                                                    if (!isFirstDayOfMonth &&
                                                                        current <
                                                                            deductionTarget)
                                                                      Positioned(
                                                                        right:
                                                                            -4,
                                                                        child: SvgPicture
                                                                            .asset(
                                                                          AssetConstants
                                                                              .poorRating,
                                                                          height:
                                                                              24.h,
                                                                          clipBehavior:
                                                                              Clip.none,
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex:
                                                                    (remainingSpace *
                                                                            100)
                                                                        .ceil(),
                                                                child:
                                                                    Container(),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 3.w),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              SizedBox(height: 2.h),
                                              LayoutBuilder(
                                                  builder: (context, size) {
                                                num areaToCover;
                                                num remainingSpace;

                                                if (current >= target) {
                                                  areaToCover = 1;
                                                  remainingSpace = 0;
                                                } else if (current <
                                                    deductionTarget) {
                                                  areaToCover = 0;
                                                  remainingSpace = 1;
                                                } else {
                                                  areaToCover = (current -
                                                          deductionTarget) /
                                                      (target -
                                                          deductionTarget);
                                                  remainingSpace =
                                                      1 - areaToCover;
                                                }
                                                return Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    SizedBox(
                                                      height: 24.h,
                                                      child: Center(
                                                        child: SizedBox(
                                                          height: 10.h,
                                                          child: Stack(
                                                            children: [
                                                              Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: AppColors
                                                                      .n0
                                                                      .withOpacity(
                                                                          0.4),
                                                                ),
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    flex: (areaToCover *
                                                                            100)
                                                                        .ceil(),
                                                                    child:
                                                                        Stack(
                                                                      alignment:
                                                                          Alignment
                                                                              .center,
                                                                      clipBehavior:
                                                                          Clip.none,
                                                                      children: [
                                                                        Container(
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color: hasViolations
                                                                                ? Colors.grey.shade800
                                                                                : Color(0xffEFB700),
                                                                          ),
                                                                        ),
                                                                        if (current >=
                                                                                deductionTarget &&
                                                                            current <
                                                                                target)
                                                                          Positioned(
                                                                            right:
                                                                                -4,
                                                                            child:
                                                                                SvgPicture.asset(
                                                                              AssetConstants.happyFace,
                                                                              height: 24.h,
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                    flex: (remainingSpace *
                                                                            100)
                                                                        .ceil(),
                                                                    child:
                                                                        Container(),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (showDeductionThreshold &&
                                                        !hasViolations)
                                                      Positioned(
                                                        left: -13,
                                                        bottom: -16,
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                              deductionTarget
                                                                  .toString(),
                                                              textScaler:
                                                                  TextScaler
                                                                      .noScaling,
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        getRatingMilestoneColor(),
                                                                  ),
                                                            ),
                                                            Icon(
                                                              Icons.star,
                                                              size: 10.sp,
                                                              color:
                                                                  getRatingMilestoneColor(),
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                    if (showRewardThreshold &&
                                                        !hasViolations)
                                                      Positioned(
                                                        right: -22,
                                                        bottom: -16,
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                              target.toString(),
                                                              textScaler:
                                                                  TextScaler
                                                                      .noScaling,
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        getRatingMilestoneColor(),
                                                                  ),
                                                            ),
                                                            Icon(
                                                              Icons.star,
                                                              size: 10.sp,
                                                              color:
                                                                  getRatingMilestoneColor(),
                                                            )
                                                          ],
                                                        ),
                                                      )
                                                  ],
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 3.w),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Stack(
                                                children: [
                                                  Container(
                                                    height: 21.h,
                                                    decoration:
                                                        const BoxDecoration(
                                                      gradient: LinearGradient(
                                                        end: Alignment
                                                            .centerRight,
                                                        // 270deg: right to left
                                                        begin: Alignment
                                                            .centerLeft,
                                                        colors: [
                                                          Color(0xFF1F4614),
                                                          // Solid green
                                                          Color.fromRGBO(
                                                              31, 70, 20, 0.0),
                                                          // Transparent
                                                        ],
                                                        stops: [
                                                          0.05,
                                                          0.9333
                                                        ], // Equivalent to 5% and 93.33%
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned.fill(
                                                    left: 4.5,
                                                    child: Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text(
                                                        "+ ${formatIndianCurrency(bonus)}",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .displayLarge
                                                            ?.copyWith(
                                                              color:
                                                                  AppColors.n0,
                                                              fontSize: 8.sp,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 2.h),
                                              LayoutBuilder(
                                                  builder: (context, size) {
                                                num areaToCover;
                                                num remainingSpace;
                                                if (current >= target) {
                                                  areaToCover = (current -
                                                          (target - 0.01)) /
                                                      (5 - (target - 0.01));
                                                  remainingSpace =
                                                      1 - areaToCover;
                                                } else {
                                                  areaToCover = 0;
                                                  remainingSpace = 1;
                                                }
                                                return SizedBox(
                                                  height: 24.h,
                                                  child: Stack(
                                                    children: [
                                                      Center(
                                                        child: SizedBox(
                                                          height: 10.h,
                                                          child: Stack(
                                                            children: [
                                                              Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius.horizontal(
                                                                          right:
                                                                              Radius.circular(1000.r)),
                                                                  color: AppColors
                                                                      .n0
                                                                      .withOpacity(
                                                                          0.4),
                                                                ),
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    flex: (areaToCover *
                                                                            100)
                                                                        .ceil(),
                                                                    child:
                                                                        Stack(
                                                                      clipBehavior:
                                                                          Clip.none,
                                                                      alignment:
                                                                          Alignment
                                                                              .center,
                                                                      children: [
                                                                        Container(
                                                                          decoration:
                                                                              const BoxDecoration(
                                                                            color:
                                                                                Color(0xff1F4614),
                                                                          ),
                                                                        ),
                                                                        if (current >=
                                                                            target)
                                                                          Positioned(
                                                                            right:
                                                                                -4,
                                                                            child:
                                                                                SvgPicture.asset(
                                                                              isAchieved == true ? AssetConstants.partyFace : AssetConstants.happyFace,
                                                                              height: 24.h,
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                    flex: (remainingSpace *
                                                                            100)
                                                                        .ceil(),
                                                                    child:
                                                                        Container(),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!isFirstDayOfMonth)
                              Expanded(
                                flex: hasViolations ? 1 : 37,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: getSubtitleBackgroundColor(),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(10.r),
                                      bottomRight: Radius.circular(10.r),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ColorFiltered(
                                        colorFilter: filter,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              "${DateFormat('MMMM').format(currentPeriodProvider.monthStartDate)} Rating:",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displaySmall
                                                  ?.copyWith(
                                                    color: AppColors.n0
                                                        .withOpacity(0.8),
                                                  ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 4.w),
                                              child: Text(
                                                current.toString(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineLarge
                                                    ?.copyWith(
                                                        color: AppColors.n0,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 21.5.sp),
                                              ),
                                            ),
                                            SvgPicture.asset(
                                              AssetConstants.circleStar,
                                              height: 18.h,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          if (attendanceViolation)
                                            Text(
                                              languageProvider.getFormattedMessage(
                                                  "x_days_absent",
                                                  "{{absent_count}} days absent",
                                                  {
                                                    'absent_count': absentDays,
                                                  }),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displaySmall
                                                  ?.copyWith(
                                                    color:
                                                        const Color(0xFFFF0000),
                                                  ),
                                            ),
                                          if (attendanceViolation &&
                                              absentWeekDays.isNotEmpty)
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
                                          if (absentWeekDays.isNotEmpty)
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
                                                      text:
                                                          "${languageProvider.getMessage(
                                                        "absent_on",
                                                        "Absent on",
                                                      )}${attendanceViolation ? '\n' : ' '}",
                                                      style: (attendanceViolation
                                                              ? Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall
                                                              : Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .displaySmall)
                                                          ?.copyWith(
                                                              color: const Color(
                                                                  0xFFFF0000),
                                                              fontWeight:
                                                                  attendanceViolation
                                                                      ? FontWeight
                                                                          .w500
                                                                      : FontWeight
                                                                          .w700),
                                                    ),
                                                    TextSpan(
                                                      text:
                                                          absentWeekDaysInText,
                                                    ),
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                SizedBox(height: 13.h),

                if (leaveDetails != null)
                  Container(
                    margin:
                        EdgeInsets.only(left: 14.h, right: 14.h, bottom: 14.h),
                    padding: EdgeInsets.all(12.r),
                    width: 1.sw,
                    decoration: BoxDecoration(
                      color: Color(0xff0C2B4E99).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      languageProvider.getFormattedMessage(
                        "leave_details_rating_bonus",
                        "Leaves taken : {{leaves_taken}} / {{leaves_allowed}}",
                        {
                          'leaves_taken': currentLeaveCount ?? 0,
                          'leaves_allowed': maxLeaveAllowedCount ?? 0,
                        },
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.n0,
                          ),
                    ),
                  ),

                GoodShiftDetailsView(goodShiftDetails: goodShiftDetails,),

                // Achievement conditions section
                if (requirements != null && requirements?.isNotEmpty == true)
                  Container(
                    margin:
                        EdgeInsets.only(left: 14.h, right: 14.h, bottom: 14.h),
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Color(0xff0C2B4E99).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12.h),
                        ...?requirements?.map(
                          (requirement) => Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 0.7.sw),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      languageProvider.getFormattedMessage(
                                        requirement['key']?.toString() ?? '',
                                        requirement['text']?.toString() ?? '',
                                        (requirement['data'] as Map?)
                                                ?.cast<String, dynamic>() ??
                                            {},
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            height: 1.4,
                                            fontSize: 14.sp,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showProRataMessage)
                          Padding(
                            padding: EdgeInsets.only(
                              left: 44.w,
                              right: 44.w,
                            ),
                            child: Text(
                              languageProvider.getMessage(
                                  "rate_card_or_shift_changes_message",
                                  "Goal updated because of mid-month rate card change"),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    color: AppColors.n40,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),

                isAchieved != true
                    ? OutlinedButton(
                        onPressed: () {
                          // Navigator.of(context).pushNamed(Performance.routeName);
                          showModalBottomSheet(
                              context: context,
                              builder: (_) {
                                return CommonBottomSheetSetup(
                                  child: RatingImprovementTips(
                                    languageProvider: languageProvider,
                                  ),
                                );
                              });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xff0C2B4E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(1000.r),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 13.w,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                languageProvider.getMessage(
                                  "improve_ratings",
                                  "Improve ratings",
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: AppColors.n0,
                                    ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            SvgPicture.asset(
                              AssetConstants.doubleArrowRight,
                              height: 10.h,
                            )
                          ],
                        ),
                      )
                    : FittedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              AssetConstants.partyPopper,
                              width: 22.r,
                            ),
                            Text(
                              "Congratulations! Bonus Unlocked",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontSize: 16.sp,
                                    color: AppColors.n0,
                                  ),
                            )
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color getSubtitleBackgroundColor() {
    if (hasViolations) {
      return const Color(0xFF262626);
    } else if (current < deductionTarget) {
      return const Color(0xFFB53D0A);
    } else if (current < target) {
      return const Color(0xFFBE9200);
    } else {
      return const Color(0xFF1F4614);
    }
  }

  List<Color> getTitleBackgroundGradient() {
    // if(isDisabled) {
    //   return const [
    //     Color(0xFFCACACA5),
    //     Color(0xFFB1B1B1),
    //   ];
    // } else
    if (current < deductionTarget) {
      return const [
        Color(0xFFDC8955),
        Color(0xFFFF9020),
      ];
    } else if (current < target) {
      return const [
        Color(0xFFA1A108),
        Color(0xFFFFE17D),
      ];
    } else {
      return const [
        Color(0xFF6AB269),
        Color(0xFF68C965),
      ];
    }
  }

  Color getRatingMessageBackgroundColor() {
    if (current < deductionTarget) {
      return const Color(0xFF59220B);
    } else if (current < target) {
      return const Color(0xFF775B00);
    } else {
      return const Color(0xFF103904);
    }
  }

  Color getRatingMilestoneColor() {
    if (hasViolations) {
      return const Color(0xFF494848);
    } else if (current < deductionTarget) {
      return const Color(0xFF6D2303);
    } else if (current < target) {
      return const Color(0xFF675503);
    } else {
      return const Color(0xFF1B460F);
    }
  }

  Widget getRatingMessage() {
    if (isPending) {
      return Text(
        "Bonus unlocks at $target",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 11.sp,
              color: AppColors.n0,
            ),
      );
    }
    if (current < deductionTarget) {
      return Text(
        "Penalty below rating $deductionTarget",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 11.sp,
              color: AppColors.n0,
            ),
      );
    } else if (current < target) {
      return Text(
        "Bonus unlocks at $target",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 11.sp,
              color: AppColors.n0,
            ),
      );
    } else {
      if (isAchieved == true) {
        return Row(
          children: [
            SvgPicture.asset(
              AssetConstants.partyPopper,
              width: 22.r,
            ),
            Text(
              "Congratulations! Bonus Unlocked",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.n0,
                  ),
            )
          ],
        );
      } else {
        return Text(
          "Bonus unlocks at $target",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 11.sp,
                color: AppColors.n0,
              ),
        );
      }
    }
  }
}

class RatingImprovementTips extends StatelessWidget {
  final LanguageProvider languageProvider;

  // Define a list of tip message keys and their default values
  static const List<String> tipsList = [
    "be_on_time",
    "wear_uniform",
    "good_behavior",
  ];

  const RatingImprovementTips({
    super.key,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 34.h),
        Image.asset(
          AssetConstants.ratingImproveIcon,
          height: 94.h,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),
        SizedBox(height: 16.h),
        // Title
        Text(
          languageProvider.getMessage(
            "how_to_improve_ratings",
            "How to improve ratings",
          ),
          style: Theme.of(context).textTheme.headlineMedium,
        ),

        SizedBox(height: 24.h),

        // Tips list - generated using map
        ...tipsList.map(
          (tip) => _buildTipItem(
            context,
            languageProvider.getMessage(tip, tip),
          ),
        ),

        SizedBox(height: 28.h),

        // Buttons section remains the same
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.g40,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              languageProvider.getMessage("got_it", "Got it"),
            ),
          ),
        ),

        SizedBox(height: 8.h),

        // Secondary button
        SizedBox(
          width: 1.sw,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pushNamed(Performance.routeName);
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 11.h),
              side: const BorderSide(
                color: AppColors.n50,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_border,
                  size: 20.sp,
                  color: AppColors.n80, // Neutral 80
                ),
                SizedBox(width: 4.w),
                Text(
                  languageProvider.getMessage(
                    "view_ratings",
                    "View ratings",
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.n80),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildTipItem(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check,
            size: 20.r,
            color: const Color(0xFF525871), // Neutral 80
          ),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16.sp,
              letterSpacing: -0.24,
              color: const Color(0xFF525871), // Neutral 80
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
