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

class SingleChildDetails extends StatefulWidget {
  static const String routeName = "/single-child-details";

  const SingleChildDetails({super.key});

  @override
  State<SingleChildDetails> createState() => _SingleChildDetailsState();
}

class _SingleChildDetailsState extends State<SingleChildDetails> {
  final TextEditingController childNameController = TextEditingController();
  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();

  // User DOB details
  final TextEditingController userDayController = TextEditingController();
  final TextEditingController userMonthController = TextEditingController();
  final TextEditingController userYearController = TextEditingController();

  Gender? selectedGender;

  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  bool init = true;
  bool showUserDob = true;

  void _selectDate(BuildContext context) async {
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
        dayController.text = picked.day.toString().padLeft(2, '0');
        monthController.text = picked.month.toString().padLeft(2, '0');
        yearController.text = picked.year.toString();
      });
      userProfileProvider.user?.insuranceData?.firstChildDob = picked;
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
      });
      userProfileProvider.user?.dob?.value = picked;
      userProfileProvider.notifyUserListeners();
    }
  }

  bool canContinue() {
    return !userProfileProvider.loading &&
        userProfileProvider.user?.dob?.value != null &&
        userProfileProvider.user?.insuranceData?.firstChildName != null &&
        userProfileProvider.user?.insuranceData?.firstChildName?.trim().isNotEmpty == true &&
        userProfileProvider.user?.insuranceData?.firstChildGender != null &&
        userProfileProvider.user?.insuranceData?.firstChildDob != null;
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      childNameController.text =
          userProfileProvider.user?.insuranceData?.firstChildName ?? '';
      selectedGender = userProfileProvider.user?.insuranceData?.firstChildGender;
      if (userProfileProvider.user?.otherDetails != null) {
        DateTime? childDob =
            userProfileProvider.user?.insuranceData?.firstChildDob;
        if (childDob != null) {
          dayController.text = childDob.day.toString().padLeft(2, '0');
          monthController.text = childDob.month.toString().padLeft(2, '0');
          yearController.text = childDob.year.toString();
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

                    // Child name field
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'child_name',
                      questionDefault: 'Details of child',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          TextField(
                            controller: childNameController,
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
                      questionKey: 'child_dob',
                      questionDefault: 'Date of Birth of child',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          DobSelector(
                            onTap: () {
                              _selectDate(context);
                            },
                            dobDay: dayController,
                            dobMonth: monthController,
                            dobYear: yearController,
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
                      questionKey: 'child_gender',
                      questionDefault: 'Gender of child',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedGender = Gender.MALE;
                                    userProfileProvider.user?.insuranceData
                                        ?.firstChildGender = selectedGender;
                                    userProfileProvider.notifyUserListeners();
                                  });
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                      value: selectedGender == Gender.MALE,
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
                                    selectedGender = Gender.FEMALE;
                                    userProfileProvider.user?.insuranceData
                                        ?.firstChildGender = selectedGender;
                                    userProfileProvider.notifyUserListeners();
                                  });
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                      value: selectedGender == Gender.FEMALE,
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
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
    childNameController.dispose();
    userDayController.dispose();
    userMonthController.dispose();
    userYearController.dispose();
    super.dispose();
  }
}
