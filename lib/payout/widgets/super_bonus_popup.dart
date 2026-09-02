import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/constants.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/payout/good_shift_details_view.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../utils/colors.dart';

void showSuperBonusDialog(BuildContext context) {
  final payoutProvider = Provider.of<PayoutProvider>(context, listen: false);

  showDialog(
    context: context,
    builder: (_) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        backgroundColor:
            payoutProvider.incentives?.superBonus?.isAchievedOrPending == true
                ? Color(0xff4F300F)
                : Color(0xff2F2E2E),
        insetPadding: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.none,
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
          child: const SuperBonusPopup(),
        ),
      );
    },
  );
}

class SuperBonusPopup extends StatefulWidget {
  const SuperBonusPopup({super.key});

  @override
  State<SuperBonusPopup> createState() => SuperBonusPopupState();
}

class SuperBonusPopupState extends State<SuperBonusPopup> {
  bool init = true;
  late LanguageProvider languageProvider;
  late PayoutProvider payoutProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  String? assetBase = 'payouts/incentives/super_bonus';

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: false);
    }
    super.didChangeDependencies();
  }

  SuperBonus? get bonus {
    return payoutProvider.incentives?.superBonus;
  }

  int? get unfilledFlex {
    try {
      return bonus!.lastTarget!.target! - bonus!.achievedValue!;
    } catch (_) {
      return null;
    }
  }

  double get widthBase {
    try {
      return bonus!.lastTarget!.target! * 1.0;
    } catch (_) {
      return 0;
    }
  }

  Widget get subtitle {
    try {
      final isAchieved = bonus?.isAchieved == true;
      final nearestPending = bonus?.nearestPendingTarget;
      if (bonus?.minRating != null &&
          bonus?.currentRating != null &&
          bonus!.minRating! > bonus!.currentRating!) {
        int? sum;
        try {
          sum = bonus?.targets
              ?.where((e) => bonus!.achievedValue! >= e.target!)
              .fold(
                  0,
                  (previous, element) =>
                      (previous ?? 0) + (element.amount ?? 0));
        } catch (_) {
          sum = null;
        }
        if ((sum ?? 0) > 0) {
          return Align(
            alignment: Alignment.center,
            child: CustomText(
              textData: {
                "key": "sb_improve_rating",
                "text":
                    "Improve rating above {{sb_min_rating}} to earn {{sb_amount}}",
                "style": {"name": "displaySmall", "color": "#FFFFFF"},
                "data": [
                  {
                    "key": "sb_min_rating",
                    "text": "${bonus?.minRating}",
                  },
                  {
                    "key": "sb_amount",
                    "text": formatIndianCurrency(sum),
                    "style": {"name": "displaySmall", "color": "#CC9200"},
                  },
                ],
              },
            ),
          );
        }
      }
      if (!isAchieved && nearestPending != null) {
        return Align(
          alignment: Alignment.center,
          child: CustomText(
            textData: {
              "key": "work_x_hours_to_earn_y",
              "text": "Work {{sbt_hours}} more hours to earn {{sbt_amount}}",
              "style": {"name": "displaySmall", "color": "#FFFFFF"},
              "data": [
                {
                  "key": "sbt_hours",
                  "text":
                      "${(bonus?.totalValue ?? 0) - (bonus?.achievedValue ?? 0)}",
                },
                {
                  "key": "sbt_amount",
                  "text": formatIndianCurrency(bonus?.targetAmount),
                  "style": {"name": "displaySmall", "color": "#CC9200"},
                },
              ],
            },
          ),
        );
      } else if (isAchieved && nearestPending != null) {
        return Align(
          alignment: Alignment.center,
          child: CustomText(
            textData: {
              "key": "work_x_hours_to_earn_more_y",
              "text":
                  "Work {{sbt_hours}} more hours to earn extra {{sbt_amount}}",
              "style": {"name": "displaySmall", "color": "#FFFFFF"},
              "data": [
                {
                  "key": "sbt_hours",
                  "text":
                      "${(bonus?.totalValue ?? 0) - (bonus?.achievedValue ?? 0)}",
                },
                {
                  "key": "sbt_amount",
                  "text": formatIndianCurrency(bonus?.targetAmount),
                  "style": {"name": "displaySmall", "color": "#CC9200"},
                },
              ],
            },
          ),
        );
      } else if (isAchieved && nearestPending == null) {
        bool isUnlocked = false;
        try {
          isUnlocked = bonus?.targets
                  ?.firstWhere((e) => e.paymentState == PaymentState.pending) !=
              null;
        } catch (_) {
          isUnlocked = false;
        }
        if (isUnlocked) {
          return Align(
            alignment: Alignment.center,
            child: CustomText(
              textData: {
                "key": "congrats_super_bonus_unlocked",
                "text": "Congrats, you've unlocked full bonus",
                "style": {"name": "displaySmall", "color": "#FFFFFF"},
              },
            ),
          );
        } else {
          return Align(
            alignment: Alignment.center,
            child: CustomText(
              textData: {
                "key": "congrats_super_bonus_earned",
                "text": "Congrats, you've earned {{sb_amount_earned}}",
                "style": {"name": "displaySmall", "color": "#FFFFFF"},
                "data": [
                  {
                    "key": "sb_amount_earned",
                    "text": formatIndianCurrency(bonus?.amount),
                    "style": {"name": "displaySmall", "color": "#CC9200"},
                  },
                ],
              },
            ),
          );
        }
      }
      return SizedBox.shrink();
    } catch (_) {
      return SizedBox.shrink();
    }
  }

  bool get showProRataMessage {
    return bonus?.rateCardOrShiftChanges == true;
  }

  GoodShiftDetails? get goodShiftDetails {
    return bonus?.goodShiftDetails;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RemoteImageHandler(
            imageUrl: bonus?.isAchievedOrPending == true
                ? "$assetBase/non_failed.png".cdn
                : "$assetBase/failed.png".cdn,
            width: 350.r,
            fit: BoxFit.cover,
          ),
        ),
        Container(
          width: 350.r,
          constraints: BoxConstraints(minHeight: 416.r, maxHeight: 0.8.sh),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
          ),
          padding: EdgeInsets.only(
            top: 24.h,
            bottom: 16.h,
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    languageProvider.getMessage("super_bonus", "Super Bonus"),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppColors.n0,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  SizedBox(height: 12.h),

                  // Image - will shrink to accommodate the expanded container
                  RemoteImageHandler(
                    imageUrl: bonus?.isAchievedOrPending == true
                        ? "$assetBase/non_failed_icon.png".cdn
                        : "$assetBase/failed_icon.png".cdn,
                    fit: BoxFit.contain,
                    height: 145.h,
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
                          vertical: 23.h,
                          horizontal: 28.w,
                        ),
                        decoration: BoxDecoration(
                          color: bonus?.isAchievedOrPending == true
                              ? const Color(0xFF321B01)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          "${bonus?.achievedValue}/${bonus?.totalValue} ",
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge
                                          ?.copyWith(color: AppColors.n0),
                                    ),
                                    TextSpan(
                                      text: languageProvider.getMessage(
                                          'hours', 'Hours'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(color: AppColors.n0),
                                    ),
                                  ],
                                ),
                              ),
                              LayoutBuilder(builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Container(
                                      height: 10.h,
                                      width: 1.sw,
                                      decoration: BoxDecoration(
                                        color:
                                            bonus?.isAchievedOrPending == true
                                                ? Color(0xff4E300E)
                                                : Color(0xFF2E2E2E),
                                        borderRadius:
                                            BorderRadius.circular(1000),
                                      ),
                                    ),
                                    if (bonus?.achievedValue != null &&
                                        unfilledFlex != null)
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: bonus!.achievedValue!,
                                            child: Container(
                                              height: 10.h,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors:
                                                      bonus?.isAchievedOrPending ==
                                                              true
                                                          ? [
                                                              Color(0xFFBA7311),
                                                              Color(0xFFE0AC00),
                                                            ]
                                                          : [
                                                              Color(0xFF666666),
                                                              Color(0xFF707070),
                                                            ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(1000),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: unfilledFlex!,
                                            child: SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    ...bonus?.targets?.map((e) {
                                          return Transform.translate(
                                            offset: Offset(
                                                widthBase > 0
                                                    ? (width *
                                                            (e.target ?? 0) /
                                                            widthBase) -
                                                        20.r
                                                    : 0,
                                                0),
                                            child: TargetView(
                                                target: e,
                                                endDate: bonus?.endDate ??
                                                    DateTime.now()),
                                          );
                                        }).toList() ??
                                        [],
                                  ],
                                );
                              }),
                              SizedBox(height: 24.h),
                              subtitle,
                              if (showProRataMessage)
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: 8.h, left: 30.w, right: 30.w),
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
                      ),
                    ),
                  ),

                  GoodShiftDetailsView(goodShiftDetails: goodShiftDetails,),

                  if (bonus?.minRating != null)
                    Padding(
                      padding: EdgeInsets.only(top: 16.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${languageProvider.getMessage('minimum_rating_required', 'Minimum rating required')}: ${bonus?.minRating} ",
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.n0),
                          ),
                          RemoteImageHandler(
                            imageUrl: "$assetBase/star.svg".cdn,
                            height: 14.h,
                          ),
                        ],
                      ),
                    ),
                  if (bonus?.currentRating != null)
                    Padding(
                      padding: EdgeInsets.only(top: 12.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${languageProvider.getMessage('current_rating', 'Current rating')}: ${bonus?.currentRating} ",
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: (bonus?.currentRating ?? 0) <
                                            (bonus?.minRating ?? 0)
                                        ? AppColors.r40
                                        : AppColors.n0),
                          ),
                          RemoteImageHandler(
                            imageUrl: "$assetBase/star.svg".cdn,
                            height: 14.h,
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 18.h),
                  if (bonus?.endDate != null &&
                      bonus?.paymentState == PaymentState.pending)
                    Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 5.h, horizontal: 11.w),
                      decoration: BoxDecoration(
                          color: Color(0xff321B01),
                          borderRadius: BorderRadius.circular(5.r)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: Color(0xffCBAF7C),
                            size: 18.sp,
                          ),
                          SizedBox(width: 4.w),
                          if (bonus?.expiryType == ExpiryType.days)
                            Text(
                              languageProvider.getFormattedMessage(
                                'super_bonus_ends_in',
                                'Ends in {{end_days}} days',
                                {
                                  'end_days': bonus!.endDate!
                                      .difference(DateTime.now())
                                      .inDays
                                },
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      color: Color(0xffCBAF7C),
                                      fontWeight: FontWeight.w700),
                            )
                          else
                            Text(
                              languageProvider.getFormattedMessage(
                                'super_bonus_ends_on',
                                'Ends on {{end_date}}',
                                {
                                  'end_date':
                                      dateFormatVisual6.format(bonus!.endDate!)
                                },
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      color: Color(0xffCBAF7C),
                                      fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    )
                  else if (bonus?.paymentDate != null &&
                      bonus?.isAchieved == true)
                    Container(
                      width: 1.sw,
                      margin: EdgeInsets.symmetric(horizontal: 14.w),
                      padding: EdgeInsets.symmetric(vertical: 5.h),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(0xffCC9200),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      child: Text(
                        currentPeriodProvider.monthEndDate
                                    .isBefore(bonus!.paymentDate!) &&
                                bonus!.paymentDate!.isBefore(DateTime.now())
                            ? languageProvider.getFormattedMessage(
                                'super_bonus_paid_on', 'Paid on {{date}}', {
                                'date': dateFormatVisual6
                                    .format(bonus!.paymentDate!)
                              })
                            : languageProvider.getFormattedMessage(
                                'super_bonus_to_be_paid_on',
                                'To be paid on {{date}}', {
                                'date': dateFormatVisual6
                                    .format(bonus!.paymentDate!)
                              }),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Color(0xff321B01),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (bonus?.endDate != null &&
                      bonus?.isAchievedOrPending != true)
                    Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 5.h, horizontal: 11.w),
                      decoration: BoxDecoration(
                          color: Color(0xff1A1A1A),
                          borderRadius: BorderRadius.circular(5.r)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: Color(0xffA4A4A4),
                            size: 18.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            languageProvider.getFormattedMessage(
                              'super_bonus_ended_on',
                              'Ended on {{end_date}}',
                              {
                                'end_date':
                                    dateFormatVisual6.format(bonus!.endDate!)
                              },
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    color: Color(0xffA4A4A4),
                                    fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TargetView extends StatelessWidget {
  final SuperBonusTarget target;
  final DateTime endDate;

  const TargetView({
    super.key,
    required this.target,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final payoutProvider = Provider.of<PayoutProvider>(context, listen: false);
    final bonus = payoutProvider.incentives?.superBonus;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: 35.r,
          height: 35.r,
          padding: EdgeInsets.all(5.r),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bonus?.isAchievedOrPending == true
                  ? Color(0xff4E300E)
                  : Color(0xff2E2E2E),
              border: Border.all(
                  color: target.isAchieved == true
                      ? Color(0xffDFAB01)
                      : Colors.transparent)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: target.isAchieved == true
                ? Text(
                    "${target.target}",
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 13.sp,
                          color: Color(0xffDFAB01),
                        ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      RemoteImageHandler(
                        imageUrl: "payouts/incentives/super_bonus/lock.svg".cdn,
                      ),
                      Positioned.fill(
                        top: 8.r,
                        child: FittedBox(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.r),
                            child: Text(
                              "${target.target}",
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                    fontSize: 9.sp,
                                    color: AppColors.n0,
                                  ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
          ),
        ),
        Transform.translate(
          offset: Offset(0, 13.r),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 49.r,
            ),
            padding: EdgeInsets.all(3.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1000),
              color: bonus?.isAchievedOrPending == true
                  ? Color(0xff4E300E)
                  : Color(0xff2E2E2E),
            ),
            child: FittedBox(
              child: Row(
                children: [
                  Text(
                    formatIndianCurrency(target.amount),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 9.sp,
                          color: target.isAchieved == true
                              ? isAfterEndDate()
                                  ? AppColors.g30
                                  : AppColors.n0
                              : Color(0xff8B8B8B),
                        ),
                  ),
                  if (target.isAchieved == true && isAfterEndDate())
                    Container(
                      width: 8.r,
                      height: 8.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.g30,
                      ),
                      margin: EdgeInsets.only(left: 2.r),
                      padding: EdgeInsets.all(1.r),
                      child: FittedBox(
                        child: Icon(
                          Icons.check,
                          color: Color(0xff4E300E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  //method to check if current date is after the end date
  bool isAfterEndDate() {
    return DateTime.now().isAfter(endDate);
  }
}
