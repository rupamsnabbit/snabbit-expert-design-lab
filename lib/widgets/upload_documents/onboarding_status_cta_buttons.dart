import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/utils/colors.dart';

class OnboardingStatusCtaButtons extends StatelessWidget {
  const OnboardingStatusCtaButtons({
    super.key,
    this.actions,
    this.onActionTap,
  });

  final List<CtaActions>? actions;
  final void Function(String?)? onActionTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (actions == null || actions!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (int i = 0; i < actions!.length; i++) ...[
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: () => onActionTap?.call(actions![i].task),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                actions![i].backgroundColor ?? _defaultBackground(i),
                foregroundColor:
                actions![i].foregroundColor ?? _defaultForeground(i),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: Text(
                actions![i].label ?? '',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                  actions![i].foregroundColor ?? _defaultForeground(i),
                ),
              ),
            ),
          ),
          if (i != actions!.length - 1) SizedBox(height: 10.h),
        ],
      ],
    );
  }

  Color _defaultBackground(int index) {
    return index == 0 ? AppColors.brand : AppColors.n20;
  }

  Color _defaultForeground(int index) {
    return index == 0 ? AppColors.n0 : AppColors.brand;
  }
}
