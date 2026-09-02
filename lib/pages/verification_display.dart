import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/login/send_otp.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import '../utils/colors.dart';

class VerificationDisplay extends StatefulWidget {
  static const String routeName = "/verification_display";

  const VerificationDisplay({super.key, this.status});

  final RunnerState? status;

  @override
  State<VerificationDisplay> createState() => _VerificationDisplayState();
}

class _VerificationDisplayState extends State<VerificationDisplay> {
  bool initialized = false;
  String? title;
  String? subtitle;
  String? image;
  Widget? actionButton;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  bool showDefaultView = false;

  @override
  void didChangeDependencies() {
    userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: true);
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    super.didChangeDependencies();
    initializeUI();
  }

  void initializeUI() {
    switch (userProfileProvider.user?.runnerStatus) {
      case RunnerState.ON_HOLD:
      case RunnerState.SUSPENDED:
        title = languageProvider.getMessage(
            "verification_suspended_title", "Please Wait");
        subtitle = languageProvider.getMessage("verification_suspended_subtitle",
            "Your documents are being verified");
        image = AssetConstants.verificationSuspended;
        actionButton = null;
        break;
      case RunnerState.FAILED:
        title = languageProvider.getMessage(
            "verification_rejected_title", "Sorry!");
        subtitle = languageProvider.getMessage("verification_rejected_subtitle",
            "You have not passed the Registration Process");
        image = AssetConstants.verificationFailed;
        actionButton = Container(
            width: 1.sw,
            padding: EdgeInsets.symmetric(vertical: 14.5.h),
            margin: EdgeInsets.symmetric(
              vertical: 16.h,
            ),
            alignment: Alignment.center,
            color: AppColors.r10,
            child: Text(
              languageProvider.getMessage("verification_rejected_action",
                  "Please try again in 3 months"),
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(color: AppColors.r50),
            ));
        break;
      case RunnerState.ACTIVE:
        title = languageProvider.getMessage(
            "verification_successful_title", "Congratulations!");
        subtitle = languageProvider.getMessage(
            "verification_successful_subtitle",
            "You have successfully passed the Registration Process");
        image = AssetConstants.verificationSuccessful;
        actionButton = Container(
          margin: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
          width: 1.sw,
          child: ElevatedButton(
              onPressed: () {},
              child: Text(
                languageProvider.getMessage(
                    "verification_successful_action", "Register for training"),
              )),
        );
        break;
      // case RunnerState.FAILED:
      //   subtitle = "Unfortunately, you have failed the Registration Process.";
      //   image = AssetConstants.instantRejection;
      //   break;
      default:
        showDefaultView = true;
        break;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: userProfileProvider.user?.runnerStatus == null
            ? const Center(
                child: Text("Invalid Expert status. Contact Support.")
              )
            : showDefaultView
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/verification.png',
                          height: 141.h,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48.0, vertical: 24),
                          child: Text(
                            'While you complete the training process, we will ensure your documents are verified.',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Gap.gap48h,
                        FloatingActionButton.extended(
                          heroTag: 'verification_pending_fab_tag',
                          elevation: 0.0,
                          onPressed: () async {
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            prefs.remove("access_token");
                            prefs.remove("registration_completed");
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (context) => const SendOtp()),
                                (route) => false);
                          },
                          label: const Text('Logout'),
                        )
                      ],
                    ),
                  )
                : Center(
                  child: RegistrationStatus(
                      title: title,
                      subtitle: subtitle,
                      actionButton: actionButton,
                      image: image,
                    ),
                ),
        floatingActionButtonLocation: showDefaultView?FloatingActionButtonLocation.centerFloat:null,
        floatingActionButton:showDefaultView? const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: FloatingActionButton.extended(
              backgroundColor:
                  // continueCondtions() ? AppColors.brand :
                  AppColors.n50,
              onPressed:
                  // continueCondtions()
                  //     ? () {
                  //         Navigator.of(context).pushNamed('/family_details');
                  //       }
                  //     :
                  null,
              elevation: 0.0,
              label: Text(
                "Start working",
                style: TextStyle(
                    color:
                        //  continueCondtions() ? Colors.white :
                        Colors.black54),
              ),
            ),
          ),
        ):null,
      ),
    );
  }
}

class RegistrationStatus extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? image;
  final Widget? actionButton;

  const RegistrationStatus({
    super.key,
    this.title,
    this.subtitle,
    this.image,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (image != null)
          Padding(
            padding: EdgeInsets.only(
              bottom: 16.h,
            ),
            child: Image.asset(
              image!,
              width: 141.r,
            ),
          ),
        if (title != null)
          Padding(
            padding: EdgeInsets.only(
              top: 16.h,
            ),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        if (subtitle != null)
          Padding(
            padding: EdgeInsets.only(
                top: 12.h, bottom: 24.h, left: 42.w, right: 42.w),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        if (actionButton != null)
          actionButton!,
      ],
    );
  }
}
