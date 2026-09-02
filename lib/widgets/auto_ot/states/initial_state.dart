import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/auto_ot/auto_ot_models.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/auto_ot/auto_ot_status.dart';
import 'package:snabbit_runner/widgets/auto_ot/ot_shift.dart';
import 'package:snabbit_runner/widgets/auto_ot/todays_shift.dart';
import '../../../providers/auto_ot_provider.dart';
import '../../../services/remote_config/remote_config_assets.dart';
import '../../../utils/colors.dart';
import '../../../widgets/remote_image_handler.dart';

/// Initial state widget for Auto-OT bottom sheet
///
/// Displays the initial Auto-OT offer with regular shift and OT shift details.
class InitialStateWidget extends StatelessWidget {
  final OtType otType;

  const InitialStateWidget({
    super.key,
    this.otType = OtType.EndOt,
  });

  @override
  Widget build(BuildContext context) {
    final autoOtProvider = Provider.of<AutoOtProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    final details = autoOtProvider.details;

    if (details == null) {
      return const SizedBox.shrink();
    }

    final regularShift = details.regularShift;
    final otShift = details.otShift;
    final otShiftMing = otShift?.ming ?? 0;
    final regularShiftMing = regularShift?.ming ?? 0;
    final extraMing = otShiftMing - regularShiftMing;

    final String buttonLabel = otType == OtType.StartOt
        ? languageProvider.getMessage(
            'request_overtime_tomorrow', 'Request Overtime tomorrow')
        : languageProvider.getMessage(
            'request_overtime_today', 'Request Overtime today');

    final String title = otType == OtType.StartOt
        ? languageProvider.getMessage(
            'work_extra_time_tomorrow', 'Work extra time tomorrow,')
        : languageProvider.getMessage(
            'work_extra_time_today', 'Work extra time today,');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [
            0.0,
            311 / 669, // ≈ 0.465
          ],
          colors: [AppColors.autoOtGradientStart, AppColors.n0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 16.h),
          // Gradient header section
          // Header image
          RemoteImageHandler(
            imageUrl: RemoteConfigAssets.autoOtDetailsHeader,
            width: 145.w,
            errorWidget: const SizedBox.shrink(),
          ),
          // Headline text
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 28 / 24,
                  color: AppColors.autoOtTextPrimary,
                ),
          ),
          Text(
            languageProvider.getFormattedMessage(
                'earn_extra_time',
                'earn {{extraMing}} extra',
                {'extraMing': formatIndianCurrency(anyValueToInt(extraMing))}),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 28 / 24,
                  color: AppColors.autoOtButtonGreen,
                ),
          ),
          // "Only for today" banner
          AutoOtStatusView(
            otType: otType,
          ),
          // Shift details section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                // Regular shift card
                TodaysShiftView(
                  otType: otType,
                ),
                // "Your overtime shift" label with arrow
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RemoteImageHandler(
                        imageUrl: RemoteConfigAssets.downArrow,
                        height: 41.h,
                      ),
                      Container(
                        color: AppColors.n0,
                        child: Text(
                          languageProvider.getMessage(
                              'your_overtime_shift', 'Your overtime shift'),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                height: 14 / 14,
                                color: AppColors.n90.withValues(alpha: 0.5),
                                letterSpacing: -0.24,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                // OT shift card (highlighted)
                OtShiftView(),
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
                      autoOtProvider.showConfirmation();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.autoOtButtonGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: Text(
                      buttonLabel,
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

                // Close button
                SizedBox(
                  width: 361.w,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(AutoOtDenyReason.rejected);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.r40,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      languageProvider.getMessage('close', 'Close'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            height: 20 / 15,
                            color: AppColors.n0,
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
