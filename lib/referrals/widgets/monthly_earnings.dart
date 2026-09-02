import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/referrals/pages/wallet.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/upload_documents/upload_pan_modal_sheet_v2.dart';

import '../../utils/mixins/provider_initialization_mixin.dart';

class MonthlyEarnings extends StatefulWidget {
  const MonthlyEarnings({super.key});

  @override
  State<MonthlyEarnings> createState() => _MonthlyEarningsState();
}

class _MonthlyEarningsState extends State<MonthlyEarnings>
    with ProviderInitializationMixin {
  bool init = true;
  late UserProfileProvider userProfileProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
    }
    initializeCommonProviders();
    super.didChangeDependencies();
  }

  bool get hasReferrals =>
      (referralDataProvider.monthlyData?.referrals?.length ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: AppColors.n0,
        boxShadow: [
          BoxShadow(
            color: AppColors.n90.withOpacity(0.25),
            offset: const Offset(0, 1),
            blurRadius: 2.r,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 1.sw,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              color: AppColors.n0,
              border: Border.all(color: AppColors.n40),
            ),
            padding: EdgeInsets.symmetric(vertical: 23.h, horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    languageProvider.getMessage(
                      'final_payout',
                      'Final Payout',
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                SizedBox(height: 4.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatIndianCurrency2(
                        referralDataProvider.monthlyData?.dueAmount),
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(color: const Color(0xff26A179)),
                  ),
                ),
                if (referralDataProvider.referralData?.allowWithdrawal ??
                    false) ...[
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: 1.sw,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(WalletHome.routeName);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        side: const BorderSide(color: AppColors.n40),
                      ),
                      child: Text(
                        languageProvider.getMessage(
                          'view_details',
                          'View Details',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            languageProvider.getMessage('payout_summary', 'Payout Summary'),
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(color: AppColors.n90, fontSize: 16.sp),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    RemoteImageHandler(
                      imageUrl:
                          "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/payouts/referrals/referral_rs.svg",
                      height: 18.r,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      languageProvider.getMessage(
                          'referral_earnings', 'Referral Earnings'),
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: AppColors.n90),
                    ),
                  ],
                ),
              ),
              Text(
                "₹${referralDataProvider.monthlyData?.totalEarnings}",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.n90),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: DottedLine(
              lineThickness: 1.h,
              dashLength: 2.w,
              dashGapLength: 3.w,
              dashColor: AppColors.n30,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    RemoteImageHandler(
                      imageUrl:
                          "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/payouts/referrals/referral_minus.svg",
                      height: 18.r,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      languageProvider.getMessage('income_tax', 'Income Tax'),
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: AppColors.n90),
                    ),
                    SizedBox(width: 4.w),
                    Tooltip(
                      decoration: const BoxDecoration(
                        color: AppColors.n80,
                      ),
                      richMessage: WidgetSpan(
                        child: Text(
                          languageProvider.getMessage(
                            'itr_tooltip',
                            'Refundable when income tax is filed during ITR',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: AppColors.n0),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 10.w,
                      ),
                      // margin: EdgeInsets.only(left: 12.r, right: 79.r),
                      showDuration: const Duration(seconds: 3),
                      triggerMode: TooltipTriggerMode.tap,
                      preferBelow: true,
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.n50,
                        size: 18.r,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "-₹${referralDataProvider.monthlyData?.taxAmount}",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.r50),
              ),
            ],
          ),
          if (userProfileProvider.user?.isPanVerified != true)
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  constraints: BoxConstraints(
                    maxHeight: 0.7.sh,
                  ),
                  builder: (ctx) {
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(ctx).viewInsets.bottom),
                      child: const UploadPanModalSheetV2(),
                    );
                  },
                );
              },
              child: Container(
                width: 1.sw,
                margin: EdgeInsets.only(top: 16.h),
                padding: EdgeInsets.fromLTRB(17.w, 19.h, 0, 12.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11.r),
                  color: const Color(0xffFDF3F4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CustomText(
                            textData: {
                              "key": "referral_pan-warning",
                              "text": "{{pan_card}} helps reduce Income Tax",
                              "alignment": "left",
                              "style": {
                                "font_size": 14,
                                "weight": 600,
                                "color": "#C50F1F"
                              },
                              "data": [
                                {
                                  "key": "pan_card",
                                  "text": "PAN Card",
                                  "style": {
                                    "font_size": 14,
                                    "weight": 800,
                                    "color": "#C50F1F"
                                  },
                                },
                              ],
                            },
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.r40,
                              borderRadius: BorderRadius.circular(1000.r),
                            ),
                            padding: EdgeInsets.symmetric(
                                vertical: 7.h, horizontal: 9.w),
                            child: Text(
                              languageProvider.getMessage(
                                'upload_now',
                                'Upload Now',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.n0,
                                      fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    RemoteImageHandler(
                      imageUrl:
                          "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/referrals/pan_card_warning.png",
                      height: 76.h,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
