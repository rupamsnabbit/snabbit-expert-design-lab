import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/auto_ot/auto_ot_status.dart';
import 'package:snabbit_runner/widgets/auto_ot/new_ming_conditions.dart';
import '../../../providers/auto_ot_provider.dart';
import '../../../services/remote_config/remote_config_assets.dart';
import '../../../utils/colors.dart';
import '../../../widgets/remote_image_handler.dart';

/// Confirmation state widget for Auto-OT bottom sheet
///
/// Displays confirmation screen with side-by-side comparison cards.
class ConfirmStateWidget extends StatelessWidget {
  final OtType otType;

  const ConfirmStateWidget({
    super.key,
    this.otType = OtType.EndOt,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AutoOtProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final details = provider.details;

    if (details == null) {
      return const SizedBox.shrink();
    }

    final regularShift = details.regularShift;
    final otShift = details.otShift;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 24.h),

          // Title
          Text(
            languageProvider.getMessage('are_you_sure?', 'Are you sure?'),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 22 / 22,
                  color: AppColors.n90,
                  letterSpacing: -0.24,
                ),
          ),

          SizedBox(height: 20.h),

          // "Only for today" banner
          AutoOtStatusView(
            margin: EdgeInsets.symmetric(horizontal: 20.w),
            otType: otType,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: NewMinGConditions(),
          ),

          // Side-by-side cards
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                // Left card - New Shift Timing
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.g10,
                      border: Border.all(color: AppColors.g30, width: 2),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 16.h),
                        RemoteImageHandler(
                          imageUrl: RemoteConfigAssets.newShiftTimingIcon,
                          height: 36.h,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          languageProvider.getMessage(
                              'new_shift_timing', 'New Shift Timing'),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                height: 14 / 14,
                                color: AppColors.n90,
                                letterSpacing: -0.24,
                              ),
                        ),
                        Divider(
                          color: AppColors.n90.withValues(alpha: 0.1),
                          thickness: 1.6.r,
                        ),
                        FittedBox(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.g20,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              provider.formatTimeRange(
                                  otShift?.startTime, otShift?.endTime),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                    fontSize: 16.sp,
                                    height: 16 / 16,
                                    color: AppColors.n90,
                                    letterSpacing: -0.24,
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        FittedBox(
                          child: Text(
                            " ${provider.formatTimeRange(regularShift?.startTime, regularShift?.endTime)} ",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  height: 13 / 13,
                                  color: Color(0xFF626F84),
                                  letterSpacing: -0.24,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xFF626F84),
                                  decorationThickness: 3.09.r,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: 13.w),

                // Right card - New MinG
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.g10,
                      border: Border.all(color: AppColors.g30, width: 2),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 16.h),
                        RemoteImageHandler(
                          imageUrl: RemoteConfigAssets.newMingIcon,
                          height: 36.h,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          languageProvider.getMessage('new_ming', 'New MinG'),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                height: 14 / 14,
                                color: AppColors.n90,
                                letterSpacing: -0.24,
                              ),
                          textAlign: TextAlign.right,
                        ),
                        Divider(
                          color: AppColors.n90.withValues(alpha: 0.1),
                          thickness: 1.6.r,
                        ),
                        FittedBox(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.g20,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              formatIndianCurrency(
                                  anyValueToInt(otShift?.ming)),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                    fontSize: 16.sp,
                                    height: 16 / 16,
                                    color: AppColors.n90,
                                    letterSpacing: -0.24,
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        FittedBox(
                          child: Text(
                            " ${formatIndianCurrency(anyValueToInt(regularShift?.ming))} ",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  height: 13 / 13,
                                  color: Color(0xFF626F84),
                                  letterSpacing: -0.24,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xFF626F84),
                                  decorationThickness: 3.09.r,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // Action buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                // Request Overtime button
                SizedBox(
                  width: 361.w,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      provider.submitRequest();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.autoOtButtonGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      languageProvider.getMessage(
                          'request_overtime', 'Request Overtime'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 20 / 15,
                            color: AppColors.n0,
                            letterSpacing: -0.24,
                          ),
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                // Go back button
                SizedBox(
                  width: 361.w,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      provider.goBackToInitial();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandInverted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      languageProvider.getMessage('go_back', 'Go back'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            height: 20 / 15,
                            color: AppColors.n90,
                            letterSpacing: -0.24,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 17.h),
        ],
      ),
    );
  }
}
