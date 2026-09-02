import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';

class OnboardingOptionButton extends StatelessWidget {
  final OptionUIConfig? uiConfig;
  final VoidCallback? onTap;
  final Color fallbackColor;
  final String fallbackText;
  final String fallbackIcon;
  final IconData fallbackErrorIcon;

  const OnboardingOptionButton({
    super.key,
    required this.uiConfig,
    required this.onTap,
    required this.fallbackColor,
    required this.fallbackText,
    required this.fallbackIcon,
    required this.fallbackErrorIcon,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = uiConfig?.ctaColor ?? fallbackColor;
    final textColor = uiConfig?.foregroundColor ?? AppColors.n0;
    final buttonText = uiConfig?.ctaText;
    final iconUrl = uiConfig?.ctaIcon ?? fallbackIcon;

    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 28.5.w, vertical: 20.h),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 50.w),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: buttonText != null && buttonText.isNotEmpty
                ? Text(
              buttonText,
              style: TextStyle(
                color: textColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            )
                : RemoteImageHandler(
              imageUrl: iconUrl.cdn,
              height: 26.r,
              fit: BoxFit.cover,
              errorWidget: Icon(
                fallbackErrorIcon,
                color: textColor,
                size: 30.r,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
