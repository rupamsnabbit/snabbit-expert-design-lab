import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Generic navigation list tile widget with background gradient, icon, title, and chevron
///
/// Example usage:
/// ```dart
/// NavigationListTile(
///   titleKey: "view_daily_earnings",
///   titleDefaultValue: "View Daily earnings",
///   icon: RemoteImageHandler(
///     imageUrl: imageUrl,
///     width: 65.w,
///     height: 54.h,
///   ),
///   backgroundImage: null, // Optional background image
///   onTap: () {
///     // Navigator.of(context).pushNamed(routeName);
///   },
/// )
/// ```
class NavigationListTile extends StatelessWidget {
  /// Title text to display
  final String titleKey;
  final String titleDefaultValue;

  /// Icon widget to display on the left (typically RemoteImageHandler or Image)
  final String? icon;

  /// Optional background image widget (full width, stacked below main content)
  final String? backgroundImage;

  /// Optional on tap callback
  final VoidCallback? onTap;

  const NavigationListTile({
    super.key,
    required this.titleKey,
    required this.titleDefaultValue,
    this.icon,
    this.backgroundImage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) => Container(
          height: 73.h,
          margin: EdgeInsets.only(top: 20.h),
          decoration: BoxDecoration(
            color: AppColors.n0,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.n30),
            boxShadow: [
              BoxShadow(
                // The color is black (#000000) with 25% opacity (40 in hex is approx 25%)
                color: Color(0x40000000).withValues(alpha: 0.05),

                // The blur radius is 4.0
                blurRadius: 4.0,

                // The spread radius is 0.0 (no spreading/shrinking)
                spreadRadius: 0.0,

                // The offset is (dx: 0.0, dy: 1.0)
                offset: Offset(0.0, 1.0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Stack(
              children: [
                // Optional background image (full width, stacked below)
                if (backgroundImage != null)
                  Positioned.fill(
                    child: RemoteImageHandler(
                      imageUrl: backgroundImage ?? "",
                      errorWidget: const SizedBox(),
                    ),
                  ),

                // Main content
                Positioned.fill(
                  child: Row(
                    children: [
                      // Icon on the left
                      if (icon != null)
                        RemoteImageHandler(
                          imageUrl: icon ?? "",
                          // width: 65.w,
                          // height: 54.h,
                          // height: 73.h,
                          errorWidget: const SizedBox(),
                        ),

                      // Title text
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: 14.w),
                          child: Text(
                            languageProvider.getMessage(
                                titleKey, titleDefaultValue),
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              height: 14 / 14,
                              color: AppColors.n90,
                              letterSpacing: -0.02,
                            ),
                          ),
                        ),
                      ),

                      // Chevron button on the right
                      Padding(
                        padding: EdgeInsets.only(right: 14.w),
                        child: Container(
                          width: 24.w,
                          height: 24.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.n30,
                              width: 1.5.r,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.chevron_right,
                              size: 16.r,
                              color: AppColors.n90,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
