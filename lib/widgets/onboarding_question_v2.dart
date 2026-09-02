import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

class OnboardingQuestionV2 extends StatefulWidget {
  final String questionKey;
  final String questionDefault;
  final String? questionSubtitle;
  final Widget answer;
  final String? error;
  final bool? mandatory;
  final double? qaGap;
  final Widget? questionTrailingItem;
  final String? criticalError;
  final TextStyle? questionTextStyle;
  final EdgeInsetsGeometry? padding;
  final bool? isEnabled;

  const OnboardingQuestionV2({
    super.key,
    required this.questionKey,
    required this.questionDefault,
    this.questionSubtitle,
    required this.answer,
    this.error,
    this.mandatory,
    this.qaGap,
    this.criticalError,
    this.questionTrailingItem,
    this.questionTextStyle,
    this.padding,
    this.isEnabled,
  });

  @override
  State<OnboardingQuestionV2> createState() => _OnboardingQuestionV2State();
}

class _OnboardingQuestionV2State extends State<OnboardingQuestionV2> {
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

  Color get questionColor {
    if (widget.isEnabled == null) {
      return AppColors.n90;
    } else if (widget.isEnabled!) {
      return AppColors.n90;
    } else {
      return AppColors.n40;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.error != null || _showCriticalError
          ? AppColors.r0
          : AppColors.n0,
      padding: widget.padding ??
          EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 4.h,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: languageProvider.getMessage(
                          widget.questionKey,
                          widget.questionDefault,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.merge(widget.questionTextStyle)
                            .copyWith(color: questionColor),
                      ),
                      if (widget.mandatory == true)
                        TextSpan(
                          text: "*",
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.merge(widget.questionTextStyle)
                              .copyWith(color: questionColor),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.questionTrailingItem != null)
                Flexible(
                  child: widget.questionTrailingItem ?? const SizedBox.shrink(),
                )
            ],
          ),
          if (widget.questionSubtitle != null)
            Text(
              widget.questionSubtitle ?? "",
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 11.sp),
            ),
          SizedBox(height: widget.qaGap ?? 4.h),
          if (widget.error != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Text(
                widget.error ?? "",
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.r50),
              ),
            ),
          SizedBox(height: 4.h),
          widget.answer,
          if (_showCriticalError)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                widget.criticalError ?? "",
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.r50),
              ),
            )
        ],
      ),
    );
  }

  bool get _showCriticalError =>
      widget.error == null && widget.criticalError != null;
}
