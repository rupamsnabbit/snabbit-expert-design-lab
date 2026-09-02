import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class BottomActionRow extends StatelessWidget {
  final String? iconUrl;
  final String text;
  final VoidCallback? onTap;
  final Color? textColor;

  const BottomActionRow({
    super.key,
    this.iconUrl,
    required this.text,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 1.sw,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconUrl != null) ...[
            RemoteImageHandler(
              imageUrl: iconUrl!.cdn,
              height: 16.h,
              width: 16.w,
            ),
            SizedBox(width: 8.w),
          ],
          // Single text - tappable with underline if callback is provided
          GestureDetector(
            onTap: onTap,
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 12.sp,
                color: onTap != null
                    ? (textColor ?? AppColors.brand)
                    : (textColor ?? AppColors.n90),
                fontWeight: FontWeight.w600,
                decoration: onTap != null
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
