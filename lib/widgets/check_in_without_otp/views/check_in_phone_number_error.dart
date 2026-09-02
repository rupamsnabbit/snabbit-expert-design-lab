import 'package:comm_stream/comm_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import '../models/check_in_without_otp_bottom_sheet_view.dart';
import '../providers/check_in_without_otp_provider.dart';

class CheckInWithoutOtpPhoneNumberError extends StatelessWidget {
  const CheckInWithoutOtpPhoneNumberError({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LanguageProvider, CheckInWithoutOtpProvider>(
        builder: (context, languageProvider, verifyCheckInPhoneProvider, _) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 24.h,),
          RemoteImageHandler(
            imageUrl: RemoteConfigAssets.checkInPhoneNumberError,
            height: 52.h,
            errorWidget: const SizedBox(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 63.3.w),
            child: Text(
              languageProvider.getMessage(
                'check_in_phone_number_error_title',
                "Phone number doesn't match this booking.",
              ),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.r40),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              width: 1.sw,
              height: 48.h,
              child: FilledButton(
                onPressed: () {
                  ClevertapSetup.logEvent(TrackingEvents.checkInWithoutOtpPhoneNumberErrorRetryClicked, {});
                  verifyCheckInPhoneProvider.setView(
                      CheckInWithoutOtpBottomSheetView.enterPhoneNumber);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.n90,
                  foregroundColor: AppColors.n0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    languageProvider.getMessage(
                      'check_in_location_error_action_btn_txt',
                      'Try again',
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.n0,
                          letterSpacing: -0.24,
                        ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
        ],
      );
    });
  }
}
