import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:snabbit_runner/widgets/dob_selector.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import '../../services/runner_http.dart';
import '../../widgets/circular_checkbox.dart';
import '../../utils/common_methods.dart';
import '../../utils/custom_themes/text_themes.dart';
import '../../utils/runner_registration_step.dart';
import '../../widgets/onboarding_question.dart';
import 'availability_details.dart';

class InsuranceDetails extends StatefulWidget {
  static const String routeName = "/insurance_details";

  const InsuranceDetails({super.key});

  @override
  State<InsuranceDetails> createState() => _InsuranceDetailsState();
}

class _InsuranceDetailsState extends State<InsuranceDetails> {
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
    DateTime date = currentDate.subtract(const Duration(days: 365*18));
    final leapDays = countLeapYearsBetween(date, currentDate);
    date=date.subtract(Duration(days: leapDays));
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

      // nomineeDob =
      //     "${yearController.text}-${monthController.text}=${dayController.text}";
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
      // userProfile.registrationStep = RunnerRegistrationStep.insurance;
      fullNameController.text = userProfile.nominee?.name ?? '';
      contactNumberController.text = userProfile.nominee?.phone ?? '';
      // nomineeRelation = userProfile.nominee?.relationship ?? '';

      if (userProfile.nominee != null) {
        DateTime? dobNominee = userProfile.nominee!.dob;
        if (dobNominee != null) {
          dayController.text = dobNominee.day.toString().padLeft(2, '0');
          monthController.text = dobNominee.month.toString().padLeft(2, '0');
          yearController.text = dobNominee.year.toString();
          // nomineeDob =
          //     "${yearController.text}-${monthController.text}-${dayController.text}";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
      persistentFooterButtons: [
        SizedBox(
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
                    const ProgressIndicatorAtTop(value: 8),
                    Gap.gap32h,
                    const OnboardingPageHeader(
                      titleKey: 'nominee_title',
                      titleDefault: 'Nominee Details for Insurance',
                      subtitleKey: 'nominee_subtitle',
                      subtitleDefault:
                          'Please provide accurate nominee information',
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'full_name',
                      questionDefault: 'Full name',
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          TextField(
                            controller: fullNameController,
                            onChanged: (v) {
                              userProfile.nominee?.name = v;
                              userProfileProvider.notifyUserListeners();
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                            ],
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              hintText: 'Enter nominee name',
                              hintStyle: AppTextTheme.hintStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'date_of_birth',
                      questionDefault: 'Date of Birth',
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
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'contact_number',
                      questionDefault: 'Contact number',
                      error: (userProfile.nominee?.phone != null &&
                              userProfile.nominee?.phone?.length != 10)
                          ? "Please enter a valid contact number"
                          : null,
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
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9]')),
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              border: const OutlineInputBorder(),
                              hintText: languageProvider.getMessage(
                                'contact_number_hint',
                                'Enter the contact number',
                              ),
                              hintStyle: AppTextTheme.hintStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'nominee_relationship',
                      questionDefault: 'Relationship - He/she is your',
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
                            children: GlobalState().appConfig?.nomineesRelations?.map((relation) {
                              return GestureDetector(
                                onTap: () {
                                  if (userProfile != null &&
                                      userProfile.nominee == null) {
                                    userProfile.nominee = Nominee();
                                  }
                                  userProfile.nominee?.relationship = relation;
                                  userProfileProvider.notifyUserListeners();
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                        value:
                                            userProfile.nominee?.relationship ==
                                                relation),
                                    Gap.gap3w,
                                    Text(
                                      languageProvider.getMessage(
                                        relation,
                                        relation,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              );
                            }).toList()??[],
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
      if (userProfile.nominee?.name != null &&
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
