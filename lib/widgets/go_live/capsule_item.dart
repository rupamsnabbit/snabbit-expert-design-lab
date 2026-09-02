import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class CapsuleItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final bool isCircle;
  final EdgeInsetsGeometry? padding;

  CapsuleItem({
    Key? key,
    required this.title,
    this.subtitle,
    this.backgroundColor = Colors.transparent,
    this.textColor = AppColors.n80, // Neutral/80
    this.borderColor = AppColors.n40,
    this.isCircle = false,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width:isCircle?42 : 129,
      height: isCircle?42:null,
      padding: isCircle?null : padding ?? EdgeInsets.symmetric(vertical: 9.8.h, horizontal: 8.01.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(isCircle?1000.r:32.r),
        border: Border.all(color: borderColor, width: 0.92),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              child: Text(
                title,
                style: textTheme.displaySmall?.copyWith(
                  fontSize: 13.7.sp,
                  height: 1.0,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Flexible(
              child: FittedBox(
                child: Text(
                  subtitle ?? '',
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 10.5.sp,
                    height: 1.14,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
