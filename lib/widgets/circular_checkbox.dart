import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class CircularCheckbox extends StatelessWidget {
  final bool value;
  final Color bgColor;
  final Color borderColor;
  final bool squircle; //multiselct
  final double circularCheckboxPadding;
  final double iconSize;

  const CircularCheckbox({
    super.key,
    required this.value,
    this.bgColor = AppColors.brand,
    this.squircle = false,
    this.borderColor = const Color(0xffEAEAF1), // TODO color not found
    this.circularCheckboxPadding = 6,
    this.iconSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(circularCheckboxPadding.r),
      decoration: BoxDecoration(
        shape: squircle ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: squircle ? BorderRadius.circular(8.r) : null,
        color: value ? bgColor : AppColors.n0,
        border: Border.all(
            width: 2.w,
            color: value
                ? Colors.transparent
                : borderColor), // TODO color not found
      ),
      child: value
          ? Icon(
              Icons.check_rounded,
              size: iconSize.r,
              color: AppColors.n0,
            )
          : Icon(
              Icons.check_rounded,
              size: iconSize.r,
              color: Colors.transparent,
            ),
    );
  }
}
