import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/dob_selector_v2.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question_v2.dart';

class InsuranceDetailsV2 extends StatefulWidget {
  static const String routeName = "/insurance_details_v2";

  const InsuranceDetailsV2({super.key});

  @override
  State<InsuranceDetailsV2> createState() => _InsuranceDetailsV2State();
}

class _InsuranceDetailsV2State extends State<InsuranceDetailsV2> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();

  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late LanguageProvider languageProvider;
  bool init = true;

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
        dayController.text = picked.day.toString().padLeft(2, '0');
        monthController.text = picked.month.toString().padLeft(2, '0');
        yearController.text = picked.year.toString();
      });
      userProfile.nominee?.dob = picked;
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
      userProfile = userProfileProvider.user!;
      fullNameController.text = userProfile.nominee?.name ?? '';
      contactNumberController.text = userProfile.nominee?.phone ?? '';
      if (userProfile.nominee != null) {
        DateTime? dobNominee = userProfile.nominee!.dob;
        if (dobNominee != null) {
          dayController.text = dobNominee.day.toString().padLeft(2, '0');
          monthController.text = dobNominee.month.toString().padLeft(2, '0');
          yearController.text = dobNominee.year.toString();
        }
      }
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

  bool get enableNomineeField => userProfile.nominee != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
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
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: userProfileProvider.loading
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Todo: Set this value. It was 8 in the prod version
                    const OnboardingProgressBar(progressValue: 8),
                    Gap.gap32h,
                    Text(
                      languageProvider.getMessage(
                        'nominee_title',
                        'Nominee Details for Insurance',
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Gap.gap16h,
                    OnboardingQuestionV2(
                      mandatory: true,
                      // Todo: key does not exist
                      questionKey: 'do_you_have_a_nominee',
                      questionDefault: 'Do you have a nominee?',
                      answer: Row(
                        children: [
                          // Yes Button
                          GestureDetector(
                            onTap: () {
                              userProfile.nominee ??= Nominee();
                              userProfileProvider.notifyUserListeners();
                            },
                            child: Row(
                              children: [
                                // Todo: set the value from the provider
                                CircularCheckbox(value: enableNomineeField),
                                Gap.gap8w,
                                Text(
                                  languageProvider.getMessage(
                                    "yes",
                                    "Yes",
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: AppColors.n80),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 24.w),
                          // No Button
                          GestureDetector(
                            onTap: () {
                              userProfile.nominee = null;
                              userProfileProvider.notifyUserListeners();
                            },
                            child: Row(
                              children: [
                                // Todo: set the value from the provider
                                CircularCheckbox(value: !enableNomineeField),
                                Gap.gap8w,
                                Text(
                                  languageProvider.getMessage(
                                    "no",
                                    "No",
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: AppColors.n80),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestionV2(
                      mandatory: true,
                      // Todo: key does not exist
                      questionKey: 'full_name',
                      questionDefault: 'Full name of nominee',
                      isEnabled: enableNomineeField,
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          TextField(
                            controller: fullNameController,
                            enabled: enableNomineeField,
                            onChanged: (v) {
                              userProfile.nominee?.name = v;
                              userProfileProvider.notifyUserListeners();
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z ]')),
                            ],
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              hintText: 'Enter name',
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                      color: enableNomineeField
                                          ? AppColors.n50
                                          : AppColors.n30),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestionV2(
                      mandatory: true,
                      questionKey: 'date_of_birth',
                      questionDefault: 'Date of Birth',
                      isEnabled: enableNomineeField,
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          DobSelectorV2(
                            onTap: () {
                              _selectDate(context);
                            },
                            enabled: enableNomineeField,
                            dobDay: dayController,
                            dobMonth: monthController,
                            dobYear: yearController,
                          ),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestionV2(
                      mandatory: true,
                      questionKey: 'contact_number',
                      questionDefault: 'Contact number',
                      error: (userProfile.nominee?.phone != null &&
                              userProfile.nominee?.phone?.length != 10)
                          ? "Please enter a valid contact number"
                          : null,
                      isEnabled: enableNomineeField,
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          TextFormField(
                            controller: contactNumberController,
                            maxLength: 10,
                            onChanged: (v) {
                              setState(() {
                                if (v.isNotEmpty) {
                                  userProfile.nominee?.phone = v;
                                } else {
                                  userProfile.nominee?.phone = null;
                                }
                              });
                            },
                            enabled: enableNomineeField,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9]')),
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(),
                              hintText: languageProvider.getMessage(
                                'contact_number_hint',
                                'Enter the contact number',
                              ),
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                      color: enableNomineeField
                                          ? AppColors.n50
                                          : AppColors.n30),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestionV2(
                      mandatory: true,
                      questionKey: 'nominee_relationship',
                      questionDefault: 'Relationship - He/she is your',
                      isEnabled: enableNomineeField,
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 3,
                            mainAxisSpacing: 3,
                            childAspectRatio: 4,
                            children: GlobalState()
                                    .appConfig
                                    ?.nomineesRelations
                                    ?.map((relation) {
                                  return GestureDetector(
                                    onTap: enableNomineeField
                                        ? () {
                                            userProfile.nominee ??= Nominee();
                                            userProfile.nominee?.relationship =
                                                relation;
                                            userProfileProvider
                                                .notifyUserListeners();
                                          }
                                        : null,
                                    child: Row(
                                      children: [
                                        CircularCheckbox(
                                          value: userProfile
                                                  .nominee?.relationship ==
                                              relation,
                                        ),
                                        Gap.gap8w,
                                        Text(
                                          languageProvider.getMessage(
                                            relation,
                                            relation,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: enableNomineeField
                                                    ? AppColors.n80
                                                    : AppColors.n40,
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList() ??
                                [],
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

  bool continueConditions() {
    try {
      // Todo: Re-evaluate this condition
      if (userProfile.nominee == null) {
        return true;
      } else if (userProfile.nominee?.name != null &&
          userProfile.nominee!.name!.trim().isNotEmpty &&
          userProfile.nominee?.dob != null &&
          (userProfile.nominee?.phone != null &&
              userProfile.nominee?.phone?.length == 10) &&
          userProfile.nominee?.relationship != null) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
