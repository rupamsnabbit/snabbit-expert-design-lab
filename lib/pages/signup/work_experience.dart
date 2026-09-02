import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/ui_helper.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import 'package:snabbit_runner/widgets/true_false_radio_button.dart';
import '../../utils/app_strings.dart';
import '../../widgets/circular_checkbox.dart';
import '../../utils/common_methods.dart';

class WorkExperience extends StatefulWidget {
  static const String routeName = "/work_experience";

  const WorkExperience({super.key});

  @override
  State<WorkExperience> createState() => WorkExperienceState();
}

class WorkExperienceState extends State<WorkExperience> {
  List<String> jobTypeChoices = [
    AppStrings.fullTimeString,
    AppStrings.partTimeString
  ];
  List<String>? jobPreferredTimeChoices;
  List<String>? reasonForJobChangeChoices;
  List<String>? priorJobKeys;

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
      // userProfile.registrationStep = RunnerRegistrationStep.priorExp;
      reasonForJobChangeChoices = GlobalState().appConfig?.jobChangeReasons;
      jobPreferredTimeChoices =
          GlobalState().appConfig?.jobPreferredTimeChoices;
      priorJobKeys = GlobalState().appConfig?.priorJob;
      setState(() {});
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
                  onPressed:
                      !userProfileProvider.loading && continueConditions()
                          ? onContinue
                          : null,
                  child: Text(
                    languageProvider.getMessage(
                      'continue',
                      'Continue',
                    ),
                  ),
                ),
              ),
            ],
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProgressIndicatorAtTop(value: 3),
                    Gap.gap32h,
                    const OnboardingPageHeader(
                      titleKey: 'work_experience_title',
                      titleDefault: 'Work Experience',
                      subtitleKey: 'work_experience_subtitle',
                      subtitleDefault:
                          'Tell us about your previous work experience',
                    ),
                    Gap.gap32h,
                    TrueFalseRadioButton(
                      mandatory: true,
                      // option1: "Yes",
                      // option2: "No",
                      question: "Are you currently employed?",
                      questionKey: 'currently_employed',
                      criticalError: userProfile.otherDetails?.currentlyEmployed
                          ?.isValueAcceptable() ==
                          true
                          ? null
                          : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                      onOption1Tap: () {
                        userProfile.otherDetails!.currentlyEmployed?.value = true;
                        userProfile.otherDetails?.workedBefore?.value = null;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.otherDetails!.currentlyEmployed?.value = false;
                        userProfile.otherDetails?.jobType?.value = null;
                        userProfile.otherDetails?.willQuitJob?.value = null;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value:
                          userProfile.otherDetails!.currentlyEmployed?.value ?? false,
                      checkBoxOption2Value:
                          userProfile.otherDetails!.currentlyEmployed?.value != null
                              ? !userProfile.otherDetails!.currentlyEmployed!.value!
                              : false,
                    ),
                    if (userProfile.otherDetails?.currentlyEmployed?.value == true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap16h,
                          OnboardingQuestion(
                            mandatory: true,
                            questionKey: 'job_type',
                            questionDefault:
                                'Are you working full time or part time?',
                            criticalError: userProfile.otherDetails?.jobType
                                ?.isValueAcceptable() ==
                                true
                                ? null
                                : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                            answer: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 3,
                              mainAxisSpacing: 3,
                              childAspectRatio: 4,
                              children: jobTypeChoices.map((e) {
                                return GestureDetector(
                                  onTap: () {
                                    userProfile.otherDetails?.jobType?.value = e;
                                    userProfileProvider.notifyUserListeners();
                                  },
                                  child: Row(
                                    children: [
                                      CircularCheckbox(
                                        squircle: false,
                                        value:
                                            userProfile.otherDetails!.jobType?.value ==
                                                e,
                                      ),
                                      Gap.gap8w,
                                      Text(
                                        e,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    if (userProfile.otherDetails?.jobType?.value ==
                        AppStrings.fullTimeString)
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: TrueFalseRadioButton(
                          mandatory: true,
                          // option1: "Yes",
                          // option2: "No",
                          question: "Will you quit your job?",
                          questionKey: 'will_quit_job',
                          criticalError: userProfile.otherDetails?.willQuitJob
                              ?.isValueAcceptable() ==
                              true
                              ? null
                              : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                          onOption1Tap: () {
                            userProfile.otherDetails!.willQuitJob?.value = true;
                            userProfileProvider.notifyUserListeners();
                          },
                          onOption2Tap: () {
                            userProfile.otherDetails!.willQuitJob?.value = false;
                            userProfileProvider.notifyUserListeners();
                          },
                          checkBoxOption1Value:
                              userProfile.otherDetails!.willQuitJob?.value ?? false,
                          checkBoxOption2Value:
                              userProfile.otherDetails!.willQuitJob?.value != null
                                  ? !userProfile.otherDetails!.willQuitJob!.value!
                                  : false,
                        ),
                      ),
                    if (userProfile.otherDetails?.jobType?.value ==
                        AppStrings.partTimeString)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap16h,
                          OnboardingQuestion(
                            mandatory: true,
                            questionKey: 'job_preferred_time',
                            questionDefault: 'What time do you usually work?',
                            criticalError: userProfile.otherDetails?.jobPreferredTime
                                ?.isValueAcceptable() ==
                                true
                                ? null
                                : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                            answer: jobPreferredTimeChoices == null
                                ? UiHelper.showLoadFailError(context)
                                : GridView.count(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 3,
                                    mainAxisSpacing: 3,
                                    childAspectRatio: 4,
                                    children: jobPreferredTimeChoices!.map((e) {
                                      return GestureDetector(
                                        onTap: () {
                                          userProfile.otherDetails
                                              ?.jobPreferredTime?.value = e;
                                          userProfileProvider
                                              .notifyUserListeners();
                                        },
                                        child: Row(
                                          children: [
                                            CircularCheckbox(
                                              squircle: false,
                                              value: userProfile.otherDetails!
                                                      .jobPreferredTime?.value ==
                                                  e,
                                            ),
                                            Gap.gap8w,
                                            Text(
                                              languageProvider.getMessage(e, e),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
                    if (userProfile.otherDetails?.currentlyEmployed?.value == false)
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: TrueFalseRadioButton(
                          mandatory: true,
                          // option1: "Yes",
                          // option2: "No",
                          question: "Have you ever worked before?",
                          questionKey: 'worked_before',
                          criticalError: userProfile.otherDetails?.workedBefore
                              ?.isValueAcceptable() ==
                              true
                              ? null
                              : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                          onOption1Tap: () {
                            userProfile.otherDetails!.workedBefore?.value = true;
                            userProfileProvider.notifyUserListeners();
                          },
                          onOption2Tap: () {
                            userProfile.otherDetails!.workedBefore?.value = false;
                            userProfileProvider.notifyUserListeners();
                          },
                          checkBoxOption1Value:
                              userProfile.otherDetails!.workedBefore?.value ?? false,
                          checkBoxOption2Value:
                              userProfile.otherDetails!.workedBefore?.value != null
                                  ? !userProfile.otherDetails!.workedBefore!.value!
                                  : false,
                        ),
                      ),
                    if (userProfile.otherDetails?.currentlyEmployed?.value == true ||
                        userProfile.otherDetails?.workedBefore?.value ==
                            true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap16h,
                          OnboardingQuestion(
                            mandatory: true,
                            questionKey: 'priorJobs',
                            questionDefault: 'What role have you worked in?',
                            criticalError: userProfile
                                .otherDetails!.priorJobs?.isValueAcceptable()==true?null:
                            languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                            answer: priorJobKeys == null
                                ? UiHelper.showLoadFailError(context)
                                : GridView.count(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 3,
                                    mainAxisSpacing: 3,
                                    childAspectRatio: 4,
                                    children: priorJobKeys!.map((jobKey) {
                                      final PriorJob? enumValue =
                                          getPriorJobFromString(jobKey);
                                      return GestureDetector(
                                        onTap: () {
                                          if (enumValue != null) {
                                            if (userProfile
                                                .otherDetails!.priorJobs?.value
                                                ?.contains(enumValue)==true) {
                                              userProfile
                                                  .otherDetails!.priorJobs
                                                  ?.value?.remove(enumValue);
                                            } else {
                                              userProfile
                                                  .otherDetails!.priorJobs
                                                  ?.value?.add(enumValue);
                                            }
                                            userProfileProvider
                                                .notifyUserListeners();
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            CircularCheckbox(
                                              squircle: true,
                                              value: enumValue != null &&
                                                  userProfile
                                                      .otherDetails!.priorJobs?.value
                                                      ?.contains(enumValue)==true,
                                            ),
                                            Gap.gap8w,
                                            Expanded(
                                              child: Text(
                                                languageProvider.getMessage(
                                                    jobKey,
                                                    toBeginningOfSentenceCase(
                                                            jobKey.replaceAll(
                                                                "_", " ")) ??
                                                        ''),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
                    if (userProfile.otherDetails?.currentlyEmployed?.value == true &&
                        userProfile.otherDetails?.jobType?.value ==
                            AppStrings.fullTimeString)
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: OnboardingQuestion(
                          mandatory: true,
                          questionKey: 'job_change_reason',
                          questionDefault:
                              'Why do you want to change your job?',
                          criticalError: userProfile
                              .otherDetails!.jobChangeReasons?.isValueAcceptable()==true?null:
                          languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                          answer: reasonForJobChangeChoices == null
                              ? UiHelper.showLoadFailError(context)
                              : GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 3,
                                  mainAxisSpacing: 3,
                                  childAspectRatio: 4,
                                  children: reasonForJobChangeChoices!.map((e) {
                                    return GestureDetector(
                                      onTap: () {
                                        try {
                                          if ((userProfile
                                                      .otherDetails
                                                      ?.jobChangeReasons?.value
                                                      ?.isNotEmpty ??
                                                  false) &&
                                              userProfile.otherDetails!
                                                  .jobChangeReasons!.value!
                                                  .contains(e)) {
                                            userProfile
                                                .otherDetails!.jobChangeReasons!.value!
                                                .remove(e);
                                          } else {
                                            if (userProfile.otherDetails
                                                    ?.jobChangeReasons?.value !=
                                                null) {
                                              userProfile.otherDetails!
                                                  .jobChangeReasons!.value!
                                                  .add(e);
                                            } else {
                                              userProfile.otherDetails
                                                  ?.jobChangeReasons?.value = [e];
                                            }
                                          }
                                          userProfileProvider
                                              .notifyUserListeners();
                                        } catch (e) {
                                          showSnackbar(context,
                                              'Something went wrong - $e');
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          CircularCheckbox(
                                            squircle: true,
                                            value: userProfile.otherDetails
                                                    ?.jobChangeReasons?.value
                                                    ?.contains(e) ??
                                                false,
                                          ),
                                          Gap.gap8w,
                                          Expanded(
                                            child: Text(
                                              languageProvider.getMessage(e, e),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
  }

  bool continueConditions() {
    if (userProfile.otherDetails?.currentlyEmployed?.value == true &&
        userProfile.otherDetails?.jobType?.value == null) {
      return false;
    }
    if (userProfile.otherDetails?.currentlyEmployed?.value == false &&
        userProfile.otherDetails?.workedBefore?.value == null) {
      return false;
    }
    if (userProfile.otherDetails?.jobType?.value == AppStrings.fullTimeString &&
        userProfile.otherDetails?.willQuitJob?.value == null) {
      return false;
    }
    if (userProfile.otherDetails?.jobType?.value == AppStrings.partTimeString &&
        userProfile.otherDetails?.jobPreferredTime?.value == null) {
      return false;
    }
    if (userProfile.otherDetails?.jobType?.value == AppStrings.fullTimeString &&
        userProfile.otherDetails?.currentlyEmployed?.value == true &&
        (userProfile.otherDetails?.jobChangeReasons?.value?.isEmpty ?? true)) {
      return false;
    }
    if (!(userProfile.otherDetails?.currentlyEmployed?.value == false &&
            userProfile.otherDetails?.workedBefore?.value == false) &&
        (userProfile.otherDetails?.priorJobs?.value == null ||
            userProfile.otherDetails!.priorJobs?.value?.isEmpty==true)) {
      return false;
    }
    if (userProfile.otherDetails?.currentlyEmployed?.value != null) {
      return true;
    } else {
      return false;
    }
  }

}
