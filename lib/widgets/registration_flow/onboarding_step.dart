import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/onboarding_module.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class OnboardingStep extends StatefulWidget {
  final Module data;
  final int stepNumber;
  final VoidCallback onCtaTap;
  const OnboardingStep({
    super.key,
    required this.data,
    required this.stepNumber,
    required this.onCtaTap,
  });

  @override
  State<OnboardingStep> createState() => _OnboardingStepState();
}

class _OnboardingStepState extends State<OnboardingStep> {
  bool init = true;
  late LanguageProvider _languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocked = widget.data.stepStatus == StepStatus.pending;
    final bool isActive = (widget.data.stepStatus == StepStatus.created) ||
        (widget.data.stepStatus == StepStatus.inProgress);
    final Color borderColor = widget.data.uiConfig.borderColor ??
        (isActive ? const Color(0xFFFDB5D5) : const Color(0xFFD8DADC));
    final Color buttonBgColor = widget.data.uiConfig.ctaColor ??
        (isLocked ? AppColors.brandInverted : AppColors.brand);
    final Color buttonTextColor = widget.data.uiConfig.ctaTextColor ??
        (isLocked ? AppColors.n60 : AppColors.n0);

    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.n0,
        border: Border.all(color: borderColor, width: 1.w),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Icon
                Container(
                  width: 30.w,
                  height: 30.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: RemoteImageHandler(
                      imageUrl: widget.data.uiConfig.moduleIcon?.cdn ?? '',
                      errorWidget: SizedBox(),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Text Column
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${widget.stepNumber}',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.n70,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _languageProvider.getMessage(
                            widget.data.name, widget.data.name),
                        style: textTheme.headlineSmall,
                      ),
                      SizedBox(height: 12.h),
                      // Button
                      widget.data.stepStatus == StepStatus.completed
                          ? Text(
                              _languageProvider.getMessage(
                                widget.data.uiConfig.ctaText ?? '',
                                widget.data.uiConfig.ctaText ?? '',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: widget.data.uiConfig.ctaColor ??
                                          AppColors.g40),
                            )
                          : ElevatedButton(
                              onPressed: isLocked ? null : widget.onCtaTap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonBgColor,
                                disabledBackgroundColor: buttonBgColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                padding: EdgeInsets.symmetric(
                                    vertical: 14.h, horizontal: 44.w),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _languageProvider.getMessage(
                                      widget.data.uiConfig.ctaText ?? '',
                                      widget.data.uiConfig.ctaText ?? ''),
                                  style: textTheme.labelLarge?.copyWith(
                                    color: buttonTextColor,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // Right side image placeholder
          SizedBox(
            width: 80.w,
            height: 80.h,
            child: RemoteImageHandler(
              imageUrl: widget.data.uiConfig.moduleImage?.cdn ?? '',
              errorWidget: SizedBox(),
            ),
          ),
        ],
      ),
    );
  }
}
