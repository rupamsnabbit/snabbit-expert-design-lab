import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/constants.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../providers/payout.dart';
import '../../widgets/payout/tds_warning.dart';
import 'payout_item_card.dart';

class AdjustmentBreakdownView extends StatefulWidget {
  const AdjustmentBreakdownView({super.key});

  @override
  State<AdjustmentBreakdownView> createState() =>
      _AdjustmentBreakdownViewState();
}

class _AdjustmentBreakdownViewState extends State<AdjustmentBreakdownView> {
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

  void openTdsModalSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return CommonBottomSheetSetup(
          horizontalPadding: 24.w,
          child: const TdsWarning(),
        );
      },
    );
  }

  Widget get _cashCollectedSummary {
    return Column(
      children: [
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: Text(
                languageProvider.getMessage(
                  'cash_collected',
                  'Cash Collected',
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Text(
              "-₹${payoutProvider.earnings?.cashCollected?.amount}",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.n90,
                  ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xffFAFAFA),
            border: Border(
              bottom: BorderSide(
                color: AppColors.n90.withOpacity(0.06),
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      languageProvider.getMessage(
                        'date',
                        'Date',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                VerticalDivider(
                  color: AppColors.n90.withOpacity(0.06),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      languageProvider.getMessage(
                        'job_id',
                        'Job ID',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                VerticalDivider(
                  color: AppColors.n90.withOpacity(0.06),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      languageProvider.getMessage(
                        'cash_amount',
                        'Cash Amount',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ...payoutProvider.earnings?.cashCollected?.summaryItems?.map((e) {
              return Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.n90.withOpacity(0.06),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          e.date != null
                              ? dateFormatVisual3.format(e.date!)
                              : "",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          "#${e.jobId}",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          "-₹${e.amount}",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList() ??
            [],
        SizedBox(height: 24.h),
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              languageProvider.getMessage(
                'i_understand',
                'I understand',
              ),
            ),
          ),
        ),
      ],
    );
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
                          "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/payouts/referrals/referral_minus.svg",
                      width: 18.r,
                    ),
                    SizedBox(width: 8.r),
                    Text(
                      languageProvider.getMessage('adjustments', 'Adjustments'),
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: AppColors.n90),
                    ),
                  ],
                ),
              ),
              Text(
                "-₹${payoutProvider.earnings?.adjustmentDetails?.total}",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.r50),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          PayoutItemCard(
            title: languageProvider.getMessage(
              "govt_taxes",
              "Government Taxes",
            ),
            amount: anyValueToInt(payoutProvider.earnings?.tds?.amount) ?? 0,
            amountColor: AppColors.r50,
            subtitle: payoutProvider.earnings?.tds?.subtitle != null
                ? Container(
                    decoration: BoxDecoration(
                      color: AppColors.r0,
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    margin: EdgeInsets.only(top: 4.h),
                    padding:
                        EdgeInsets.symmetric(vertical: 3.h, horizontal: 7.w),
                    child: CustomText(
                      textData: payoutProvider.earnings?.tds?.subtitle ?? {},
                    ),
                  )
                : null,
            onTap: openTdsModalSheet,
          ),
          SizedBox(height: 12.h),
          PayoutItemCard(
            title: languageProvider.getMessage(
              "cash_collected",
              "Cash Collected",
            ),
            amount:
                anyValueToInt(payoutProvider.earnings?.cashCollected?.amount) ??
                    0,
            amountColor: AppColors.r50,
            onTap: () {
              if ((anyValueToInt(
                          payoutProvider.earnings?.cashCollected?.amount) ??
                      0) >
                  0) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  constraints: BoxConstraints(
                    maxHeight: 0.7.sh,
                  ),
                  builder: (_) {
                    return CommonBottomSheetSetup(
                      child: _cashCollectedSummary,
                    );
                  },
                );
              }
            },
          ),
          ...payoutProvider.earnings?.adjustmentDetails?.additionalItems
                  ?.map((e) {
                return Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: PayoutItemCard(
                    title: languageProvider.getMessage(
                      e.key ?? "",
                      e.key ?? "",
                    ),
                    amountColor: AppColors.r50,
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
