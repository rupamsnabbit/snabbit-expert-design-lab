import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/enums.dart';

import '../../pages/payout/attendance.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';

void showJoiningBonusDialog(BuildContext context) {
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
          child: const JoiningBonusPopup(),
        ),
      );
    },
  );
}

class JoiningBonusPopup extends StatefulWidget {
  const JoiningBonusPopup({super.key});

  @override
  State<JoiningBonusPopup> createState() => JoiningBonusPopupState();
}

class JoiningBonusPopupState extends State<JoiningBonusPopup> {
  bool init = true;
  late LanguageProvider languageProvider;
  late PayoutProvider payoutProvider;
  late UserProfileProvider userProfileProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  int get bonus {
    return payoutProvider.incentives?.joiningBonus?.jb ?? 0;
  }

  int? get jbEligibleDays {
    return payoutProvider.incentives?.joiningBonus?.jbEligibleDays ?? 0;
  }

  DateTime? get joiningDate {
    return payoutProvider.incentives?.joiningBonus?.joiningDate;
  }

  DateTime? get paymentDate {
    return payoutProvider.incentives?.joiningBonus?.paymentDate;
  }

  bool get isJbCredited {
    try {
      return DateTime.now().toUtc().isAfter(paymentDate!);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Image.asset(
              userProfileProvider.user?.runnerStatus == RunnerState.SUSPENDED
                  ? AssetConstants.negativeState
                  : AssetConstants.joiningBonusBg,
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
                languageProvider.getMessage("joining_bonus", "Joining Bonus"),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.n0,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: 24.h),

              // Image - will shrink to accommodate the expanded container
              Flexible(
                child: Image.asset(
                  userProfileProvider.user?.runnerStatus ==
                          RunnerState.SUSPENDED
                      ? AssetConstants.negativeStateJoiningBonus
                      : AssetConstants.joiningBonusCoin,
                  fit: BoxFit.contain,
                  height: 122.h,
                ),
              ),
              SizedBox(height: 7.h),

              Text(
                formatIndianCurrency(bonus),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 42.sp,
                      color: AppColors.n0,
                    ),
              ),
              SizedBox(height: 30.h),
              Center(
                child: isJbCredited
                    ? Text(
                        languageProvider.getMessage(
                            'bonus_credited', 'Your BONUS has been credited'),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: AppColors.n0,
                              fontWeight: FontWeight.w500,
                            ),
                      )
                    : RichText(
                        text: TextSpan(
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: AppColors.n0,
                              ),
                          children: [
                            TextSpan(
                              text: "${languageProvider.getFormattedMessage(
                                  "jb_work_message",
                                  "Work for {{jb_eligible_days}} days to get",
                                  {
                                  'jb_eligible_days': jbEligibleDays,
                                  },
                                  )
                                } ",
                            ),
                            TextSpan(
                              text: languageProvider.getMessage(
                                'paid_capital',
                                'PAID',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: AppColors.y40,
                                  ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              SizedBox(height: 42.h),
              if (isJbCredited)
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.n0,
                          fontWeight: FontWeight.w500,
                        ),
                    children: [
                      TextSpan(
                        text: languageProvider.getMessage(
                          'payment_date',
                          'Payment date ',
                        ),
                      ),
                      TextSpan(
                        text: paymentDate != null
                            ? " ${DateFormat('d\'${getDaySuffix(paymentDate!.day)}\' MMMM').format(paymentDate!)}"
                            : '',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: AppColors.n0,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getMessage(
                              'joining_date',
                              'Joining date:',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.n0),
                          ),
                          if (joiningDate != null)
                            Text(
                              DateFormat(
                                      'd\'${getDaySuffix(joiningDate!.day)}\' MMMM')
                                  .format(joiningDate!),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    fontSize: 16.sp,
                                    color: AppColors.n0,
                                  ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getMessage(
                              'payment_date',
                              'Payment date:',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.n0),
                          ),
                          if (paymentDate != null)
                            Text(
                              DateFormat(
                                      'd\'${getDaySuffix(paymentDate!.day)}\' MMMM')
                                  .format(paymentDate!),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    fontSize: 16.sp,
                                    color: AppColors.n0,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 17.h),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(Attendance.routeName);
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xff410666),
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
                    const Icon(
                      Icons.double_arrow_rounded,
                      color: AppColors.y40,
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
