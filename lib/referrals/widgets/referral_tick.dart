import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';


class ReferralTick extends StatelessWidget {
  final double height;

  const ReferralTick({
    super.key,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height.r,
      width: height.r,
      decoration: const BoxDecoration(
        color: AppColors.g30,
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(3.r),
      child: const FittedBox(
        child: Icon(
          Icons.check_rounded,
          color: AppColors.n0,
        ),
      ),
    );
  }
}
