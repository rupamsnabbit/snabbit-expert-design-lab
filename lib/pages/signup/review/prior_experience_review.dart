import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/miscellaneous/tail_widgets.dart';

import '../../../providers/language_provider.dart';
import '../../../providers/user_profile.dart';
import '../../../utils/app_strings.dart';
import '../../../utils/enums.dart';
import '../../../widgets/onboarding_question.dart';
import 'registration_review.dart';

class PriorExperienceReview extends StatefulWidget {
  const PriorExperienceReview({super.key});

  @override
  State<PriorExperienceReview> createState() => _PriorExperienceReviewState();
}

class _PriorExperienceReviewState extends State<PriorExperienceReview> {
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
          questionKey: "has_own_smartphone",
          questionDefault: "Do you have your own smartphone?",
          answer: ReviewBoolAnswer(
            data: userProfile?.otherDetails?.ownSmartphone?.value,
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          mandatory: true,
          questionKey: 'prior_tasks',
          questionDefault:
              'How many of these tasks have you done before?\n(select all that apply)',
          answer: ReviewAnswer(
            data: userProfile?.otherDetails?.priorTasks
                    ?.value?.map((jobKey) {
                      return languageProvider.getMessage(
                        jobKey.name.toLowerCase(),
                        jobKey.name,
                      );
                    })
                    .toList()
                    .join("\n") ??
                "N/A",
          ),
        ),
        SizedBox(height: 16.h),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingQuestion(
              questionDefault:
                  "Are you willing to clean homes with dogs / other pets?",
              questionKey: 'willing_to_clean_home_with_pets',
              answer: ReviewBoolAnswer(
                data: userProfile?.otherDetails?.willingToCleanHomeWithPets?.value,
              ),
            ),
            SizedBox(height: 16.h),
            OnboardingQuestion(
              questionDefault: "Are you willing to clean pooja room?",
              questionKey: 'willing_to_clean_pooja_room',
              answer: ReviewBoolAnswer(
                data: userProfile?.otherDetails?.willingToCleanPoojaRoom?.value,
              ),
            ),
            SizedBox(height: 16.h),
            OnboardingQuestion(
              questionDefault: "Are you willing to clean bathrooms?",
              questionKey: 'willing_to_clean_bathrooms',
              answer: ReviewBoolAnswer(
                data: userProfile?.otherDetails?.willingToCleanBathrooms?.value,
              ),
            ),
            SizedBox(height: 16.h),
          ],
        ),
        OnboardingQuestion(
          mandatory: true,
          questionDefault: "Do you keep fasts?",
          questionKey: 'keep_fasts',
          answer: ReviewBoolAnswer(
            data: userProfile?.otherDetails?.keepFasts?.value,
          ),
        ),
        SizedBox(height: 16.h),
        if (userProfile?.otherDetails?.keepFasts?.value == true)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: OnboardingQuestion(
              mandatory: true,
              questionDefault:
                  "Will you be able to complete all tasks during fasts (including bathroom cleaning)?",
              questionKey: 'tasks_during_fasts',
              answer: ReviewBoolAnswer(
                data: userProfile?.otherDetails?.tasksDuringFast?.value,
              ),
            ),
          ),
        OnboardingQuestion(
          questionKey: 'dietary_preference',
          questionDefault: 'What are your dietary preferences?',
          answer: ReviewAnswer(
            data: languageProvider.getMessage(
              userProfile?.otherDetails?.dietaryPreference?.value?.name
                      .toLowerCase() ??
                  "",
              userProfile?.otherDetails?.dietaryPreference?.value?.name ?? "",
            ),
          ),
        ),
        SizedBox(height: 16.h),
        if (userProfile?.otherDetails!.dietaryPreference?.value ==
            DietaryPreference.Strictly_Vegetarian)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: OnboardingQuestion(
              mandatory: true,
              questionDefault:
                  "Will you be okay working in non-vegetarian households and completing tasks like dishwashing?",
              questionKey: 'can_clean_non_veg_kitchen',
              answer: ReviewBoolAnswer(
                data: userProfile?.otherDetails?.canCleanNonVegKitchen?.value,
              ),
            ),
          ),
        OnboardingQuestion(
          mandatory: true,
          questionKey: 'language_comfortable',
          questionDefault: 'How comfortable are you with each language?',
          answer: Column(
            children: userProfile?.otherDetails?.languageProficiency?.value?.map((e) {
                  return e.isValidData()
                      ? Row(
                          children: [
                            Expanded(
                                flex: 20,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: ReviewAnswer(
                                      data:
                                          "${languageProvider.getMessage(e.key ?? "", e.label.capitalize())}:"),
                                )),
                            Expanded(
                                flex: 80,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    if (e.read == true)
                                      Padding(
                                        padding: EdgeInsets.only(right: 12.w),
                                        child: ReviewAnswer(
                                          data: languageProvider.getMessage(
                                            'read',
                                            'Read',
                                          ),
                                        ),
                                      ),
                                    if (e.write == true)
                                      Padding(
                                        padding: EdgeInsets.only(right: 12.w),
                                        child: ReviewAnswer(
                                          data: languageProvider.getMessage(
                                            'write',
                                            'Write',
                                          ),
                                        ),
                                      ),
                                    if (e.understand == true)
                                      ReviewAnswer(
                                        data: languageProvider.getMessage(
                                          'understand',
                                          'Understand',
                                        ),
                                      ),
                                  ],
                                )),
                          ],
                        )
                      : const SizedBox.shrink();
                }).toList() ??
                [],
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          mandatory: true,
          questionKey: 'pet_preference',
          questionDefault: 'Are you afraid of pets?',
          questionSubtitle: languageProvider.getMessage(
            'pet_preference_subtitle',
            'Please mark only if you are genuinely scared of pets as it may reduce your chances of passing the registration process',
          ),
          questionTrailingItem: TailWidgets.petAverse,
          answer: ReviewAnswer(
            data: languageProvider.getMessage(
              userProfile?.petAverse?.value==true? "yes": "no",
              userProfile?.petAverse?.value==true?"yes":"no",
            ),
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          mandatory: true,
          questionKey: "has_used_google_maps",
          questionDefault: "Have you ever used Google Maps?",
          answer: ReviewBoolAnswer(
            data: userProfile?.otherDetails?.usedGoogleMaps?.value,
          ),
        ),
        if (userProfile?.otherDetails?.vehiclesUsed?.value != null)
          Padding(
            padding: EdgeInsets.only(top: 16.h),
            child: OnboardingQuestion(
              mandatory: true,
              questionKey: 'vehicles_used',
              questionDefault:
                  'Do you know how to ride any of the following?\n(select all that apply) ',
              answer: ReviewAnswer(
                data: userProfile?.otherDetails?.vehiclesUsed
                        ?.value?.map((e) {
                          return languageProvider.getMessage(e, e);
                        })
                        .toList()
                        .join("\n") ??
                    "",
              ),
            ),
          ),
        if (userProfile?.otherDetails?.willingToLearnEBike?.value != null)
        Padding(padding: EdgeInsets.only(top: 16.h),
          child: OnboardingQuestion(
            mandatory: true,
            questionKey: "willing_to_learn_ebike",
            questionDefault: "Would you be willing to learn how to ride E-Bike?",
            answer: ReviewBoolAnswer(
              data: userProfile?.otherDetails?.willingToLearnEBike?.value,
            ),
          ),
        ),
      ],
    );
  }
}
