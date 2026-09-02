import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Reusable progress indicator for Go Live V2 flow
/// Shows progress as a horizontal bar divided into segments
class GoLiveProgressIndicator extends StatelessWidget {
  /// Current step (1-4)
  final int currentStep;

  /// Total steps in the flow (default: 4)
  final int totalSteps;

  const GoLiveProgressIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  }) : assert(currentStep > 0 && currentStep <= totalSteps,
            'currentStep must be between 1 and totalSteps');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Row(
        children: List.generate(
          totalSteps,
          (index) => Expanded(
            child: Container(
              height: 4.h,
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              decoration: BoxDecoration(
                color: index < currentStep ? AppColors.brand : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
