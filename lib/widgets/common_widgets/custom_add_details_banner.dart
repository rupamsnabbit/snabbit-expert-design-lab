import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Widget to display a banner prompting users to add bank account or UPI
class CustomAddDetailsBanner extends StatelessWidget {
  /// Image URL to display on the right side of the banner
  final String? image;
  final Map<String, dynamic> title;
  final String? subtitle;
  final Color? backgroundColor;

  /// Callback when the banner is tapped
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? imageWidth;
  final EdgeInsetsGeometry? titlePadding;

  const CustomAddDetailsBanner({
    super.key,
    this.image,
    this.onTap,
    this.subtitle,
    required this.title,
    this.backgroundColor,
    this.padding,
    this.imageWidth,
    this.titlePadding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final textTheme = Theme.of(context).textTheme;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            // width: 361.w,
            // height: 90.h,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.r0,
              borderRadius: BorderRadius.circular(11.08.r),
            ),
            padding: padding ?? EdgeInsets.fromLTRB(17.w, 7.h, 20.w, 0),
            child: Row(
              children: [
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: titlePadding ?? EdgeInsets.zero,
                        child: SizedBox(
                          width: 179.w,
                          child: CustomText(textData: title),
                        ),
                      ),
                      if (subtitle != null)
                        // Add Details button
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 11.h),
                          decoration: BoxDecoration(
                            color: AppColors.r40,
                            borderRadius: BorderRadius.circular(19.86.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 8.83.w,
                              ),
                              Text(
                                subtitle ?? '',
                                style: textTheme.bodySmall?.copyWith(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 18 / 12,
                                  letterSpacing: -0.265,
                                  color: AppColors.n0,
                                ),
                              ),
                              // Chevron icon
                              Icon(Icons.chevron_right,
                                  size: 16.r, color: AppColors.n0),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Bank institution image
                image != null && image!.isNotEmpty
                    ? RemoteImageHandler(
                        imageUrl: image!,
                        width: imageWidth ?? 80.w,
                        fit: BoxFit.contain,
                        errorWidget: const SizedBox.shrink(),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        );
      },
    );
  }
}
