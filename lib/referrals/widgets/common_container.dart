import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
//  make use of this in all places
class ReferralCommonContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const ReferralCommonContainer({
    super.key,
    required this.child,
    this.padding,
  });

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
      padding: padding ??
          EdgeInsets.symmetric(
            vertical: 20.h,
            horizontal: 16.w,
          ),
      child: child,
    );
  }
}
