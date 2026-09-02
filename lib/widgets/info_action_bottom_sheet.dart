import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// A reusable bottom sheet with an icon, label badge, title, subtitle,
/// and a single action button. All content is configurable.
class InfoActionBottomSheet extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color labelColor;
  final Color? labelBackgroundColor;
  final String title;
  final String subtitle;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback? onPressed;

  const InfoActionBottomSheet({
    super.key,
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    this.labelColor = AppColors.brand,
    this.labelBackgroundColor,
    this.buttonColor = AppColors.brand,
    this.onPressed,
  });

  /// Shows the bottom sheet. Returns `true` if the button was tapped,
  /// `null` if dismissed by swiping.
  static Future<bool?> show(
    BuildContext context, {
    required Widget icon,
    required String label,
    required String title,
    required String subtitle,
    required String buttonText,
    Color labelColor = AppColors.brand,
    Color? labelBackgroundColor,
    Color buttonColor = AppColors.brand,
    VoidCallback? onPressed,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => CommonBottomSheetSetup(
        gradient: _redSheetGradient,
        child: InfoActionBottomSheet(
          icon: icon,
          label: label,
          title: title,
          subtitle: subtitle,
          buttonText: buttonText,
          labelColor: labelColor,
          labelBackgroundColor: labelBackgroundColor,
          buttonColor: buttonColor,
          onPressed: onPressed ?? () => Navigator.of(ctx).pop(true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          _buildBadge(context),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Column(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.n90,
                        fontSize: 20.sp,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.n80,
                        fontSize: 16.sp,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: AppColors.n0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  // Badge colors from Figma (Snabbit 2.0 – node 19322:4618).
  static const Color _badgeBackground = Color(0xffFFD5D8);
  static const Color _badgeDotAndText = Color(0xFFD03254);

  /// Subtle red gradient for the bottom sheet background (Snabbit Shield style).
  static const LinearGradient _redSheetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      // #FFE3E399 → #FFE3E300 style, but in RGBO to mirror Shield consent pattern.
      Color.fromRGBO(255, 227, 227, 0.3),
      Color.fromRGBO(255, 227, 227, 0.0),
    ],
  );

  Widget _buildBadge(BuildContext context) {
    final textColor =
        labelColor == AppColors.brand ? _badgeDotAndText : labelColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: labelBackgroundColor ?? _badgeBackground,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _badgeDotAndText.withValues(alpha: 0.05),
            offset: Offset(0, 2.h),
            blurRadius: 2.r,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.5,
              fontSize: 12.sp,
              shadows: [
                Shadow(
                  color: textColor.withValues(alpha: 0.25),
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
