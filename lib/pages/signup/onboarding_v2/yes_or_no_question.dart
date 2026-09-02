import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_v2/onboarding_button.dart';
import 'package:snabbit_runner/pages/signup/onboarding_v2/onboarding_single_question_screen.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class YesOrNoQuestion extends StatefulWidget {
  final OnboardingQuestionData questionData;
  final Widget questionHeader;
  final Function(int)? onOptionTapped;
  final Widget? floatingActionButton;
  final AppBar appBar;
  final Color backgroundColor;
  final bool isLoading;

  const YesOrNoQuestion({
    super.key,
    required this.questionData,
    this.onOptionTapped,
    this.floatingActionButton,
    required this.questionHeader,
    required this.appBar,
    required this.backgroundColor,
    required this.isLoading,
  });

  @override
  State<YesOrNoQuestion> createState() => _YesOrNoQuestionState();
}

class _YesOrNoQuestionState extends State<YesOrNoQuestion> {
  @override
  Widget build(BuildContext context) {
    final question = widget.questionData;
    final List<OptionUIConfig?>? optionsUIConfig =
        question.optionObjects?.map((option) => option.uiConfig).toList();
    late final SingleQuestionUiConfig? uiConfig;
    if (question.uiConfig != null) {
      uiConfig = SingleQuestionUiConfig.fromJson(question.uiConfig);
    }

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: widget.appBar,
      floatingActionButton:
          widget.isLoading ? null : widget.floatingActionButton,
      persistentFooterButtons: widget.isLoading
          ? null
          : [
              Padding(
                padding: EdgeInsets.fromLTRB(28.5.w, 0, 28.5.w, 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OnboardingOptionButton(
                      uiConfig: optionsUIConfig?.isNotEmpty == true
                          ? optionsUIConfig?.first
                          : null,
                      onTap: () => widget.onOptionTapped?.call(0),
                      fallbackColor: const Color(0xFFC50F1F),
                      fallbackText: "No",
                      fallbackIcon: "onboarding/onboarding_no_button.svg",
                      fallbackErrorIcon: Icons.close,
                    ),
                    SizedBox(width: 40.w),
                    OnboardingOptionButton(
                      uiConfig: optionsUIConfig?.length == 2
                          ? optionsUIConfig?.last
                          : null,
                      onTap: () => widget.onOptionTapped?.call(1),
                      fallbackColor: const Color(0xFF37A660),
                      fallbackText: "Yes",
                      fallbackIcon: "onboarding/onboarding_yes_button.svg",
                      fallbackErrorIcon: Icons.check,
                    ),
                  ],
                ),
              ),
            ],
      body: widget.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                widget.questionHeader,
                SizedBox(height: 50.h),
                if (uiConfig?.imageUrl != null &&
                    uiConfig!.imageUrl!.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 27.h, horizontal: 52.w),
                      child: RemoteImageHandler(
                        imageUrl: uiConfig.imageUrl!.cdn,
                        fit: BoxFit.fitWidth,
                        width: 1.sw,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
