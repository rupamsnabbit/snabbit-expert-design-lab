import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/job_login/selfie_login.dart';

class SelfieError extends StatefulWidget {
  final List<String> errors;

  const SelfieError({
    super.key,
    required this.errors,
  });

  @override
  State<SelfieError> createState() => _SelfieErrorState();
}

class _SelfieErrorState extends State<SelfieError> {
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  bool init = true;
  final String _uniformMissing = "uniform_not_detected";
  final String _bikeMissing = "bike_not_detected";
  final String _helmetMissing = "helmet_not_detected";
  final String _faceMismatch = "face_mismatch";
  final String _faceNotDetected = "face_not_detected";

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      _trackLoginError();
    }
    super.didChangeDependencies();
  }

  void _trackLoginError() {
    final props = <String, dynamic>{
      'error_types': widget.errors,
      'error_count': widget.errors.length,
    };
    MixpanelSetup.logEvent(TrackingEvents.loginError, props);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        //uniform not visible
        if (widget.errors.contains(_uniformMissing))
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Image.asset(
                    AssetConstants.uniform,
                    height: 28.h,
                  ),
                ),
                Flexible(
                  child: Text(
                    languageProvider.getMessage(
                      _uniformMissing,
                      "Uniform is not visible",
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                )
              ],
            ),
          ),
        //bike not visible
        if (widget.errors.contains(_bikeMissing))
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Image.asset(
                    AssetConstants.bike,
                    height: 28.h,
                  ),
                ),
                Flexible(
                  child: Text(
                    languageProvider.getMessage(
                      _bikeMissing,
                      "Your Bike is not visible",
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                )
              ],
            ),
          ),
        //helmet not visible
        if (widget.errors.contains(_helmetMissing))
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Image.asset(
                    AssetConstants.helmet,
                    height: 28.h,
                  ),
                ),
                Flexible(
                  child: Text(
                    languageProvider.getMessage(
                      _helmetMissing,
                      "Your Helmet is not visible",
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                )
              ],
            ),
          ),
        //face mismatch
        if (widget.errors.contains(_faceMismatch))
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Image.asset(
                    AssetConstants.faceMismatch,
                    height: 28.h,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                ),
                Flexible(
                  child: Text(
                    languageProvider.getMessage(
                      _faceMismatch,
                      "Face did not match. Please try again.",
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                )
              ],
            ),
          ),
        //face not detected
        if (widget.errors.contains(_faceNotDetected))
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Image.asset(
                    AssetConstants.faceMismatch,
                    height: 28.h,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                ),
                Flexible(
                  child: Text(
                    languageProvider.getMessage(
                      _faceNotDetected,
                      "No face found.Please adjust and retry.",
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                )
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Image.asset(
            userProfileProvider.user?.alternateDeliveryMethod ==
                    AlternateDeliveryMethod.yulu
                ? AssetConstants.selfieAdmYulu
                : AssetConstants.selfieAdmFoot,
            height: 169.92.h,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  languageProvider.getMessage(
                    "correct_selfie_method",
                    "Correct way to take a photo",
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 4.w),
                child: CircleAvatar(
                  backgroundColor: AppColors.g50,
                  radius: 10.5.r,
                  child: Icon(
                    Icons.check,
                    color: AppColors.n0,
                    size: 10.r,
                  ),
                ),
              )
            ],
          ),
        ),
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: () {
              Navigator.popUntil(
                context,
                (route) => route.settings.name == SelfieForLogin.routeName,
              );
            },
            child: FittedBox(
              child: Text(
                languageProvider.getMessage(
                  "retake_photo",
                  "Retake Photo",
                ),
              ),
            ),
          ),
        )
      ],
    );
  }
}
