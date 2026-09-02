import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/daily_earnings_models.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/payout/ming_applicable_section.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

import '../../utils/common_methods.dart';

class BasePaySection extends StatelessWidget {
  final BasePay? data;
  final bool? mingEligible;
  final List<MingDetail>? mingDetails;

  const BasePaySection(
      {super.key, this.data, this.mingEligible, this.mingDetails});

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    if (data == null) {
      return const SizedBox();
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
        ),
        padding: EdgeInsets.all(24.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageProvider.getMessage('base_pay', 'Base Pay'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF40515B),
                  ),
            ),
            SizedBox(height: 10.h),
            Divider(color: Colors.grey[300]),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Text(
                  languageProvider.getMessage(
                      'no_base_pay_data', 'No base pay data available'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF40515B),
                      ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: mingEligible == true ? AppColors.n0 : const Color(0xffD0D0D0),
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.n0,
              borderRadius: BorderRadius.circular(8.r),
            ),
            padding: EdgeInsets.all(15.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.getMessage('base_pay', 'Base Pay'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF40515B),
                      ),
                ),
                SizedBox(height: 10.h),
                Divider(color: Colors.grey[300]),

                // Hours worked x Rate = Total row
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  color: const Color(0xFFF6F0FF),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        languageProvider.getMessage(
                            'hours_worked', 'Hours worked'),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF40515B),
                            ),
                      ),
                      Text(
                        "x",
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF40515B),
                            ),
                      ),
                      Text(
                        languageProvider.getMessage(
                            'rate_per_hour', 'Rate Per Hour'),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF40515B),
                            ),
                      ),
                      Text(
                        "=",
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF40515B),
                            ),
                      ),
                      Text(
                        languageProvider.getMessage('total', 'Total'),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF40515B),
                            ),
                      ),
                    ],
                  ),
                ),

                // Values row
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 7.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${minsToHours(data!.minsWorked)} ${languageProvider.getMessage('hours', 'hours')}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF40515B),
                            ),
                      ),
                      const SizedBox(),
                      Text(
                        "₹${data!.ratePerHour?.toInt()}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF40515B),
                            ),
                      ),
                      const SizedBox(),
                      Text(
                        "₹${data!.totalBasePay?.toInt()}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.g50,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // MinG Applicable section
          const MingApplicableSection(),
        ],
      ),
    );
  }
}
