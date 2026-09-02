import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class OnboardingProgressBar extends StatelessWidget {
  final double progressValue;
  final EdgeInsets? padding;
  const OnboardingProgressBar(
      {super.key, required this.progressValue, this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 16.w),
      child: LinearProgressIndicator(
        value: progressValue,
        minHeight: 6.h,
        backgroundColor: AppColors.n40,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
  }
}
