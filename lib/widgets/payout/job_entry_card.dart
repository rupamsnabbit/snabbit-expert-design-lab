import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/daily_earnings_models.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class JobEntryCard extends StatelessWidget {
  final JobDetail? job;
  final int? minsWorked;

  const JobEntryCard({super.key, this.job, this.minsWorked});

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    if (job == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
        ),
        padding: EdgeInsets.all(20.r),
        margin: EdgeInsets.only(bottom: 12.h),
        child: Center(
          child: Text(
            languageProvider.getMessage('no_job_data', 'No job data available'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.n60,
                ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.all(20.r),
      margin: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${languageProvider.getMessage('job_id', 'Job ID')} #${job?.jobId ?? ''}",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.n90,
                  height: 1.38,
                ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    "${languageProvider.getMessage('hours_worked', 'Hours worked')}: ",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.n90,
                          height: 1.57,
                        ),
                  ),
                  Text(
                    "${minsToHours(job?.duration)} ${languageProvider.getMessage('hours', 'hours')}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.n60,
                          height: 1.57,
                        ),
                  ),
                ],
              ),
              Text(
                "₹ ${job?.jobEarning?.toInt() ?? 0}",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.n90,
                      height: 1.18,
                    ),
              ),
            ],
          ),
          const Divider(color: AppColors.n20),

          // Base Pay
          if (job?.details?.basePay != null)
            _buildJobAttribute(
              context: context,
              iconData: AssetConstants.jobDetailRupee,
              label: languageProvider.getMessage('base_pay', 'Base pay'),
              value: job!.details!.basePay!,
            ),

          // On Time
          if (job?.details?.onTime != null)
            _buildJobAttribute(
              context: context,
              iconData: AssetConstants.jobDetailClock,
              label: job!.details!.onTime! >= 0
                  ? languageProvider.getMessage(
                      'time_pe_bonus',
                      'Time pe Bonus',
                    )
                  : languageProvider.getMessage(
                      'time_pe_penalty',
                      'Time pe Penalty',
                    ),
              value: job!.details!.onTime!,
            ),

          // Long Distance
          if (job?.details?.longDistance != null)
            _buildJobAttribute(
              context: context,
              iconData: AssetConstants.jobDetailLongDistance,
              label:
                  languageProvider.getMessage('long_distance', 'Long distance'),
              value: job!.details!.longDistance!,
            ),

          // Overtime
          if (job?.details?.ot?.amount != null)
            _buildJobAttribute(
              context: context,
              iconData: AssetConstants.jobDetailOt,
              label:
                  "${minsWorked != null && job?.details?.ot?.otMins != null && minsWorked! > job!.details!.ot!.otMins! ? languageProvider.getMessage('partial_overtime', 'Partial Overtime') : languageProvider.getMessage('overtime', 'Overtime')} (${minsToHours(job?.details?.ot?.otMins)} ${languageProvider.getMessage('hrs', 'hrs')})",
              value: job!.details!.ot!.amount!,
            ),

          // Additional Details
          if (job?.details?.additionalDetails != null &&
              job!.details!.additionalDetails!.isNotEmpty)
            ...job!.details!.additionalDetails!.map((detail) {
              if (detail.value != null) {
                return _buildJobAttribute(
                  context: context,
                  iconData: detail.image ?? "",
                  label: languageProvider.getMessage(
                      detail.key ?? '', detail.key ?? ''),
                  value: detail.value!,
                );
              } else {
                return const SizedBox();
              }
            }),

          // Cash Collected
          if (job?.cashCollected != null && job!.cashCollected! > 0)
            const Divider(color: AppColors.n20),
          if (job?.cashCollected != null && job!.cashCollected! > 0)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: Image.asset(AssetConstants.cashCollected),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        languageProvider.getMessage(
                            'cash_collected', 'Cash collected'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.sp,
                              color: const Color(0xFF40515B),
                              height: 2.18,
                            ),
                      ),
                    ],
                  ),
                  Text(
                    "₹${job!.cashCollected!.abs()}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.sp,
                          color: const Color(0xFF101840),
                          height: 1.57,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJobAttribute({
    required BuildContext context,
    required String iconData,
    required String label,
    required int value,
    bool isLate = false,
    Color? bgColor,
  }) {
    final bool isPositive = value >= 0;
    final bool isAssetImage = !iconData.startsWith("https");
    final Color color = bgColor ?? (isPositive ? AppColors.g10 : AppColors.r10);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isAssetImage)
                Container(
                  width: 24.r,
                  height: 24.r,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  padding: EdgeInsets.all(4.r),
                  child: Image.asset(
                    iconData,
                    width: 16.r,
                    height: 16.r,
                    errorBuilder: (_, __, ___) => SizedBox(
                      width: 16.r,
                      height: 16.r,
                    ),
                  ),
                )
              else
                Image.network(
                  iconData,
                  width: 24.r,
                  errorBuilder: (_, __, ___) => SizedBox(
                    width: 24.r,
                    height: 24.r,
                  ),
                ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isLate ? AppColors.r50 : AppColors.n90,
                      height: 1.57,
                    ),
              ),
            ],
          ),
          Text(
            "${isPositive ? '+' : '-'}₹${value.abs()}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.n60,
                  height: 1.57,
                ),
          ),
        ],
      ),
    );
  }
}
