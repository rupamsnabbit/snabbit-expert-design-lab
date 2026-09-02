import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

class HorizontalMultiSelectData {
  final String? trailingIcon;
  final bool? enabled;

  // Color properties (expected to be hex codes as strings)
  final Color? textColor;
  final Color? borderColor;
  final Color? activeBorderColor;
  final Color? activeTextColor;
  final dynamic selectedOption;

  HorizontalMultiSelectData({
    this.trailingIcon,
    this.enabled,
    this.textColor,
    this.borderColor,
    this.activeBorderColor,
    this.activeTextColor,
    this.selectedOption,
  });

  /// Factory constructor to create a HorizontalMultiSelectData instance from a JSON map.
  /// NOTE: This implementation relies on the JSON map providing the exact
  /// expected types for each key, as there is no type casting or validation.
  factory HorizontalMultiSelectData.fromJson(Map<String, dynamic> json) {
    return HorizontalMultiSelectData(
      trailingIcon: json['trailing_icon'],
      textColor: hexToColor(json['text_color']),
      borderColor: hexToColor(json['border_color']),
      activeBorderColor: hexToColor(json['active_border_color']),
      activeTextColor: hexToColor(json['active_text_color']),
      enabled: json['enabled'],
      selectedOption: json['selected_option'],
    );
  }
}

class HorizontalMultiSelect extends StatefulWidget {
  final OnboardingQuestionData? data;
  final Function(dynamic)? onSelected;
  final int? initialOptionId;

  const HorizontalMultiSelect({
    super.key,
    this.data,
    this.onSelected,
    this.initialOptionId,
  });

  @override
  State<HorizontalMultiSelect> createState() => _HorizontalMultiSelectState();
}

class _HorizontalMultiSelectState extends State<HorizontalMultiSelect> {
  dynamic selectedOption;
  HorizontalMultiSelectData? uiConfigData;

  @override
  void initState() {
    super.initState();
    try {
      uiConfigData =
          HorizontalMultiSelectData.fromJson(widget.data?.uiConfig ?? {});
    } catch (_) {}

    // If an initialOptionId is provided, set the matching option as selected
    if (widget.initialOptionId != null &&
        (widget.data?.optionObjects?.isNotEmpty ?? false)) {
      selectedOption = widget.data!.optionObjects!.firstWhere(
          (opt) => opt.id == widget.initialOptionId,
          orElse: () => OnboardingQuestionOption());
      if (selectedOption?.id == null) {
        selectedOption = null;
      }
    } else {
      // Fall back to UI config’s preselected option if defined
      selectedOption = uiConfigData?.selectedOption;
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingQuestion(
      questionKey: widget.data?.question ?? '',
      questionDefault: widget.data?.question ?? '',
      mandatory: widget.data?.mandatory,
      answer: Row(
        children: (widget.data?.optionObjects ?? []).map(
          (OnboardingQuestionOption option) {
            return Flexible(
              flex: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedOption = option;
                    });
                    if (widget.onSelected != null) {
                      widget.onSelected!(option);
                    }
                  },
                  child: Container(
                    height: 48.h,
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedOption == null
                            ? AppColors.n60
                            : option == selectedOption
                                ? uiConfigData?.activeBorderColor ??
                                    AppColors.brand
                                : uiConfigData?.borderColor ?? AppColors.n60,
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                      color: AppColors.n0,
                    ),
                    child: Center(
                      child: Text(
                        option.text.toString(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: uiConfigData?.activeTextColor ??
                                  AppColors.n80,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }
}
