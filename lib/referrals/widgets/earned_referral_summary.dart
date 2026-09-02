import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

import '../../providers/referral.dart';

class EarnedReferralSummary extends StatefulWidget {
  final RunnerReferral currentReferral;

  const EarnedReferralSummary({
    super.key,
    required this.currentReferral,
  });

  @override
  State<EarnedReferralSummary> createState() => _EarnedReferralSummaryState();
}

class _EarnedReferralSummaryState extends State<EarnedReferralSummary> {
  bool init = true;
  late LanguageProvider languageProvider;
  late ReferralDataProvider referralDataProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.n30),
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getMessage(
              'earnings_summary',
              'Earnings summary',
            ),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: DottedLine(
              lineThickness: 1.h,
              dashLength: 5.w,
              dashColor: AppColors.n30,
            ),
          ),
          ...widget.currentReferral.bonusSummary?.map((e) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText(
                              textData: e.title,
                            ),
                            if (e.subtitle != null)
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.r0,
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                margin: EdgeInsets.only(top: 8.h),
                                padding: EdgeInsets.symmetric(
                                    vertical: 3.h, horizontal: 7.w),
                                child: CustomText(
                                  textData: e.subtitle,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        formatIndianCurrency(e.amount),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: const Color(0xff40515B)),
                      ),
                    ],
                  ),
                );
              }).toList() ??
              [],
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: DottedLine(
              lineThickness: 1.h,
              dashLength: 5.w,
              dashColor: AppColors.n30,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  languageProvider.getMessage(
                    'net_payable',
                    'Net Payable',
                  ),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              Text(
                formatIndianCurrency(widget.currentReferral.netPayable),
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
