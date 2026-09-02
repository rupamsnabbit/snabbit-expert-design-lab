import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class RadioListTileData {
  final String? title;
  final String? subtitle;
  final String? trailingIcon;
  final Color? unselectedBorderColor;
  final Color? selectedBorderColor;
  final Color? selectedColor;
  final String? optionValue;

  const RadioListTileData({
    this.title,
    this.subtitle,
    this.trailingIcon,
    this.unselectedBorderColor,
    this.selectedBorderColor,
    this.selectedColor,
    this.optionValue,
  });

  factory RadioListTileData.fromJson(Map<String, dynamic> json) {
    return RadioListTileData(
      title: json['title'],
      subtitle: json['subtitle'],
      trailingIcon: json['trailing_icon'],
      unselectedBorderColor: json['unselected_border_color'] != null
          ? hexToColor(json['unselected_border_color'])
          : null,
      selectedBorderColor: json['selected_border_color'] != null
          ? hexToColor(json['selected_border_color'])
          : null,
      selectedColor: json['selected_color'] != null
          ? hexToColor(json['selected_color'])
          : null,
      optionValue: json['option_value'],
    );
  }
}

class RadioListTileQuestion extends StatelessWidget {
  final Function(OnboardingQuestionOption?)? onTap;
  final OnboardingQuestionData? data;
  final OnboardingQuestionOption? option;
  final OnboardingQuestionOption? selectedOption;
  const RadioListTileQuestion({
    super.key,
    this.onTap,
    this.data,
    this.option,
    this.selectedOption,
  });

  @override
  Widget build(BuildContext context) {
    RadioListTileData? uiConfigData;
    String? title;

    if (option != null) {
      // Use option data
      title = option!.text;
      try {
        // Convert OptionUIConfig to RadioListTileData format
        final optionUiConfig = option!.uiConfig;
        if (optionUiConfig != null) {
          uiConfigData = RadioListTileData(
            title: option!.text,
            trailingIcon: optionUiConfig.trailingIcon,
            optionValue: option!.value,
            subtitle: optionUiConfig.subTitle,
          );
        }
      } catch (_) {}
    } else if (data != null) {
      try {
        uiConfigData = RadioListTileData.fromJson(data?.uiConfig ?? {});
      } catch (_) {}
    }

    final bool isSelected = selectedOption == option;
    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: () => onTap?.call(option),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
              color: isSelected
                  ? uiConfigData?.selectedBorderColor ?? AppColors.brand
                  : uiConfigData?.unselectedBorderColor ??
                      const Color(0xFFD8DADC),
              width: 1.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// --- Custom Radio ---
            Container(
              width: 18.w,
              height: 18.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.brand : const Color(0xFF6D7783),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 10.r,
                      height: 10.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: uiConfigData?.selectedColor ?? AppColors.brand,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(width: 8.w),

            /// --- Title + Subtitle ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title ?? '',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            letterSpacing: -0.24,
                          ),
                    ),
                  ),
                  if (uiConfigData?.subtitle != null) ...[
                    SizedBox(height: 6.h),
                    Text(
                      uiConfigData?.subtitle ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            letterSpacing: -0.24,
                            color: AppColors.n70,
                          ),
                    ),
                  ],
                ],
              ),
            ),

            /// --- Trailing icon/text ---
            RemoteImageHandler(
              imageUrl: uiConfigData?.trailingIcon?.cdn ?? '',
              width: 24.r,
              errorWidget: const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
