import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/runner_registration_step.dart';
import 'package:snabbit_runner/widgets/true_false_radio_button.dart';
import '../../../widgets/common_app_bar.dart';
import '../../../widgets/onboarding_question.dart';
import '../prior_experience.dart';

class FamilyDetailsIfUnmarried extends StatefulWidget {
  static const String routeName = "/family_details_unmarried";

  const FamilyDetailsIfUnmarried({super.key});

  @override
  State<FamilyDetailsIfUnmarried> createState() =>
      _FamilyDetailsIfUnmarriedState();
}

class _FamilyDetailsIfUnmarriedState extends State<FamilyDetailsIfUnmarried> {
  // bool? stayWithParents;
  // bool? isDecisionSupportedByParents;
  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late LanguageProvider languageProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;

      // userProfile.registrationStep = RunnerRegistrationStep.family;
    }
    super.didChangeDependencies();
  }

  void onContinue() async {
    await userProfileProvider.runnerRegistrationAndErrorHandler(
      context: context,
      onError: (errorMessage) {
        showSnackbar(context, errorMessage ?? "Something went wrong");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return userProfileProvider.loading
        ? const Scaffold(
            body: Center(
              child: CupertinoActivityIndicator(),
            ),
          )
        : Scaffold(
            appBar: const CommonAppBar(),
            persistentFooterButtons: [
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: continueCondtions() && !userProfileProvider.loading
                      ? onContinue
                      : null,
                  child: userProfileProvider.loading
                      ? const CupertinoActivityIndicator(
                          color: AppColors.n0,
                        )
                      : Text(
                          languageProvider.getMessage(
                            'continue',
                            'Continue',
                          ),
                        ),
                ),
              ),
            ],
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProgressIndicatorAtTop(value: 2),
                  Gap.gap32h,
                  const OnboardingPageHeader(
                    titleKey: "family_details_title",
                    titleDefault: "Family Details",
                    subtitleKey: 'family_details_subtitle',
                    subtitleDefault: "Tell us a bit more about yourself",
                  ),
                  Gap.gap16h,
                  TrueFalseRadioButton(
                    question: "Do you stay with your parents?",
                    questionKey: 'stay_with_parents',
                    mandatory: true,
                    onOption1Tap: () {
                      userProfile.otherDetails!.stayWithParents?.value = true;
                      userProfileProvider.notifyUserListeners();
                    },
                    onOption2Tap: () {
                      userProfile.otherDetails!.stayWithParents?.value = false;
                      userProfileProvider.notifyUserListeners();
                    },
                    checkBoxOption1Value:
                        userProfile.otherDetails!.stayWithParents?.value ?? false,
                    checkBoxOption2Value:
                        userProfile.otherDetails!.stayWithParents?.value != null
                            ? !userProfile.otherDetails!.stayWithParents?.value!
                            : false,
                  ),
                  Gap.gap16h,
                  TrueFalseRadioButton(
                    question:
                        "Will they approve of you doing house and bathroom cleaning work?",
                    questionKey: 'parents_approval',
                    mandatory: true,
                    onOption1Tap: () {
                      userProfile.otherDetails!.parentsApproval?.value = true;
                      userProfileProvider.notifyUserListeners();
                    },
                    onOption2Tap: () {
                      userProfile.otherDetails!.parentsApproval?.value = false;
                      userProfileProvider.notifyUserListeners();
                    },
                    checkBoxOption1Value:
                        userProfile.otherDetails!.parentsApproval?.value ?? false,
                    checkBoxOption2Value:
                        userProfile.otherDetails!.parentsApproval?.value != null
                            ? !userProfile.otherDetails!.parentsApproval?.value!
                            : false,
                  ),
                  Gap.gap16h,
                  TrueFalseRadioButton(
                    question:
                        "Are you allowed to wear t-shirt/pants when you go out?",
                    questionKey: 'tshirt_allowed',
                    criticalError: userProfile.otherDetails?.tshirtAllowed
                        ?.isValueAcceptable() ==
                        true
                        ? null
                        : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                    mandatory: true,
                    onOption1Tap: () {
                      userProfile.otherDetails!.tshirtAllowed?.value = true;
                      userProfileProvider.notifyUserListeners();
                    },
                    onOption2Tap: () {
                      userProfile.otherDetails!.tshirtAllowed?.value = false;
                      userProfileProvider.notifyUserListeners();
                    },
                    checkBoxOption1Value:
                        userProfile.otherDetails!.tshirtAllowed?.value ?? false,
                    checkBoxOption2Value:
                        userProfile.otherDetails!.tshirtAllowed?.value != null
                            ? !userProfile.otherDetails!.tshirtAllowed!.value!
                            : false,
                  ),
                  Gap.gap16h,
                ],
              ),
            ),
          );
  }

  bool continueCondtions() {
    if (userProfile.otherDetails!.stayWithParents?.value != null &&
        userProfile.otherDetails?.tshirtAllowed?.value != null &&
        userProfile.otherDetails!.parentsApproval?.value != null) {
      return true;
    } else {
      return false;
    }
  }
}
