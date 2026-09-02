import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../utils/colors.dart';


class PayoutSectionContainer extends StatelessWidget {
  final Widget child;

  const PayoutSectionContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 24.w,
        vertical: 20.h,
      ),
      child: child,
    );
  }
}