import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../pages/payout/bonus_home.dart';
import '../../pages/payout/daily_earnings_list.dart';
import '../../providers/payout.dart';
import 'payout_item_card.dart';

class EarningsBreakdownView extends StatefulWidget {
  const EarningsBreakdownView({super.key});

  @override
  State<EarningsBreakdownView> createState() => _EarningsBreakdownViewState();
}

class _EarningsBreakdownViewState extends State<EarningsBreakdownView> {
  bool init = true;
  late PayoutProvider payoutProvider;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: AppColors.n0,
      ),
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 17.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    RemoteImageHandler(
                      imageUrl:
                          "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/referrals/referral_rs.json",
                      width: 30.r,
                    ),
                    SizedBox(width: 8.r),
                    Text(
                      languageProvider.getMessage('earnings', 'Earnings'),
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: AppColors.n90),
                    ),
                  ],
                ),
              ),
              Text(
                "₹${payoutProvider.earnings?.earningDetails?.total}",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.n90),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          PayoutItemCard(
            title: languageProvider.getMessage(
              "daily_earning",
              "Daily Earning",
            ),
            amount: anyValueToInt(payoutProvider.earnings?.earning) ?? 0,
            onTap: () {
              Navigator.of(context).pushNamed(DailyEarningsList.routeName);
            },
          ),
          SizedBox(height: 12.h),
          PayoutItemCard(
            title: languageProvider.getMessage(
              "monthly_bonus",
              "Monthly Bonus",
            ),
            amount: anyValueToInt(payoutProvider.earnings?.totalIncentive) ?? 0,
            onTap: () {
              Navigator.of(context).pushNamed(BonusHome.routeName);
            },
          ),
          ...payoutProvider.earnings?.earningDetails?.additionalItems?.map((e) {
                return Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: PayoutItemCard(
                    title: languageProvider.getMessage(
                      e.key ?? "",
                      e.key ?? "",
                    ),
                    amount: e.value,
                    onTap: () {
                      showModalBottomSheet(
                          context: context,
                          builder: (_) {
                            return CommonBottomSheetSetup(
                              child: Column(
                                children: [
                                  SizedBox(height: 20.h),
                                  CustomText(
                                    textData: e.bottomSheetText,
                                  ),
                                  SizedBox(height: 20.h),
                                  SizedBox(
                                    width: 1.sw,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        languageProvider.getMessage(
                                          'ok_got_it',
                                          'Okay, got it',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          });
                    },
                  ),
                );
              }).toList() ??
              [],
        ],
      ),
    );
  }
}
