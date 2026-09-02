import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class DobSelectorV2 extends StatelessWidget {
  final void Function()? onTap;
  final TextEditingController dobDay;
  final TextEditingController dobMonth;
  final TextEditingController dobYear;
  final bool enabled;

  const DobSelectorV2({
    super.key,
    required this.onTap,
    required this.dobDay,
    required this.dobMonth,
    required this.dobYear,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              height: 62.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.n40),
                color: AppColors.n0,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 20.h),
                child: Text(
                  dobDay.text.isEmpty ? 'Day' : dobDay.text,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: enabled ? AppColors.n50 : AppColors.n30),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              height: 62.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.n40),
                color: AppColors.n0,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 20.h),
                child: Text(
                  dobMonth.text.isEmpty ? 'Month' : dobMonth.text,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: enabled ? AppColors.n50 : AppColors.n30),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              height: 62.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.n40),
                color: AppColors.n0,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 20.h),
                child: Text(
                  dobYear.text.isEmpty ? 'Year' : dobYear.text,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: enabled ? AppColors.n50 : AppColors.n30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
