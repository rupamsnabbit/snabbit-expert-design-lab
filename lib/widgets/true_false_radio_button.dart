import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

import '../providers/language_provider.dart';

class TrueFalseRadioButton extends StatefulWidget {
  final String question;
  final String? questionKey;
  final bool? mandatory;

  final void Function()? onOption1Tap;
  final void Function()? onOption2Tap;

  final bool checkBoxOption1Value;
  final bool checkBoxOption2Value;
  final String? option1;
  final String? option2;
  final String? criticalError;
  final String? questionSubtitle;
  final Widget? questionTrailingItem;

  const TrueFalseRadioButton({
    super.key,
    required this.question,
    this.questionKey,
    this.mandatory,
    required this.onOption1Tap,
    required this.onOption2Tap,
    required this.checkBoxOption1Value,
    required this.checkBoxOption2Value,
    this.option1,
    this.option2,
    this.questionSubtitle,
    this.questionTrailingItem,
    this.criticalError,
  });

  @override
  State<TrueFalseRadioButton> createState() => _TrueFalseRadioButtonState();
}

class _TrueFalseRadioButtonState extends State<TrueFalseRadioButton> {
  bool init = true;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingQuestion(
      questionKey: widget.questionKey ?? widget.question,
      questionDefault: widget.question,
      mandatory: widget.mandatory,
      criticalError: widget.criticalError,
      answer: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onOption1Tap,
            child: Row(
              children: [
                CircularCheckbox(value: widget.checkBoxOption1Value),
                Gap.gap8w,
                Text(
                  widget.option1 ??
                      languageProvider.getMessage(
                        'yes_option',
                        'Yes',
                      ),
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              ],
            ),
          ),
          Gap.gap32w,
          GestureDetector(
            onTap: widget.onOption2Tap,
            child: Row(
              children: [
                CircularCheckbox(value: widget.checkBoxOption2Value),
                Gap.gap8w,
                Text(
                  widget.option2 ??
                      languageProvider.getMessage(
                        'no_option',
                        'No',
                      ),
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              ],
            ),
          ),
        ],
      ),
      questionSubtitle: widget.questionSubtitle,
      questionTrailingItem: widget.questionTrailingItem,
    );
  }
}
