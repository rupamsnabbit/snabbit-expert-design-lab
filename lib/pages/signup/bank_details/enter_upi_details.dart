import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/bank_details/upi_details_screen.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/onboarding_question_v2.dart';
import 'package:snabbit_runner/widgets/text_form_v2.dart';

class EnterUpiDetails extends StatefulWidget {
  static const String routeName = "/enter_upi_details";
  const EnterUpiDetails({super.key});

  @override
  State<EnterUpiDetails> createState() => _EnterUpiDetailsState();
}

class _EnterUpiDetailsState extends State<EnterUpiDetails> {
  bool init = true;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  late UserProfile? userProfile;
  final TextEditingController upiIdController = TextEditingController();
  String? upiIdError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: false);
      userProfile = userProfileProvider.user;
      init = false;
      setState(() {});
    }
  }

  bool canContinue() {
    return upiIdController.text.isNotEmpty && upiIdError == null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingStepsProvider>(
      builder: (context, onboardingProvider, child) {
        return Scaffold(
          appBar: CommonAppBar(
            elevation: 6,
            centerTitle: true,
            title: Text(
              languageProvider.getMessage(
                  "enter_upi_details", "Enter UPI Details"),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 16.sp,
                  ),
            ),
          ),
          persistentFooterButtons: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 48.h,
                      maxWidth: 1.sw,
                    ),
                    child: ElevatedButton(
                      onPressed: canContinue() && !onboardingProvider.loading
                          ? onContinue
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        minimumSize:
                            Size.fromHeight(48.h), // Ensures button stretches
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: onboardingProvider.loading
                            ? const CupertinoActivityIndicator()
                            : Text(
                                languageProvider.getMessage(
                                    'confirm', "Confirm"),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: canContinue()
                                          ? AppColors.n0
                                          : AppColors.n60,
                                    ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 1.sw,
                      maxHeight: 48.h,
                    ),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.brand,
                          width: 1.r,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        minimumSize:
                            Size.fromHeight(48.h), // Ensures button stretches
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          languageProvider.getMessage('go_back', 'Go Back'),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: AppColors.brand),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          body: onboardingProvider.loading == true
              ? const Center(
                  child: CupertinoActivityIndicator(),
                )
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Column(
                        children: [
                          SizedBox(height: 40.h),
                          OnboardingQuestionV2(
                            mandatory: true,
                            questionTextStyle:
                                Theme.of(context).textTheme.labelMedium,
                            questionKey: 'upi_id',
                            questionDefault: 'UPI ID',
                            padding: EdgeInsets.zero,
                            answer: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormSnabbitV2(
                                  controller: upiIdController,
                                  hintText: languageProvider.getMessage(
                                    'enter_upi_id_hint',
                                    'Enter UPI ID',
                                  ),
                                  isLoading: onboardingProvider.loading,
                                  onChanged: (v) {
                                    setState(() {
                                      upiIdController.text = v;
                                    });
                                    userProfileProvider.notifyUserListeners();
                                    if (v.isNotEmpty) {
                                      upiIdError = null;
                                    } else {
                                      upiIdError = "UPI ID is required";
                                    }
                                  },
                                ),
                                if (upiIdError != null) ...[
                                  SizedBox(height: 8.h),
                                  Text(
                                    upiIdError!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.r40,
                                        ),
                                  )
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  void onContinue() async {
    await onboardingStepsProvider.verifyBankOrUpi(
      context: context,
      data: {"upi_id": upiIdController.text.trim()},
      onSuccess: () {
        // Check if status is REGISTERED before navigating
        if (onboardingStepsProvider.bankVerificationResponse?.status ==
            "REGISTERED") {
          Navigator.of(context)
              .pushReplacementNamed(UpiDetailsScreen.routeName);
        } else {
          // Handle other statuses if needed
          setState(() {
            upiIdError = "Verification incomplete. Please try again.";
          });
        }
      },
      onError: (error) {
        // Update the UI with the error
        setState(() {
          upiIdError = error.message;
        });
      },
    );
  }
}
