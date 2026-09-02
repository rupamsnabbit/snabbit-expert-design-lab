import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../providers/language_provider.dart';
import '../../../providers/user_profile.dart';
import '../../../utils/app_strings.dart';
import '../../../widgets/onboarding_question.dart';
import 'registration_review.dart';

class WorkExperienceReview extends StatefulWidget {
  const WorkExperienceReview({super.key});

  @override
  State<WorkExperienceReview> createState() => _WorkExperienceReviewState();
}

class _WorkExperienceReviewState extends State<WorkExperienceReview> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  UserProfile? userProfile;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfile = userProfileProvider.user;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingQuestion(
          mandatory: true,
          questionDefault: "Are you currently employed?",
          questionKey: 'currently_employed',
          answer: ReviewBoolAnswer(
            data: userProfile?.otherDetails?.currentlyEmployed?.value,
          ),
        ),
        SizedBox(height: 16.h),
        if (userProfile?.otherDetails?.currentlyEmployed == true)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: OnboardingQuestion(
              mandatory: true,
              questionKey: 'job_type',
              questionDefault: 'Are you working full time or part time?',
              answer: ReviewAnswer(data: "${userProfile?.otherDetails?.jobType?.value}"),
            ),
          ),
        if (userProfile?.otherDetails?.jobType?.value == AppStrings.fullTimeString)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: OnboardingQuestion(
              mandatory: true,
              questionDefault: "Will you quit your job?",
              questionKey: 'will_quit_job',
              answer: ReviewBoolAnswer(
                data: userProfile?.otherDetails?.willQuitJob?.value,
              ),
            ),
          ),
        if (userProfile?.otherDetails?.jobType?.value == AppStrings.partTimeString)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: OnboardingQuestion(
              mandatory: true,
              questionKey: 'job_preferred_time',
              questionDefault: 'What time do you usually work?',
              answer: ReviewAnswer(
                data: languageProvider.getMessage(
                  userProfile?.otherDetails?.jobPreferredTime?.value ?? "",
                  userProfile?.otherDetails?.jobPreferredTime?.value ?? "",
                ),
              ),
            ),
          ),
        if (userProfile?.otherDetails?.currentlyEmployed?.value == false)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: OnboardingQuestion(
              mandatory: true,
              questionDefault: "Have you ever worked before?",
              questionKey: 'worked_before',
              answer: ReviewBoolAnswer(
                data: userProfile?.otherDetails?.workedBefore?.value,
              ),
            ),
          ),
        if (userProfile?.otherDetails?.currentlyEmployed?.value == true ||
            userProfile?.otherDetails?.workedBefore?.value == true)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: OnboardingQuestion(
              mandatory: true,
              questionKey: 'priorJobs',
              questionDefault: 'What role have you worked in?',
              answer: ReviewAnswer(
                data: userProfile?.otherDetails?.priorJobs
                        ?.value?.map((jobKey) {
                          return languageProvider.getMessage(
                            jobKey.name.toLowerCase(),
                            jobKey.name,
                          );
                        })
                        .toList()
                        .join("\n") ??
                    "",
              ),
            ),
          ),
        if (userProfile?.otherDetails?.currentlyEmployed?.value == true &&
            userProfile?.otherDetails?.jobType?.value == AppStrings.fullTimeString)
          OnboardingQuestion(
            mandatory: true,
            questionKey: 'job_change_reason',
            questionDefault: 'Why do you want to change your job?',
            answer: ReviewAnswer(
              data: userProfile?.otherDetails?.jobChangeReasons
                      ?.value?.map((e) {
                        return languageProvider.getMessage(e, e);
                      })
                      .toList()
                      .join("\n") ??
                  "",
            ),
          ),
      ],
    );
  }
}
