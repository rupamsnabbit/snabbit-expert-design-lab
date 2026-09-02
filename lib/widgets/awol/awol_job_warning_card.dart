import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/awol/awol_models.dart';
import '../../providers/language_provider.dart';
import '../../utils/colors.dart';
import 'awol_view_helper.dart';

/// Warning card that wraps job location details when AWOL data is active.
///
/// Color depends on timer state:
/// - Yellow (Y10 bg, Y20 border): timer running (default)
/// - Red (R10 bg, R20 border): timer in red state or expired
enum AwolWarningState {
  yellow,
  red;

  Color get bgColor => this == red ? AppColors.r10 : AppColors.y10;
  Color get borderColor => this == red ? AppColors.r20 : AppColors.y20;
}

class AwolJobWarningCard extends StatelessWidget {
  final AwolData awolData;
  final LanguageProvider languageProvider;
  final AwolWarningState warningState;
  final Widget child;

  const AwolJobWarningCard({
    super.key,
    required this.awolData,
    required this.languageProvider,
    this.warningState = AwolWarningState.yellow,
    required this.child,
  });

  AwolViewHelper get _helper => AwolViewHelper(data: awolData, lp: languageProvider);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: warningState.bgColor,
        border: Border.all(color: warningState.borderColor),
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                Text(
                  _helper.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.r60,
                    letterSpacing: -0.44,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _helper.warning,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.r60,
                    height: 15 / 12,
                    letterSpacing: -0.15,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }
}