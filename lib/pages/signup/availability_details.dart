// ignore_for_file: use_build_context_synchronously

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
import '../../widgets/circular_checkbox.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import '../../utils/custom_themes/text_themes.dart';

class AvailabilityDetails extends StatefulWidget {
  static const String routeName = "/availability_details";

  const AvailabilityDetails({super.key});

  @override
  State<AvailabilityDetails> createState() => _AvailabilityDetailsState();
}

class _AvailabilityDetailsState extends State<AvailabilityDetails> {

  List<int>? workHoursOptions;

  TimeOfDay? avaiableTimingsFromShow;
  TimeOfDay? avaiableTimingsToShow;

  List<String> jobReachApproximationChoices = [
    "15 minute pehle",
    "Time pe",
    "Kabhi khabi late hua toh chal jayega"
  ];
  List<String>? leaveCountChoices;
  List<String>? availabilityToWorkChoices;
  List<String>? planToUseSalaryChoices;


  _updateWorkTime() {
    if (avaiableTimingsFromShow != null) {
      final now = DateTime.now();
      final pickedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        avaiableTimingsFromShow!.hour,
        avaiableTimingsFromShow!.minute,
      );

      final updatedDateTime = pickedDateTime.add(Duration(
          hours: userProfile.otherDetails?.hoursAvailableToWork?.value ?? 0));
      final formattedPickedTime =
          DateFormat("HH:mm:ss.SSS'Z'").format(pickedDateTime.toUtc());
      final formattedUpdatedTime =
          DateFormat("HH:mm:ss.SSS'Z'").format(updatedDateTime.toUtc());

      userProfile.otherDetails?.availableStartTime?.value = formattedPickedTime;
      userProfile.otherDetails?.availableEndTime?.value = formattedUpdatedTime;

      userProfileProvider.notifyUserListeners();

      setState(() {
        avaiableTimingsToShow = TimeOfDay.fromDateTime(updatedDateTime);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      final pickedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );

      final updatedDateTime = pickedDateTime.add(Duration(
          hours: userProfile.otherDetails?.hoursAvailableToWork?.value ?? 0));
      final formattedPickedTime =
          DateFormat("HH:mm:ss.SSS'Z'").format(pickedDateTime.toUtc());
      final formattedUpdatedTime =
          DateFormat("HH:mm:ss.SSS'Z'").format(updatedDateTime.toUtc());
      userProfile.otherDetails?.availableStartTime?.value = formattedPickedTime;
      userProfile.otherDetails?.availableEndTime?.value = formattedUpdatedTime;
      userProfileProvider.notifyUserListeners();
      setState(() {
        avaiableTimingsFromShow = picked;
        avaiableTimingsToShow = TimeOfDay.fromDateTime(updatedDateTime);
      });
    }
  }

///////
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late UserProfile userProfile;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;
      avaiableTimingsFromShow =
          parseTimeOfDay(userProfile.otherDetails?.availableStartTime?.value);
      avaiableTimingsToShow =
          parseTimeOfDay(userProfile.otherDetails?.availableEndTime?.value);
      leaveCountChoices = GlobalState().appConfig?.leaveCountChoices;
      availabilityToWorkChoices =
          GlobalState().appConfig?.availabilityToWorkChoices;
      planToUseSalaryChoices = GlobalState().appConfig?.planToUseSalary;
      workHoursOptions = userProfile.workSchedule?.value==WorkSchedule.everyday? GlobalState().appConfig?.regularWorkHours: GlobalState().appConfig?.weekendWorkHours;
      setState(() {});
    }
    super.didChangeDependencies();
  }

  TimeOfDay? parseTimeOfDay(String? timeString) {
    try {
      // Parse the input string to DateTime
      final DateTime dateTime =
          DateTime.parse("1970-01-01T$timeString").toLocal();

      // Extract the TimeOfDay from the DateTime
      return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
    } catch (e) {
      return null;
    }
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
    return Scaffold(
      appBar: const CommonAppBar(),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: !userProfileProvider.loading && continueConditions()
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
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: userProfileProvider.loading
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProgressIndicatorAtTop(value: 9),
                    Gap.gap32h,
                    const OnboardingPageHeader(
                      titleKey: 'job_details_title',
                      titleDefault: 'Job Details',
                      subtitleKey: 'job_details_subtitle',
                      subtitleDefault: 'Tell us your working details',
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'plan_to_use_salary',
                      questionDefault: 'How do you plan to use this money',
                      criticalError: userProfile.otherDetails?.planToUseSalary?.isValueAcceptable()==true?null:languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                      answer: planToUseSalaryChoices == null
                          ? UiHelper.showLoadFailError(context)
                          : GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 3,
                              mainAxisSpacing: 3,
                              childAspectRatio: 3,
                              children:
                                  planToUseSalaryChoices!.map((salaryChoice) {
                                final enumValue =
                                    getPlanToUseSalaryFromString(salaryChoice);
                                return GestureDetector(
                                  onTap: () {
                                    if (enumValue != null) {
                                      if (userProfile.otherDetails!
                                              .planToUseSalary?.value
                                              ?.contains(enumValue) ==
                                          true) {
                                        userProfile.otherDetails!
                                            .planToUseSalary?.value
                                            ?.remove(enumValue);
                                      } else {
                                        userProfile.otherDetails!
                                            .planToUseSalary?.value
                                            ?.add(enumValue);
                                      }
                                      userProfileProvider.notifyUserListeners();
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      CircularCheckbox(
                                        squircle: true,
                                        value: enumValue != null &&
                                            userProfile.otherDetails!
                                                    .planToUseSalary?.value
                                                    ?.contains(enumValue) ==
                                                true,
                                      ),
                                      Gap.gap8w,
                                      Expanded(
                                        child: Text(
                                          languageProvider.getMessage(
                                            salaryChoice,
                                            toBeginningOfSentenceCase(
                                                    salaryChoice.replaceAll(
                                                        "_", " ")) ??
                                                '',
                                          ),
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
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'job_reach_approximation',
                      questionDefault:
                          'If the job is scheduled at 9am, what time will you reach?',
                      criticalError: userProfile
                                  .otherDetails?.jobReachApproximation
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
                        children: jobReachApproximationChoices.map((e) {
                          return GestureDetector(
                            onTap: () {
                              userProfile.otherDetails?.jobReachApproximation
                                  ?.value = e;
                              userProfileProvider.notifyUserListeners();
                            },
                            child: Row(
                              children: [
                                CircularCheckbox(
                                  squircle: false,
                                  value: userProfile.otherDetails!
                                          .jobReachApproximation?.value ==
                                      e,
                                ),
                                Gap.gap8w,
                                Expanded(
                                  child: Text(
                                    e,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'hours_available_to_work_daily',
                      questionDefault: 'How many hours can you work daily?',
                      criticalError: userProfile
                                  .otherDetails?.hoursAvailableToWork
                                  ?.isValueAcceptable() ==
                              true
                          ? null
                          : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                      answer: Row(
                        children:
                            List.generate(workHoursOptions?.length ?? 0, (index) {
                          return Flexible(
                            flex: 1,
                            child: Padding(
                              padding: EdgeInsets.only(right: 8.w),
                              child: GestureDetector(
                                onTap: () {
                                  userProfile.otherDetails!.hoursAvailableToWork
                                      ?.value = workHoursOptions?[index];
                                  userProfileProvider.notifyUserListeners();

                                  _updateWorkTime();
                                },
                                child: Container(
                                  height: 48.h,
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.n60),
                                    borderRadius: BorderRadius.circular(8.r),
                                    color: userProfile.otherDetails!
                                                .hoursAvailableToWork?.value ==
                                            workHoursOptions?[index]
                                        ? AppColors.brand
                                        : AppColors.n0,
                                  ),
                                  child: Center(
                                    child: Text(
                                      workHoursOptions?[index].toString() ?? '',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w500,
                                        color: userProfile.otherDetails!
                                                    .hoursAvailableToWork?.value ==
                                                workHoursOptions?[index]
                                            ? AppColors.n0
                                            : Colors.black,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'available_timings',
                      questionDefault: 'Available timings',
                      answer: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              try {
                                if (userProfile.otherDetails!
                                        .hoursAvailableToWork?.value! >
                                    0) {
                                  _selectTime(context);
                                } else {
                                  showSnackbar(
                                      context, "Please select work hours");
                                }
                              } catch (e) {
                                showSnackbar(
                                    context, "Please select hours first.");
                              }
                            },
                            child: ShowTimings(time: avaiableTimingsFromShow),
                          ),
                          const SizedBox(
                            width: 32,
                            child: Center(
                              child: Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // _selectTime(context, false);
                            },
                            child: ShowTimings(time: avaiableTimingsToShow),
                          ),
                        ],
                      ),
                    ),
                    if (userProfile.workSchedule?.value == WorkSchedule.everyday)
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: OnboardingQuestion(
                          mandatory: true,
                          questionKey: 'leave_count',
                          questionDefault:
                              'How many leaves will you take in a month?',
                          criticalError: userProfile.otherDetails?.leaveCount
                                      ?.isValueAcceptable() ==
                                  true
                              ? null
                              : languageProvider.getMessage(
                                  'pls_review_answer_carefully',
                                  "Please review this answer carefully",
                                ),
                          answer: leaveCountChoices == null
                              ? UiHelper.showLoadFailError(context)
                              : GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 3,
                                  mainAxisSpacing: 3,
                                  childAspectRatio: 4,
                                  children: leaveCountChoices!.map((e) {
                                    return GestureDetector(
                                      onTap: () {
                                        userProfile.otherDetails?.leaveCount
                                            ?.value = e;
                                        userProfileProvider
                                            .notifyUserListeners();
                                      },
                                      child: Row(
                                        children: [
                                          CircularCheckbox(
                                            squircle: false,
                                            value: userProfile.otherDetails!
                                                    .leaveCount?.value ==
                                                e,
                                          ),
                                          Gap.gap3w,
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
                    Gap.gap16h,
                  ],
                ),
              ),
      ),
    );
  }

  bool continueConditions() {
    try {
      if (
          userProfile.otherDetails?.hoursAvailableToWork?.value != null &&
              userProfile.otherDetails!.planToUseSalary?.value?.isNotEmpty ==
                  true &&
              userProfile.otherDetails?.jobReachApproximation?.value != null
          ) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

}

class ShowTimings extends StatelessWidget {
  const ShowTimings({
    super.key,
    required this.time,
  });

  final TimeOfDay? time;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width / 3).w,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.n60),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Center(
        child: Text(
          time != null ? time!.format(context) : '00:00',
          style: time != null
              ? Theme.of(context).textTheme.bodyLarge
              : AppTextTheme.hintStyle,
        ),
      ),
    );
  }
}
