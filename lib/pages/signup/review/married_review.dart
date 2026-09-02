import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

import '../../../providers/language_provider.dart';
import '../../../providers/user_profile.dart';
import '../../../widgets/onboarding_question.dart';
import 'registration_review.dart';

class MarriedReview extends StatefulWidget {
  const MarriedReview({super.key});

  @override
  State<MarriedReview> createState() => _MarriedReviewState();
}

class _MarriedReviewState extends State<MarriedReview> {
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
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionKey: 'spouse_name',
          questionDefault: 'Name of Husband',
          mandatory: true,
          answer: ReviewAnswer(
            data: '${userProfile?.insuranceData?.spouseName}',
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionKey: 'spouse_occupation',
          questionDefault: 'Occupation of husband',
          mandatory: true,
          answer: ReviewAnswer(
            data: languageProvider.getMessage(
              userProfile?.otherDetails?.spouseOccupation?.value ?? "",
              userProfile?.otherDetails?.spouseOccupation ?.value ?? "",
            ),
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionKey: 'spouse_monthly_income',
          questionDefault: 'Monthly income of husband',
          mandatory: true,
          answer: ReviewAnswer(
            data:
                "${anyValueToInt(userProfile?.otherDetails?.spouseMonthlyIncome?.value)}",
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionDefault:
              "Have you told your family members about Snabbit and the work it involves?",
          questionKey: 'family_ok_with_cleaning_job',
          mandatory: true,
          answer: ReviewBoolAnswer(
            data: userProfile?.otherDetails?.familyOkWithCleaningJob?.value,
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionDefault: "Do you stay with parents/ in-laws/ joint family?",
          questionKey: 'stay_with_parents',
          mandatory: true,
          answer: ReviewBoolAnswer(
            data: userProfile?.otherDetails?.stayWithParents?.value,
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionDefault:
              "Will they approve of you doing house and bathroom cleaning work?",
          questionKey: 'parents_approval',
          mandatory: true,
          answer: ReviewBoolAnswer(
            data: userProfile?.otherDetails?.parentsApproval?.value,
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionDefault:
              "Are you allowed to wear t-shirt and pants when you go out?",
          questionKey: 'tshirt_allowed',
          mandatory: true,
          answer: ReviewBoolAnswer(
            data: userProfile?.otherDetails?.tshirtAllowed?.value,
          ),
        ),
        SizedBox(height: 16.h),
        if ((userProfile?.otherDetails?.numberOfChildren ?? 0) != 0)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: OnboardingQuestion(
              questionKey: 'number_of_children',
              questionDefault: 'How many kids do you have?',
              answer: ReviewAnswer(
                data: ((userProfile?.otherDetails?.numberOfChildren?.value as int?) ?? 0) > 4
                    ? "${userProfile?.otherDetails?.numberOfChildren?.value}+"
                    : "${userProfile?.otherDetails?.numberOfChildren?.value}",
              ),
            ),
          ),
        if ((userProfile?.otherDetails?.numberOfChildren?.value ?? 0) != 0 &&
            userProfileProvider.user?.otherDetails?.ageOfYoungestChild?.value != null)
          OnboardingQuestion(
            questionKey: 'youngest_child_age',
            questionDefault: 'How old is your youngest child (years)?',
            answer: ReviewAnswer(
              data:
                  "${anyValueToInt(userProfileProvider.user?.otherDetails?.ageOfYoungestChild?.value)}",
            ),
          ),
      ],
    );
  }
}
