import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart' show Provider;
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';

class ChildrenCountScreen extends StatefulWidget {
  const ChildrenCountScreen({super.key});

  @override
  State<ChildrenCountScreen> createState() => _ChildrenCountScreenState();
}

class _ChildrenCountScreenState extends State<ChildrenCountScreen> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 6.h),
              // Todo: Calculate and set this value
              OnboardingProgressBar(
                progressValue: 0.8,
                padding: EdgeInsets.zero,
              ),
              SizedBox(height: 32.h),
              Text(
                languageProvider.getMessage(
                  'how_many_kids',
                  'How many kids do you have?',
                ),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 38.h),
              Row(
                children: List.generate(5, (index) {
                  return Flexible(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        userProfile.otherDetails!
                            .numberOfChildren?.value = index;
                        userProfileProvider.notifyUserListeners();
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Container(
                              height: 53.h,
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: userProfile.otherDetails!
                                                .numberOfChildren?.value ==
                                            index
                                        ? AppColors.brand
                                        : AppColors.n40),
                                borderRadius: BorderRadius.circular(10.r),
                                color: Colors.white,
                              ),
                              child: Center(
                                child: Text(
                                  index == 4 ? "$index+" : (index).toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: AppColors.n80,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 8.5.w,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
