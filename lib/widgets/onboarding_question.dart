import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

class OnboardingQuestion extends StatefulWidget {
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
  final TextStyle? questionSubtitleTextStyle;
  final EdgeInsetsGeometry? padding;

  const OnboardingQuestion({
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
    this.questionSubtitleTextStyle,
    this.padding,
  });

  @override
  State<OnboardingQuestion> createState() => _OnboardingQuestionState();
}

class _OnboardingQuestionState extends State<OnboardingQuestion> {
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
    return Container(
      color: widget.error != null || _showCriticalError
          ? AppColors.r0
          : AppColors.n0,
      padding: widget.padding ??
          EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 8.h,
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
                            .labelMedium
                            ?.copyWith(fontSize: 14.sp)
                            .merge(widget.questionTextStyle),
                      ),
                      if (widget.mandatory == true)
                        TextSpan(
                          text: " *",
                          style: Theme.of(context).textTheme.labelMedium,
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
                  ?.copyWith(fontSize: 11.sp)
                  .merge(widget.questionSubtitleTextStyle),
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
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Text(
                widget.criticalError ?? "",
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
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

class OnboardingPageHeaderV2 extends StatefulWidget {
  final String? title;
  final String? description;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final EdgeInsetsGeometry? padding;

  const OnboardingPageHeaderV2({
    super.key,
    this.title,
    this.description,
    this.titleStyle,
    this.subtitleStyle,
    this.padding,
  });

  @override
  State<OnboardingPageHeaderV2> createState() => _OnboardingPageHeaderV2State();
}

class _OnboardingPageHeaderV2State extends State<OnboardingPageHeaderV2> {
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
    return Padding(
      padding: widget.padding ?? EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null)
            Text(
              widget.title!,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.merge(widget.titleStyle),
            ),
          if (widget.description != null) ...[
            SizedBox(height: 8.h),
            Text(
              widget.description!,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.merge(widget.subtitleStyle),
            ),
          ]
        ],
      ),
    );
  }
}

class OnboardingPageHeader extends StatefulWidget {
  final String titleKey;
  final String titleDefault;
  final String subtitleKey;
  final String subtitleDefault;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final EdgeInsetsGeometry? padding;

  const OnboardingPageHeader({
    super.key,
    required this.titleKey,
    required this.titleDefault,
    required this.subtitleKey,
    required this.subtitleDefault,
    this.titleStyle,
    this.subtitleStyle,
    this.padding,
  });

  @override
  State<OnboardingPageHeader> createState() => _OnboardingPageHeaderState();
}

class _OnboardingPageHeaderState extends State<OnboardingPageHeader> {
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
    return Padding(
      padding: widget.padding ?? EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getMessage(
              widget.titleKey,
              widget.titleDefault,
            ),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.merge(widget.titleStyle),
          ),
          Text(
            languageProvider.getMessage(
              widget.subtitleKey,
              widget.subtitleDefault,
            ),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.merge(widget.subtitleStyle),
          ),
        ],
      ),
    );
  }
}
