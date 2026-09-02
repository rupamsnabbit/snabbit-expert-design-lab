import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

/// Dart model representing the configuration data for a radio options widget.
class RadioOptionsData {
  final dynamic selectedOption;
  final bool? enabled;

  // Color properties (expected to be hex codes as strings)
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final Color? selectedRadioBorderColor;
  final Color? unselectedRadioBorderColor;
  final Color? selectedRadioFillColor;

  RadioOptionsData({
    this.enabled,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.selectedRadioBorderColor,
    this.unselectedRadioBorderColor,
    this.selectedRadioFillColor,
    this.selectedOption,
  });

  /// Factory constructor to create a RadioOptionsData instance from a JSON map.
  /// NOTE: This implementation relies on the JSON map providing the exact
  /// expected types for each key, as there is no type casting or validation.
  factory RadioOptionsData.fromJson(Map<String, dynamic> json) {
    return RadioOptionsData(
      // String fields
      selectedTextColor: hexToColor(json['selected_text_color']),
      unselectedTextColor: hexToColor(json['unselected_text_color']),
      selectedRadioBorderColor: hexToColor(json['selected_radio_border_color']),
      unselectedRadioBorderColor:
          hexToColor(json['unselected_radio_border_color']),
      selectedRadioFillColor: hexToColor(json['selected_radio_fill_color']),
      selectedOption: json['selected_option'],
      // Boolean fields
      enabled: json['enabled'],
    );
  }
}

class RadioOptions extends StatefulWidget {
  final OnboardingQuestionData? data;
  final Function(dynamic)? onSelected;
  final int? initialOptionId;

  const RadioOptions({
    super.key,
    this.data,
    this.onSelected,
    this.initialOptionId,
  });

  @override
  State<RadioOptions> createState() => _RadioOptionsState();
}

class _RadioOptionsState extends State<RadioOptions> {
  OnboardingQuestionOption? selectedOption;
  RadioOptionsData? uiConfigData;
  @override
  void initState() {
    super.initState();
    try {
      uiConfigData = RadioOptionsData.fromJson(widget.data?.uiConfig ?? {});
    } catch (_) {}

    // If an initialOptionId is passed, find and preselect the matching option
    if (widget.initialOptionId != null &&
        (widget.data?.optionObjects?.isNotEmpty ?? false)) {
      selectedOption = widget.data!.optionObjects!.firstWhere(
            (opt) => opt.id == widget.initialOptionId,
      );
      if (selectedOption?.id == null) {
        selectedOption = null;
      }
    } else {
      // fallback to UI-config default selected option
      selectedOption = uiConfigData?.selectedOption;
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingQuestion(
      mandatory: widget.data?.mandatory,
      questionKey: widget.data?.question ?? '',
      questionDefault: widget.data?.question ?? '',
      answer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8.h),
          Wrap(
            runSpacing: 20.h,
            children: (widget.data?.optionObjects ?? []).map(
              (OnboardingQuestionOption option) {
                return Padding(
                  padding: EdgeInsets.only(right: 24.w),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedOption = option;
                      });
                      if (widget.onSelected != null) {
                        widget.onSelected!(option);
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 8.w, // spacing between checkbox and text
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularCheckbox(
                          value: selectedOption?.id == option.id,
                          borderColor: AppColors.n40,
                        ),
                        Flexible(
                          child: Text(
                            option.text ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }
}
