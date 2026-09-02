import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/check_in_without_otp/providers/check_in_without_otp_provider.dart';

class CheckInWithoutOtpPhoneEntryView extends StatefulWidget {

  /// Creates the phone entry view.
  const CheckInWithoutOtpPhoneEntryView({
    super.key,
  });

  @override
  State<CheckInWithoutOtpPhoneEntryView> createState() => _CheckInWithoutOtpPhoneEntryViewState();
}

class _CheckInWithoutOtpPhoneEntryViewState extends State<CheckInWithoutOtpPhoneEntryView> {
  /// Backing controller for the phone number input field.
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    ClevertapSetup.logEvent(TrackingEvents.checkInWithoutOtpPhoneNumberInputDisplayed, {});
  }


  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 17.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.n90,
      letterSpacing: -0.24,
    );

    final hintStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: 15.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.n90.withValues(alpha: 0.4),
      letterSpacing: -0.24,
    );

    final inputStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: 15.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.n90,
      letterSpacing: -0.24,
    );

    final buttonTextStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 15.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.n0,
      letterSpacing: -0.24,
    );

    return Consumer2<LanguageProvider,CheckInWithoutOtpProvider>(builder: (context, languageProvider, checkInWithoutOtpProvider, _) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 25.w),
            child: Text(
              languageProvider.getMessage("check_in_without_otp_title",
                  'Enter 10 digit customer phone number used for the booking'),
              style: titleStyle,
              textAlign: TextAlign.left,
            ),
          ),
          SizedBox(height: 28.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            child: SizedBox(
              height: 50.h,
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                style: inputStyle,
                onChanged: checkInWithoutOtpProvider.setPhoneNumber,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                maxLines: 1,
                decoration: InputDecoration(
                    hintText: languageProvider.getMessage(
                        'phone_number', 'Phone number'),
                    hintStyle: hintStyle,
                    filled: true,
                    fillColor: AppColors.n0,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 15.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide:
                      const BorderSide(color: AppColors.n40, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide:
                      const BorderSide(color: AppColors.n40, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide:
                      const BorderSide(color: AppColors.n40, width: 1),
                    ),
                    counter: const SizedBox(),),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              width: double.infinity,
              height: 48.h,
              child: FilledButton(
                onPressed: _canContinue() ? () => checkInWithoutOtpProvider.submit(context) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.g40,
                  foregroundColor: AppColors.n0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    languageProvider.getMessage(
                        'check_in_without_otp_action_btn_txt',
                        'Verify and start job'),
                    style: buttonTextStyle,
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

  bool _canContinue() {
    return _controller.text.length == 10;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}