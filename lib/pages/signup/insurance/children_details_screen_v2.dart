import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/dob_selector_v2.dart';
import 'package:snabbit_runner/widgets/onboarding_question_v2.dart';
import 'package:snabbit_runner/widgets/text_form.dart';

class ChildrenDetailsScreenV2 extends StatefulWidget {
  final int childIndex;
  final int totalChildren;
  const ChildrenDetailsScreenV2(
      {super.key, required this.childIndex, required this.totalChildren});

  @override
  State<ChildrenDetailsScreenV2> createState() =>
      _ChildrenDetailsScreenV2State();
}

class _ChildrenDetailsScreenV2State extends State<ChildrenDetailsScreenV2> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
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

  // Todo: Keys do not exist
  String get childNameQuestionKey => widget.totalChildren == 1
      ? 'child_name'
      : 'child_${widget.childIndex + 1}_name';

  String get childNameQuestionFallbackText {
    if (widget.totalChildren == 1) return 'Name of child ';

    final positionNames = ['first', 'second'];
    final position = positionNames[widget.childIndex];

    return 'Name of $position child ';
  }

  bool get genderOfChildIsMale {
    if (widget.childIndex == 0) {
      return userProfile.insuranceData?.firstChildGender == Gender.MALE;
    } else if (widget.childIndex == 1) {
      return userProfile.insuranceData?.secondChildGender == Gender.MALE;
    }
    return false;
  }

  bool get genderOfChildIsFeMale {
    if (widget.childIndex == 0) {
      return userProfile.insuranceData?.firstChildGender == Gender.FEMALE;
    } else if (widget.childIndex == 1) {
      return userProfile.insuranceData?.secondChildGender == Gender.FEMALE;
    }
    return false;
  }

  bool continueConditions() {
    bool firstChildDetailsAreComplete = (userProfileProvider
                .user?.insuranceData?.firstChildName
                ?.trim()
                .isNotEmpty ==
            true) &&
        (userProfileProvider.user?.insuranceData?.firstChildDob != null) &&
        (userProfileProvider.user?.insuranceData?.firstChildGender != null);
    bool secondChildDetailsAreComplete = (userProfileProvider
                .user?.insuranceData?.secondChildName
                ?.trim()
                .isNotEmpty ==
            true) &&
        (userProfileProvider.user?.insuranceData?.secondChildDob != null) &&
        (userProfileProvider.user?.insuranceData?.secondChildGender != null);

    if (widget.childIndex == 0 && firstChildDetailsAreComplete) {
      return true;
    } else if (widget.childIndex == 1 && secondChildDetailsAreComplete) {
      return true;
    } else {
      return false;
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

  void _selectDate(BuildContext context) async {
    final currentDate = DateTime.now();
    DateTime date = currentDate.subtract(const Duration(days: 365 * 18));
    final leapDays = countLeapYearsBetween(date, currentDate);
    date = date.subtract(Duration(days: leapDays));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(1900),
      lastDate: date,
    );
    if (picked != null) {
      setState(() {
        _dayController.text = picked.day.toString().padLeft(2, '0');
        _monthController.text = picked.month.toString().padLeft(2, '0');
        _yearController.text = picked.year.toString();
      });
      if (widget.childIndex == 0) {
        userProfile.insuranceData?.firstChildDob = picked;
      } else {
        userProfile.insuranceData?.secondChildDob = picked;
      }
      userProfileProvider.notifyUserListeners();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(),
      persistentFooterButtons: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: SizedBox(
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
        ),
      ],
      body: SingleChildScrollView(
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
                'children_insurance_details',
                'Children Details for Insurance',
              ),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 38.h),
            OnboardingQuestionV2(
              mandatory: true,
              questionKey: childNameQuestionKey,
              questionDefault: childNameQuestionFallbackText,
              padding: EdgeInsets.zero,
              answer: TextFormSnabbit(
                controller: _nameController,
                // Todo: key does not exist
                hintText: languageProvider.getMessage(
                  'child_name_hint',
                  "Enter Child's name",
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    if (widget.childIndex == 0) {
                      userProfile.insuranceData?.firstChildName = value;
                    } else {
                      userProfile.insuranceData?.secondChildName = value;
                    }
                  }
                  userProfileProvider.notifyUserListeners();
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                ],
              ),
            ),
            SizedBox(height: 40.h),
            OnboardingQuestionV2(
              mandatory: true,
              // Todo: key does not exist
              questionKey: 'date_of_birth_of_child',
              questionDefault: 'Date of Birth of child',
              padding: EdgeInsets.zero,
              answer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DobSelectorV2(
                    onTap: () {
                      _selectDate(context);
                    },
                    dobDay: _dayController,
                    dobMonth: _monthController,
                    dobYear: _yearController,
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),
            OnboardingQuestionV2(
              questionKey: 'gender_of_child',
              questionDefault: 'Gender of child ',
              mandatory: true,
              padding: EdgeInsets.zero,
              answer: Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if(widget.childIndex==0) {
                          userProfile.insuranceData?.firstChildGender =
                              Gender.MALE;
                        }
                        else {
                          userProfile.insuranceData?.secondChildGender =
                              Gender.MALE;
                        }
                        userProfileProvider.notifyUserListeners();
                      },
                      child: Row(
                        children: [
                          CircularCheckbox(value: genderOfChildIsMale),
                          SizedBox(width: 8.w),
                          Text(
                            languageProvider.getMessage(
                              'male',
                              'Male',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 24.w),
                    GestureDetector(
                      onTap: () {
                        if(widget.childIndex==0) {
                          userProfile.insuranceData?.firstChildGender =
                              Gender.FEMALE;
                        }
                        else {
                          userProfile.insuranceData?.secondChildGender =
                              Gender.FEMALE;
                        }
                        userProfileProvider.notifyUserListeners();
                      },
                      child: Row(
                        children: [
                          CircularCheckbox(value: genderOfChildIsFeMale),
                          SizedBox(width: 8.w),
                          Text(
                            languageProvider.getMessage(
                              'female',
                              'Female',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
