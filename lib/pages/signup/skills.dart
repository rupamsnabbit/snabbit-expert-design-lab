import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/integrity_test.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

import '../../services/runner_http.dart';
import '../../utils/colors.dart';
import '../../widgets/gap.dart';
import '../../widgets/progress_indicator.dart';
import '../../widgets/true_false_radio_button.dart';

class Skills extends StatefulWidget {
  static const String routeName = "/skills";

  const Skills({super.key});

  @override
  State<Skills> createState() => _SkillsState();
}

class _SkillsState extends State<Skills> {
  bool loading = false;
  late UserProfileProvider userProfileProvider;
  UserProfile? userProfile;
  bool init = true;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user;
      languageProvider = Provider.of<LanguageProvider>(context,listen: false);
    }
    super.didChangeDependencies();
  }

  bool isContinueEnabled() {
    try {
      return !loading &&
          ( (userProfile?.otherDetails?.ownSmartphone?.value == false &&
                  userProfile?.otherDetails?.getPhoneForJob?.value != null));
    } catch (e) {
      return true;
    }
  }

  void onContinue() async {
    setState(() {
      loading = true;
    });
    Response? response =
    await RunnerHttp.runnerRegistration(data: userProfile?.toMap());
    if (response != null && response.statusCode == 200) {
      Navigator.of(context).pushNamed(IntegrityTestWidget.routeName);
    } else {
      showSnackbar(context, "Something went wrong - $response");
    }
    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: isContinueEnabled() && !loading ? onContinue : null,
            child: loading
                ? const CupertinoActivityIndicator()
                : Text(
              languageProvider.getMessage("continue", "Continue",),
            ),
          ),
        ),
      ],
      body: loading
          ? const Center(child: CupertinoActivityIndicator())
          : userProfile == null
              ? const Center(child: Text("Error: User profile not found"))
              : Padding(
                  padding: EdgeInsets.symmetric(vertical:16.h),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ProgressIndicatorAtTop(value: 4),
                        Gap.gap32h,
                        const OnboardingPageHeader(
                          titleKey: 'skills_title',
                          titleDefault: 'Skills',
                          subtitleKey: 'skills_subtitle',
                          subtitleDefault: "Tell us what you're good at",
                        ),
                        Gap.gap32h,
                        if (userProfile?.otherDetails?.ownSmartphone?.value == false)
                          Padding(
                            padding: EdgeInsets.only(top: 16.h),
                            child: TrueFalseRadioButton(
                              option1: "Yes",
                              option2: "No",
                              questionKey: "can_bring_own_smartphone",
                              question:
                                  "Will you be able to get a phone for the job? ",
                              criticalError: userProfile?.otherDetails?.getPhoneForJob
                                  ?.isValueAcceptable() ==
                                  true
                                  ? null
                                  : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                              onOption1Tap: () {
                                userProfile?.otherDetails?.getPhoneForJob?.value =
                                    true;
                                userProfileProvider.notifyUserListeners();
                              },
                              onOption2Tap: () {
                                userProfile?.otherDetails?.getPhoneForJob?.value =
                                    false;
                                userProfileProvider.notifyUserListeners();
                              },
                              checkBoxOption1Value:
                                  userProfile?.otherDetails?.getPhoneForJob?.value ==
                                      true,
                              checkBoxOption2Value:
                                  userProfile?.otherDetails?.getPhoneForJob?.value ==
                                      false,
                            ),
                          ),
                        Gap.gap16h,

                      ],
                    ),
                  ),
                ),
    );
  }
}
