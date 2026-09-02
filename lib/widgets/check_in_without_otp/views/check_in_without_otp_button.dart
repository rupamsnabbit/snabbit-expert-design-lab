import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/check_in_without_otp/views/check_in_without_otp_bottom_sheet.dart';
import '../../../utils/colors.dart';

class CheckInWithoutOtpButton extends StatefulWidget {
  const CheckInWithoutOtpButton({super.key});

  @override
  State<CheckInWithoutOtpButton> createState() =>
      _CheckInWithoutOtpButtonState();
}

class _CheckInWithoutOtpButtonState extends State<CheckInWithoutOtpButton> {
  @override
  void initState() {
    super.initState();
    ClevertapSetup.logEvent(TrackingEvents.checkInWithoutOtpBtnDisplayed, {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (
      context,
      provider,
      child,
    ) {
      return GestureDetector(
        onTap: () {
          ClevertapSetup.logEvent(TrackingEvents.checkInWithoutOtpBtnClicked, {});
          showCheckInWithoutOtpBottomSheet(context);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38.h,
          margin: EdgeInsets.only(top: 10.h),
          alignment: Alignment.center,
          child: Text(
            provider.getMessage("no_otp", "No OTP"),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 18 / 13,
                  // line-height from Figma
                  color: AppColors.r50,
                  decoration: TextDecoration.underline,
                  decorationThickness: 1.5.r,
                  decorationColor: AppColors.r50,
                ),
          ),
        ),
      );
    });
  }
}
