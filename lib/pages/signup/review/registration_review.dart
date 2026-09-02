import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/review/divorced_review.dart';
import 'package:snabbit_runner/pages/signup/review/married_review.dart';
import 'package:snabbit_runner/pages/signup/review/prior_experience_review.dart';
import 'package:snabbit_runner/pages/signup/review/unmarried_review.dart';
import 'package:snabbit_runner/pages/signup/review/widowed_review.dart';
import 'package:snabbit_runner/pages/signup/review/work_experience_review.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';

import '../../../utils/common_methods.dart';
import '../../../utils/enums.dart';
import '../../../widgets/gap.dart';
import '../../../widgets/onboarding_question.dart';
import '../../../widgets/progress_indicator.dart';
import 'personal_details_review.dart';

class RegistrationReview extends StatefulWidget {
  static const String routeName = "/registration_review";

  const RegistrationReview({super.key});

  @override
  State<RegistrationReview> createState() => _RegistrationReviewState();
}

class _RegistrationReviewState extends State<RegistrationReview> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  UserProfile? userProfile;

  // Add a scroll controller and a boolean to track if at bottom
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;
  bool _isScrollable = true;

  @override
  void initState() {
    super.initState();

    // Add listener to the scroll controller
    _scrollController.addListener(_onScroll);

    // Check if content is scrollable after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.position.maxScrollExtent == 0) {
        setState(() {
          _isScrollable = false;
          _isAtBottom = true; // If not scrollable, consider it at bottom
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Check if we're at the bottom of the scroll view
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_isAtBottom) {
        setState(() {
          _isAtBottom = true;
        });
      }
    }
  }

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

  Widget get maritalStatusView {
    switch (userProfileProvider.user?.maritalStatus) {
      case MaritalStatus.married:
        return const MarriedReview();
      case MaritalStatus.divorced:
        return const DivorcedReview();
      case MaritalStatus.widow:
        return const WidowedReview();
      case MaritalStatus.unmarried:
        return const UnmarriedReview();
      default:
        return const UnmarriedReview();
    }
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await userProfileProvider.editDetailsReviewAction();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        side: const BorderSide(color: AppColors.brand),
                      ),
                      child: Text(
                        languageProvider.getMessage(
                          'edit_details',
                          'Edit details',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isAtBottom || !_isScrollable)
                          ? () async {
                              await userProfileProvider
                                  .runnerRegistrationAndErrorHandler(
                                context: context,
                                onError: (errorMessage) {
                                  showSnackbar(context,
                                      errorMessage ?? "Something went wrong");
                                },
                              );
                            }
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
              ),
            ],
            body: userProfile == null
                ? const Center(
                    child: Text("Something went wrong. Restart the app"),
                  )
                : SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ProgressIndicatorAtTop(),
                        Gap.gap32h,
                        const OnboardingPageHeader(
                          titleKey: "review_title",
                          titleDefault: "Review Details",
                          subtitleKey: 'review_subtitle',
                          subtitleDefault:
                              "Please review carefully, no changes can be made after this step",
                        ),
                        const ReviewHeader(
                          data: 'Personal Details',
                        ),
                        const PersonalDetailsReview(),
                        maritalStatusView,
                        const ReviewHeader(
                          data: 'Work Experience',
                        ),
                        const WorkExperienceReview(),
                        const ReviewHeader(
                          data: 'Additional Details',
                        ),
                        const PriorExperienceReview(),
                      ],
                    ),
                  ),
          );
  }
}

class ReviewAnswer extends StatelessWidget {
  final String data;

  const ReviewAnswer({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500, fontSize: 14.sp, color: AppColors.n70),
    );
  }
}

class ReviewBoolAnswer extends StatelessWidget {
  final bool? data;

  const ReviewBoolAnswer({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Text(
          data == true
              ? languageProvider.getMessage('yes', 'Yes')
              : languageProvider.getMessage('no', 'No'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 14.sp,
              color: AppColors.n70),
        );
      },
    );
  }
}

class ReviewHeader extends StatelessWidget {
  final String data;

  const ReviewHeader({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 24.h,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1.h,
              color: AppColors.n90,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            data,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Divider(
              height: 1.h,
              color: AppColors.n90,
            ),
          ),
        ],
      ),
    );
  }
}
