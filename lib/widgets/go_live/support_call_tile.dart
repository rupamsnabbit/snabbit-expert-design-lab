import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // For responsive sizing
import 'package:snabbit_runner/utils/colors.dart';
import 'package:url_launcher/url_launcher.dart'; // For making phone calls

class SupportCallTile extends StatelessWidget {
  final String name;
  final String role;
  final String phoneNumber;
  final Function(String phoneNumber) onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color borderColor;
  final Color backgroundColor;
  final TextStyle textStyle;

  const SupportCallTile({
    super.key,
    required this.name,
    required this.role,
    required this.phoneNumber,
    required this.onTap,
    required this.padding,
    required this.borderRadius,
    required this.borderColor,
    required this.backgroundColor,
    required this.textStyle,
  });

  factory SupportCallTile.defaultStyle({
    required String name,
    required String role,
    required String phoneNumber,
    required Function(String phoneNumber) onTap,
  }) {
    return SupportCallTile(
      name: name,
      role: role,
      phoneNumber: phoneNumber,
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: 8.83657.w,
        vertical: 7.06925.h,
      ),
      borderRadius: 7.06925.r,
      borderColor: const Color(0xFFD8DAE5),
      backgroundColor: Colors.white,
      textStyle: const TextStyle(
        fontSize: 12.3712,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF101840),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(phoneNumber),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: borderColor,
            width: 0.883657.w,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left section: Name and Role
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name ($role)',
                    style: textStyle,
                  ),
                ],
              ),
            ),
            SizedBox(width: 26.27.w), // Figma: gap: 26.27px;

            // Right section: Call Icon
            // Figma: width: 33.99px; height: 34.38px;
            Container(
              width: 33.99.w,
              height: 34.38.h,
              // The Figma shows a green background on the icon itself,
              // not a separate container, so we'll directly color the icon.
              alignment: Alignment.center, // Center the icon within its container
              child: Icon(
                Icons.call, // material-symbols:call
                size: 21.93.r, // Figma: width: 21.93px; height: 21.93px;
                color: AppColors.g40, // Figma: background: #429777; (Green/G40)
              ),
            ),
          ],
        ),
      ),
    );
  }
}

