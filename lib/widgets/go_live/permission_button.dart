import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:snabbit_runner/utils/colors.dart'; // For responsive sizing

class PermissionButton extends StatelessWidget {
  final String permissionName; // e.g., "Camera"
  final String actionText;     // e.g., "Allow access"
  final VoidCallback? onPressed; // Callback when the button is pressed
  final String icon;     // Icon for the permission (e.g., Icons.camera_alt_outlined)
  final Color actionTextColor; // Color for the action text (e.g., red for "Allow access")
  final bool isLoading; // Optional loading state

  PermissionButton({
    super.key,
    required this.permissionName,
    required this.actionText,
    this.onPressed,
    required this.icon,
    this.actionTextColor = AppColors.r40, // Default to Red/R40
    this.isLoading = false, // Default to not loading
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector( // Use GestureDetector for tap functionality
      onTap: onPressed,
      child: Container(
        width: 155.w, // Figma: width: 155px;
        height: 60.h, // Figma: height: 60px;
        padding: EdgeInsets.symmetric(horizontal: 16.w), // Figma: padding: 0px 16px;
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.n40, // Figma: border: 0.916481px solid #D8DAE5;
            width: 0.916481.w, // Use .w for responsive border width
          ),
          borderRadius: BorderRadius.circular(12.r), // Figma: border-radius: 12px;
        ),
        child: Row( // Figma: display: flex; flex-direction: row; align-items: center; gap: 8px;
          mainAxisAlignment: MainAxisAlignment.start, // Align items to start
          crossAxisAlignment: CrossAxisAlignment.center, // Figma: align-items: center;
          children: [
            // Icon (famicons:camera-outline)
            SvgPicture.asset(
              icon,
              height: 29.r, // Figma: width: 29px; height: 29px;
              color: Colors.black, // From Figma: border: 2px solid #000000; (implies icon color)
            ),
            SizedBox(width: 8.w), // Figma: gap: 8px;

            // Recurrence Detail Info (Text Column)
            Column( // Figma: display: flex; flex-direction: column; align-items: flex-start; gap: 4px;
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically within the button
              crossAxisAlignment: CrossAxisAlignment.start, // Figma: align-items: flex-start;
              children: [
                // Permission Name Text (e.g., "Camera")
                Flexible(
                  // width: 71.99.w, // Figma: width: 71.99px;
                  // height: 13.h, // Figma: height: 13px;
                  child: FittedBox(
                    child: Text(
                      permissionName,
                      style: textTheme.labelMedium?.copyWith(
                        height: 12 / 13, // Figma: line-height: 12px; (calculated as line-height / font-size)
                        color: AppColors.n80, // Figma: color: #525871;
                      ),
                      overflow: TextOverflow.ellipsis, // Handle long text
                    ),
                  ),
                ),
                SizedBox(height: 4.h), // Figma: gap: 4px;

                // Action Text (e.g., "Allow access")
               isLoading? const CupertinoActivityIndicator() : Flexible(
                  // width: 71.99.w, // Figma: width: 71.99px;
                  // height: 13.h, // Figma: height: 13px;
                  child: FittedBox(
                    child: Text(
                      actionText,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500, // Figma: font-weight: 500;
                        height: 12 / 10.5128, // Figma: line-height: 12px; (calculated as line-height / font-size)
                        color: actionTextColor, // Figma: color: #D14343; (Red/R40)
                      ),
                      overflow: TextOverflow.ellipsis, // Handle long text
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}