import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../utils/colors.dart';


class ClickableText extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const ClickableText({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      // style: TextButton.styleFrom(
      //   padding: EdgeInsets.zero,
      // ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        // mainAxisSize: MainAxisSize.min,
        children: [
          child,
          Icon(
            Icons.chevron_right,
            size: 16.sp,
            color: AppColors.n70,
          ),
        ],
      ),
    );
  }
}
