import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/dob_selector.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';

class MultipleChildDetails extends StatefulWidget {
  static const String routeName = "/multiple-child-details";

  const MultipleChildDetails({super.key});

  @override
  State<MultipleChildDetails> createState() => _MultipleChildDetailsState();
}

class _MultipleChildDetailsState extends State<MultipleChildDetails> {
  //for 1st child
  final TextEditingController child1NameController = TextEditingController();
  final TextEditingController child1DayController = TextEditingController();
  final TextEditingController child1MonthController = TextEditingController();
  final TextEditingController child1YearController = TextEditingController();
  Gender? child1Gender;

  //for 2nd child
  final TextEditingController child2NameController = TextEditingController();
  final TextEditingController child2DayController = TextEditingController();
  final TextEditingController child2MonthController = TextEditingController();
  final TextEditingController child2YearController = TextEditingController();
  Gender? child2Gender;

  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  bool init = true;

  // User DOB details
  final TextEditingController userDayController = TextEditingController();
  final TextEditingController userMonthController = TextEditingController();
  final TextEditingController userYearController = TextEditingController();

  bool showUserDob = true;

  void _selectDateForChild1(BuildContext context) async {
    final currentDate = DateTime.now();
    final firstDate = currentDate.subtract(
        const Duration(days: 365 * 25));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: firstDate,
      lastDate: currentDate,
    );
    if (picked != null) {
      setState(() {
        child1DayController.text = picked.day.toString().padLeft(2, '0');
        child1MonthController.text = picked.month.toString().padLeft(2, '0');
        child1YearController.text = picked.year.toString();
      });
      userProfileProvider.user?.insuranceData?.firstChildDob = picked;
      userProfileProvider.notifyUserListeners();
    }
  }

  void _selectDateForChild2(BuildContext context) async {
    final currentDate = DateTime.now();
    final firstDate = currentDate.subtract(
        const Duration(days: 365 * 25));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: firstDate,
      lastDate: currentDate,
    );
    if (picked != null) {
      setState(() {
        child2DayController.text = picked.day.toString().padLeft(2, '0');
        child2MonthController.text = picked.month.toString().padLeft(2, '0');
        child2YearController.text = picked.year.toString();
      });
      userProfileProvider.user?.insuranceData?.secondChildDob = picked;
      userProfileProvider.notifyUserListeners();
    }
  }

  void _selectUserDob(BuildContext context) async {
    final currentDate = DateTime.now();
    final firstDate = currentDate.subtract(
        const Duration(days: 365 * 60)); // assuming the standard retirement age
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: firstDate,
      lastDate: currentDate,
    );
    if (picked != null) {
      setState(() {
        userDayController.text = picked.day.toString().padLeft(2, '0');
        userMonthController.text = picked.month.toString().padLeft(2, '0');
        userYearController.text = picked.year.toString();
        // _validateForm();
      });
      userProfileProvider.user?.dob?.value = picked;
      userProfileProvider.notifyUserListeners();
    }
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      //FIRST CHILD
      child1NameController.text =
          userProfileProvider.user?.insuranceData?.firstChildName ?? '';
      child1Gender = userProfileProvider.user?.insuranceData?.firstChildGender;
      if (userProfileProvider.user?.otherDetails != null) {
        DateTime? childDob =
            userProfileProvider.user?.insuranceData?.firstChildDob;
        if (childDob != null) {
          child1DayController.text = childDob.day.toString().padLeft(2, '0');
          child1MonthController.text =
              childDob.month.toString().padLeft(2, '0');
          child1YearController.text = childDob.year.toString();
        }
      }

      //SECOND CHILD
      child2NameController.text =
          userProfileProvider.user?.insuranceData?.secondChildName ?? '';
      child2Gender = userProfileProvider.user?.insuranceData?.secondChildGender;
      if (userProfileProvider.user?.otherDetails != null) {
        DateTime? childDob =
            userProfileProvider.user?.insuranceData?.secondChildDob;
        if (childDob != null) {
          child2DayController.text = childDob.day.toString().padLeft(2, '0');
          child2MonthController.text =
              childDob.month.toString().padLeft(2, '0');
          child2YearController.text = childDob.year.toString();
        }
      }

      if (userProfileProvider.user?.dob?.value != null) {
        showUserDob = false;
      }
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

  bool canContinue() {
    return !userProfileProvider.loading &&
        ((userProfileProvider.user?.dob?.value != null &&
        userProfileProvider.user?.insuranceData?.firstChildName != null &&
        userProfileProvider.user?.insuranceData?.firstChildName?.trim().isNotEmpty == true &&
        userProfileProvider.user?.insuranceData?.firstChildGender != null &&
        userProfileProvider.user?.insuranceData?.firstChildDob != null &&
        userProfileProvider.user?.insuranceData?.secondChildName != null &&
        userProfileProvider.user?.insuranceData?.secondChildName?.trim().isNotEmpty == true &&
        userProfileProvider.user?.insuranceData?.secondChildGender != null &&
        userProfileProvider.user?.insuranceData?.secondChildDob != null)
            && (userProfileProvider.user?.insuranceData?.firstChildName?.trim() != userProfileProvider.user?.insuranceData?.secondChildName?.trim()
            )
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
            onPressed: canContinue() ? onContinue : null,
            child: Text(
              languageProvider.getMessage(
                'continue',
                'Continue',
              ),
            ),
          ),
        ),
      ],
      body: init || userProfileProvider.loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProgressIndicatorAtTop(value: 8),
                    Gap.gap32h,

                    // Date of birth field for Logged in User
                    if (showUserDob)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OnboardingQuestion(
                            mandatory: true,
                            questionKey: 'user_dob',
                            questionDefault: 'Your date of birth',
                            answer: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Gap.gap8h,
                                DobSelector(
                                  onTap: () {
                                    _selectUserDob(context);
                                  },
                                  dobDay: userDayController,
                                  dobMonth: userMonthController,
                                  dobYear: userYearController,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 6.h, horizontal: 16.w),
                            child: const Divider(
                              color: Color(0xFFE6E8F0),
                            ),
                          ),
                          SizedBox(
                            height: 18.h,
                          )
                        ],
                      ),

                    // Title and subtitle
                    const OnboardingPageHeader(
                      titleKey: 'children_insurance_details',
                      titleDefault: 'Children Details for Insurance',
                      subtitleKey: 'children_insurance_details_subtitle',
                      subtitleDefault:
                          'Insurance is provided for a maximum of 2 children',
                    ),
                    Gap.gap16h,

                    // FOR FIRST CHILD
                    // Child name field
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'first_child_name',
                      questionDefault: 'Details of first child',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          TextField(
                            controller: child1NameController,
                            onChanged: (value) {
                              userProfileProvider
                                  .user?.insuranceData?.firstChildName = value;
                              userProfileProvider.notifyUserListeners();
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                            ],
                            decoration: InputDecoration(
                              hintText: 'Enter child name',
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    letterSpacing: -0.24,
                                    color: AppColors.n50,
                                  ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16.w),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 24.h,
                    ),

                    // Date of birth field
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'first_child_dob',
                      questionDefault: 'Date of Birth of first child',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          DobSelector(
                            onTap: () {
                              _selectDateForChild1(context);
                            },
                            dobDay: child1DayController,
                            dobMonth: child1MonthController,
                            dobYear: child1YearController,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 24.h,
                    ),

                    // Gender selection
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'first_child_gender',
                      questionDefault: 'Gender of first child',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    child1Gender = Gender.MALE;
                                    userProfileProvider.user?.insuranceData
                                        ?.firstChildGender = child1Gender;
                                    userProfileProvider.notifyUserListeners();
                                  });
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                      value: child1Gender == Gender.MALE,
                                      borderColor: AppColors.n40,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Male',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 24.w),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    child1Gender = Gender.FEMALE;
                                    userProfileProvider.user?.insuranceData
                                        ?.firstChildGender = child1Gender;
                                    userProfileProvider.notifyUserListeners();
                                  });
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                      value: child1Gender == Gender.FEMALE,
                                      borderColor: AppColors.n40,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Female',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // FOR SECOND CHILD
                    // Title and subtitle
                    Gap.gap16h,

                    // Child name field
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'second_child_name',
                      questionDefault: 'Details of second child',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          TextField(
                            controller: child2NameController,
                            onChanged: (value) {
                              userProfileProvider
                                  .user?.insuranceData?.secondChildName = value;
                              userProfileProvider.notifyUserListeners();
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                            ],
                            decoration: InputDecoration(
                              hintText: 'Enter child name',
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    letterSpacing: -0.24,
                                    color: AppColors.n50,
                                  ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16.w),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 24.h,
                    ),

                    // Date of birth field
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'second_child_dob',
                      questionDefault: 'Date of Birth of second child',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          DobSelector(
                            onTap: () {
                              _selectDateForChild2(context);
                            },
                            dobDay: child2DayController,
                            dobMonth: child2MonthController,
                            dobYear: child2YearController,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 24.h,
                    ),

                    // Gender selection
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'second_child_gender',
                      questionDefault: 'Gender of second child',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    child2Gender = Gender.MALE;
                                    userProfileProvider.user?.insuranceData
                                        ?.secondChildGender = child2Gender;
                                    userProfileProvider.notifyUserListeners();
                                  });
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                      value: child2Gender == Gender.MALE,
                                      borderColor: AppColors.n40,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Male',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 24.w),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    child2Gender = Gender.FEMALE;
                                    userProfileProvider.user?.insuranceData
                                        ?.secondChildGender = child2Gender;
                                    userProfileProvider.notifyUserListeners();
                                  });
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                      value: child2Gender == Gender.FEMALE,
                                      borderColor: AppColors.n40,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Female',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    child1NameController.dispose();
    child1DayController.dispose();
    child1MonthController.dispose();
    child1YearController.dispose();
    child2NameController.dispose();
    child2DayController.dispose();
    child2MonthController.dispose();
    child2YearController.dispose();
    userDayController.dispose();
    userMonthController.dispose();
    userYearController.dispose();
    super.dispose();
  }
}
