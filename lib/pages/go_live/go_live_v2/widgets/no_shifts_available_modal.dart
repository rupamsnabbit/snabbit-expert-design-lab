import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

class GoLiveErrorModal extends StatelessWidget {
  final String title;
  final String subtitle;

  const GoLiveErrorModal({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          SizedBox(height: 8.h),
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.n90,
              borderRadius: BorderRadius.circular(100.r),
            ),
          ),
          SizedBox(height: 24.h),

          // Warning icon
          SizedBox(
            width: 70.w,
            height: 70.h,
            child: Image.asset(AssetConstants.fpWarningPng),
          ),
          SizedBox(height: 24.h),

          // Title
          Text(
            title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF000000),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),

          // Subtitle
          Text(
            subtitle,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.n80,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),

          // Okay Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Consumer<LanguageProvider>(
                    builder: (context, languageProvider, _) => Text(
                      languageProvider.getMessage(
                        'go_live_v2_okay',
                        'Okay',
                      ),
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.n0,
                        letterSpacing: -0.24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}

void showGoLiveErrorModal(
  BuildContext context, {
  required String title,
  required String subtitle,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GoLiveErrorModal(title: title, subtitle: subtitle),
    ),
  );
}

/// Convenience function for NO_SHIFTS_AVAILABLE error
void showNoShiftsAvailableModal(BuildContext context) {
  final languageProvider =
      Provider.of<LanguageProvider>(context, listen: false);
  showGoLiveErrorModal(
    context,
    title: languageProvider.getMessage(
      'go_live_v2_no_slots_available',
      'No slots available as per\nyour preference',
    ),
    subtitle: languageProvider.getMessage(
      'go_live_v2_go_back_change_preferences',
      'Please change your preferences and try again.',
    ),
  );
}

/// Convenience function for SHIFT_NOT_AVAILABLE error
void showShiftNotAvailableModal(BuildContext context) {
  final languageProvider =
      Provider.of<LanguageProvider>(context, listen: false);
  showGoLiveErrorModal(
    context,
    title: languageProvider.getMessage(
      'go_live_v2_slot_unavailable',
      'This slot is unavailable',
    ),
    subtitle: languageProvider.getMessage(
      'go_live_v2_choose_another',
      'Please choose another',
    ),
  );
}
