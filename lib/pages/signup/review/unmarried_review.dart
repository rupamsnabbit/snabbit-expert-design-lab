import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

import '../../../providers/language_provider.dart';
import '../../../providers/user_profile.dart';
import '../../../widgets/onboarding_question.dart';
import 'registration_review.dart';

class UnmarriedReview extends StatefulWidget {
  const UnmarriedReview({super.key});

  @override
  State<UnmarriedReview> createState() => _UnmarriedReviewState();
}

class _UnmarriedReviewState extends State<UnmarriedReview> {
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
      ],
    );
  }
}
