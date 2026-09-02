import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/referrals/widgets/referral_header.dart';
import 'package:snabbit_runner/services/server_requests/training_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/registration_navigation.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';

import '../../models/training_center.dart';

class TrainingSlot {
  int id;
  DateTime? start;
  DateTime? end;
  TrainingCenter? tc;

  TrainingSlot({
    required this.id,
    this.start,
    this.end,
    this.tc,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'start_time': start?.toIso8601String(),
        'end_time': end?.toIso8601String(),
      };

  factory TrainingSlot.fromMap(Map<String, dynamic> map) {
    return TrainingSlot(
      id: map['id'],
      start: convertDateAndTimeToDateTime(map['start_date'], map['start_time']),
      end: convertDateAndTimeToDateTime(map['end_date'], map['end_time']),
      tc: map['training_center'] != null
          ? TrainingCenter.fromJson(map['training_center'])
          : null,
    );
  }
}

class TrainingSlots extends StatefulWidget {
  static const String routeName = "/training_slots";

  const TrainingSlots({super.key});

  @override
  State<TrainingSlots> createState() => _TrainingSlotsState();
}

class _TrainingSlotsState extends State<TrainingSlots> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  List<TrainingSlot> slots = [];

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(
        context,
        listen: true,
      );
      userProfileProvider = Provider.of<UserProfileProvider>(
        context,
        listen: true,
      );
      onboardingStepsProvider = Provider.of<OnboardingStepsProvider>(
        context,
        listen: true,
      );
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    try {
      Response? response = await TrainingHttp.getTrainingBatches();
      if (response != null) {
        slots = response.data
            .map<TrainingSlot>((e) => TrainingSlot.fromMap(e))
            .toList();
      } else {
        if (mounted) {
          showSnackbar(
            context,
            'Something went wrong!',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(
          context,
          'Something went wrong!',
        );
      }
    }
  }

  /// 1. Returns start date in format "11"
  String getStartDate(TrainingSlot trainingSlot) {
    try {
      return DateFormat("d").format(trainingSlot.start!);
    } catch (e) {
      return "";
    }
  }

  /// 2. Returns start date in format "MAR"
  String getStartMonthShort(TrainingSlot trainingSlot) {
    try {
      return DateFormat("MMM").format(trainingSlot.start!).toUpperCase();
    } catch (e) {
      return "";
    }
  }

  /// 3. Returns "Date - 28 Feb to 2 Mar (3 days)"
  String getDateRange(TrainingSlot trainingSlot) {
    try {
      String startDay = DateFormat("d MMM").format(trainingSlot.start!);
      String endDay = DateFormat("d MMM").format(trainingSlot.end!);
      int dayCount =
          trainingSlot.end!.difference(trainingSlot.start!).inDays + 1;

      return "Date - $startDay to $endDay ($dayCount days)";
    } catch (e) {
      return "";
    }
  }

  /// 4. Returns "Time - 11:00 AM to 05:00 PM"
  String getTimeRange(TrainingSlot trainingSlot) {
    try {
      String startTimeFormatted =
          DateFormat("hh:mm a").format(trainingSlot.start!);
      String endTimeFormatted = DateFormat("hh:mm a").format(trainingSlot.end!);

      return "Time - $startTimeFormatted to $endTimeFormatted";
    } catch (e) {
      return "";
    }
  }

  Future<void> setBatch() async {
    setState(() {
      loading = true;
    });
    try {
      Response? response = await TrainingHttp.setBatch(
        data: {
          'batch_id': userProfileProvider.user?.trainingSlot?.id ?? 0,
        },
      );
      if (response != null) {
        final sessionId =
            onboardingStepsProvider.onboardingQuestionResponse?.sessionId;
        final questionId = onboardingStepsProvider
            .onboardingQuestionResponse?.questions?.first.id;
        final batchId = userProfileProvider.user?.trainingSlot?.id ?? 0;

        if (sessionId != null && questionId != null) {
          final questionPayload = {
            'session_id': sessionId,
            'responses': [
              {
                'question_id': questionId,
                'question_type': 'text',
                'free_text_answer': batchId.toString(),
              }
            ]
          };

          onboardingStepsProvider.submitAnswerAndProceed(
              context: context,
              data: questionPayload,
              onSuccess: () {
                setState(() {
                  loading = false;
                });
              });
        }
      } else {
        if (mounted) {
          showSnackbar(
            context,
            'Something went wrong - ${response?.statusCode}',
          );
        }
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(
          context,
          'Something went wrong - $e',
        );
      }
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: const Color(0xffF5F6F8),
          appBar: AppBar(
            leading: InkWell(
              onTap: () {
                final userProfileProvider =
                    Provider.of<UserProfileProvider>(context, listen: false);
                userProfileProvider.checkStatusAndNavigate(context);
              },
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: AppColors.n80,
              ),
            ),
            title: Text(
              languageProvider.getMessage(
                'registration_complete',
                'Registration Complete',
              ),
            ),
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: EdgeInsets.all(16.r),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: const ReferralHeaderView(
                      showViewMyReferrals: true,
                      source: 'training_slots_page',
                    ),
                  ),
                  Container(
                    width: 1.sw,
                    padding: EdgeInsets.fromLTRB(
                      11.w,
                      34.h,
                      11.w,
                      12.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.n0,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          AssetConstants.verificationSuccessful,
                          height: 107.h,
                        ),
                        SizedBox(height: 32.h),
                        Text(
                          languageProvider.getMessage(
                            'congratulations',
                            'Congratulations!',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          languageProvider.getMessage(
                            'registration_complete_msg',
                            'Registration process successfully completed',
                          ),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        SizedBox(height: 42.h),
                        Text(
                          languageProvider.getMessage(
                            'select_training_slot',
                            'Please select training batch',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: AppColors.n80),
                        ),
                        SizedBox(height: 24.h),
                        ListView.separated(
                          itemCount: slots.length,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          separatorBuilder: (_, __) => Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.n30),
                              ),
                            ),
                          ),
                          itemBuilder: (_, index) {
                            TrainingSlot current = slots[index];
                            return InkWell(
                              onTap: () {
                                userProfileProvider.user?.trainingSlot = current;
                                userProfileProvider.notifyUserListeners();
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.r),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 57.r,
                                      height: 57.r,
                                      padding: EdgeInsets.all(8.r),
                                      decoration: BoxDecoration(
                                        color: AppColors.n20,
                                        borderRadius: BorderRadius.circular(16.r),
                                        border: Border.all(color: AppColors.n40),
                                      ),
                                      child: Column(
                                        children: [
                                          Flexible(
                                            flex: 7,
                                            child: Text(
                                              getStartDate(current),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineLarge
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700),
                                            ),
                                          ),
                                          Flexible(
                                            flex: 3,
                                            child: Text(
                                              getStartMonthShort(current),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.n70),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            getDateRange(current),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium,
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            getTimeRange(current),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(color: AppColors.n80),
                                          )
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    CircularCheckbox(
                                      value: userProfileProvider
                                              .user?.trainingSlot?.id ==
                                          current.id,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 21.h),
                        SizedBox(
                          width: 1.sw,
                          child: ElevatedButton(
                            onPressed:
                                userProfileProvider.user?.trainingSlot != null &&
                                        !loading
                                    ? () async {
                                        await setBatch();
                                      }
                                    : null,
                            child: Text(
                              languageProvider.getMessage(
                                'confirm',
                                'Confirm',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 25.h),
                  // BehaviouralAssessment(
                  //   userProfileProvider: userProfileProvider,
                  //   languageProvider: languageProvider,
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BehaviouralAssessment extends StatelessWidget {
  final UserProfileProvider userProfileProvider;
  final LanguageProvider languageProvider;
  final Color? bgColor;

  const BehaviouralAssessment({
    super.key,
    required this.userProfileProvider,
    required this.languageProvider,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.sw,
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.n0,
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userProfileProvider.user?.registrationCompleted == true)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: StatusTile(
                text: languageProvider.getMessage(
                  'completed',
                  'COMPLETED',
                ),
                bgColor: AppColors.g10,
                textColor: AppColors.g50,
              ),
            ),
          Text(
            (userProfileProvider.user?.registrationCompleted == true)
                ? languageProvider.getMessage(
                    'successfully_completed',
                    'Successfully completed ',
                  )
                : languageProvider.getMessage(
                    'behavioral_assessment_title',
                    'Behavioural Assessment',
                  ),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 8.h),
          Text(
            (userProfileProvider.user?.registrationCompleted == true)
                ? languageProvider.getMessage(
                    'passed_test',
                    'Thanks for sharing the additional information with us, this help us to facilitate better',
                  )
                : languageProvider.getMessage(
                    'behavioral_assessment_subtitle',
                    'We have a few more questions. Please ensure this is completed on the Registration Day itself.',
                  ),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.n80),
          ),
          if (userProfileProvider.user?.registrationCompleted != true)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: SizedBox(
                width: 170.w,
                child: ElevatedButton(
                  onPressed: () {
                    try {
                      RegistrationNavigation.navigateToRegistrationStep(
                        context,
                      );
                    } catch (e) {
                      // DO NOTHING
                    }
                  },
                  child: Text(
                    languageProvider.getMessage(
                      'take_test',
                      'Take Test',
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class StatusTile extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const StatusTile({
    super.key,
    required this.text,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 4.w,
        vertical: 4.h,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .displaySmall
            ?.copyWith(color: textColor),
      ),
    );
  }
}
