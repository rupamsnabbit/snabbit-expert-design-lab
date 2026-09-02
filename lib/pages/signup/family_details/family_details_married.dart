// ignore_for_file: use_build_context_synchronously
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/ui_helper.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'dart:async';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import 'package:snabbit_runner/widgets/dob_selector.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/text_form.dart';
import 'package:snabbit_runner/widgets/true_false_radio_button.dart';
import '../../../providers/user_profile.dart';

import '../../../utils/colors.dart';
import '../../../utils/custom_themes/text_themes.dart';
import '../../../widgets/onboarding_question.dart';

class FamilyDetailsIfMarried extends StatefulWidget {
  static const String routeName = "/family_details_married";

  const FamilyDetailsIfMarried({super.key});

  @override
  State<FamilyDetailsIfMarried> createState() => _FamilyDetailsIfMarriedState();
}

class _FamilyDetailsIfMarriedState extends State<FamilyDetailsIfMarried> {
  TextEditingController spouseNameController = TextEditingController();
  TextEditingController spouseMonthlyIncomeController = TextEditingController();

  // TextEditingController dobDay = TextEditingController();
  // TextEditingController dobMonth = TextEditingController();
  // TextEditingController dobYear = TextEditingController();
  TextEditingController ageController = TextEditingController();

  //  localization
  List<String>? spouseOccupationChoices;

  // bool? spouseKnowAboutRole;
  // bool? isDecisionSupportedBySpouse;
  // bool? stayWithParents;
  // bool? isDecisionSupportedByInLaws;
  bool? haveChildren;

  // dynamic numberofKids = 0;
  // final List<String> kidsCount = ["1", "2", "3", "4"];
  // String dobYoungestKid = "";

///////
  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late LanguageProvider languageProvider;
  bool init = true;

  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();

  // String? selectedOccupation;
  // Map<SpouseOccupation, String> occupations = {
  //   SpouseOccupation.FOOD_DELIVERY: "Food delivery",
  //   SpouseOccupation.GROCERY_DELIVERY: "Grocery delivery",
  //   SpouseOccupation.PUBLIC_TRANSPORT: "Public transport",
  //   SpouseOccupation.FACTORY_WORKER: "Factory worker",
  //   SpouseOccupation.CONSTRUCTION_WORKER: "Construction worker",
  //   SpouseOccupation.UNEMPLOYED: "Unemployed",
  //   SpouseOccupation.OTHER: "Others"
  // };
  // void _selectDate(BuildContext context) async {
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime.now(),
  //     firstDate: DateTime(1900),
  //     lastDate: DateTime.now(),
  //   );
  //   if (picked != null) {
  //     userProfile.otherDetails!.dobOfYoungestChild = picked;
  //     userProfileProvider.notifyUserListeners();
  //     setState(() {
  //       dobDay.text = picked.day.toString().padLeft(2, '0');
  //       dobMonth.text = picked.month.toString().padLeft(2, '0');
  //       dobYear.text = picked.year.toString();
  //     });
  //   }
  // }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;

      // userProfile.registrationStep = RunnerRegistrationStep.family;

      spouseNameController = TextEditingController(
          text: userProfile.insuranceData?.spouseName ?? '');
      spouseMonthlyIncomeController = TextEditingController(
          text: userProfile.otherDetails?.spouseMonthlyIncome?.value != null
              ? userProfile.otherDetails?.spouseMonthlyIncome?.value.toString()
              : '');

      if (userProfile.otherDetails?.numberOfChildren?.value != null) {
        haveChildren = userProfile.otherDetails!.numberOfChildren!.value! > 0;
      }
      ageController.text =
          "${userProfileProvider.user?.otherDetails?.ageOfYoungestChild?.value ?? ""}";

      if (userProfileProvider.user?.insuranceData != null) {
        DateTime? spouseDob =
            userProfileProvider.user?.insuranceData?.spouseDob;
        if (spouseDob != null) {
          dayController.text = spouseDob.day.toString().padLeft(2, '0');
          monthController.text = spouseDob.month.toString().padLeft(2, '0');
          yearController.text = spouseDob.year.toString();
        }
      }

      // spouseKnowAboutRole = userProfile.otherDetails?.spouseKnowAboutJob;
      // isDecisionSupportedBySpouse = userProfile.otherDetails?.spouseApproval;
      // stayWithParents = userProfile.otherDetails?.stayWithParents;
      // isDecisionSupportedByInLaws = userProfile.otherDetails?.inLawsApproval;
      // haveChildren = userProfile.otherDetails?.numberOfChildren != null &&
      //         userProfile.otherDetails!.numberOfChildren! > 0
      //     ? true
      //     : false;
      // numberofKids = userProfile.otherDetails?.numberOfChildren;

      DateTime? youngestChildDobBackend =
          userProfile.otherDetails?.dobOfYoungestChild;

      // if (youngestChildDobBackend != null) {
      //   dobDay.text = youngestChildDobBackend.day.toString().padLeft(2, '0');
      //   dobMonth.text =
      //       youngestChildDobBackend.month.toString().padLeft(2, '0');
      //   dobYear.text = youngestChildDobBackend.year.toString();
      // }

      // dobYoungestKid = "${dobYear.text}-${dobMonth.text}-${dobDay.text}";

      spouseOccupationChoices =
          GlobalState().appConfig?.spouseOccupationChoices;

      // print("\n\n GlobalState().appConfig details started\n");
      // // print("jobChangeReasons => ${GlobalState().appConfig?.jobChangeReasons}");
      // // print("leaveCountChoices => ${GlobalState().appConfig?.leaveCountChoices}");
      // // print("availabilityToWorkChoices => ${GlobalState().appConfig?.availabilityToWorkChoices}");
      // // print("vehiclesUsed => ${GlobalState().appConfig?.vehiclesUsed}");
      // // print("jobPreferredTimeChoices => ${GlobalState().appConfig?.jobPreferredTimeChoices}");
      // print("spouseOccupationChoices => ${GlobalState().appConfig?.spouseOccupationChoices}");
      // print("\n GlobalState().appConfig details ended\n\n");

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

  void _selectDate(BuildContext context) async {
    final currentDate = DateTime.now();
    final initialDate = currentDate.subtract(const Duration(days: 365 * 18));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: initialDate,
    );
    if (picked != null) {
      setState(() {
        dayController.text = picked.day.toString().padLeft(2, '0');
        monthController.text = picked.month.toString().padLeft(2, '0');
        yearController.text = picked.year.toString();
      });
      userProfileProvider.user?.insuranceData?.spouseDob = picked;
      userProfileProvider.notifyUserListeners();
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
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: continueCondtions() ? onContinue : null,
                  child: userProfileProvider.loading
                      ? const CupertinoActivityIndicator(
                          color: AppColors.n0,
                        )
                      : Text(
                          languageProvider.getMessage(
                            'continue',
                            'Continue',
                          ),
                        ),
                ),
              ),
            ],
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProgressIndicatorAtTop(value: 2),
                    Gap.gap32h,
                    const OnboardingPageHeader(
                      titleKey: "family_details_title",
                      titleDefault: "Family Details",
                      subtitleKey: 'family_details_subtitle',
                      subtitleDefault: "Tell us a bit more about yourself",
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'spouse_name',
                      questionDefault: 'Name of Husband',
                      answer: TextFormSnabbit(
                        controller: spouseNameController,
                        hintText: languageProvider.getMessage(
                          "spouse_name_hint",
                          "Enter name",
                        ),
                        onChanged: (v) {
                          if (v.isNotEmpty) {
                            userProfile.insuranceData?.spouseName = v;
                          } else {
                            userProfile.insuranceData?.spouseName = null;
                          }
                          userProfileProvider.notifyUserListeners();
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z ]')),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    // Husband's Date of birth field
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'husband_dob',
                      questionDefault: 'Date of Birth of Husband',
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
                      height: 16.h,
                    ),
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'spouse_occupation',
                      questionDefault: 'Occupation of husband',
                      criticalError: userProfile.otherDetails?.spouseOccupation
                                  ?.isValueAcceptable() ==
                              true
                          ? null
                          : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                      answer: spouseOccupationChoices == null
                          ? UiHelper.showLoadFailError(context)
                          : GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 3.5,
                              children: spouseOccupationChoices!.map((e) {
                                return GestureDetector(
                                  onTap: () {
                                    userProfile.otherDetails?.spouseOccupation
                                        ?.value = e;
                                    userProfileProvider.notifyUserListeners();
                                  },
                                  child: Row(
                                    children: [
                                      CircularCheckbox(
                                        value: userProfile.otherDetails
                                                ?.spouseOccupation?.value ==
                                            e,
                                      ),
                                      Gap.gap8w,
                                      Text(
                                        languageProvider.getMessage(e, e),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'spouse_monthly_income',
                      questionDefault: 'Monthly income of husband',
                      criticalError: userProfile.otherDetails?.spouseMonthlyIncome
                            ?.isValueAcceptable() ==
                            true
                            ? null
                            : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                      answer: SizedBox(
                        width: MediaQuery.of(context).size.width / 2,
                        child: TextField(
                          controller: spouseMonthlyIncomeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                          ],
                          decoration: InputDecoration(
                            hintText: languageProvider.getMessage(
                              'spouse_monthly_income_hint',
                              'Ex. ₹10000',
                            ),
                            hintStyle: AppTextTheme.hintStyle,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            try {
                              if (v.isNotEmpty) {
                                userProfile.otherDetails?.spouseMonthlyIncome
                                    ?.value = anyValueToInt(v);
                              } else {
                                userProfile.otherDetails?.spouseMonthlyIncome
                                    ?.value = null;
                              }
                              userProfileProvider.notifyUserListeners();
                            } catch (e) {
                              // DO NOTHING
                            }
                          },
                        ),
                      ),
                    ),
                    Gap.gap16h,
                    // TrueFalseRadioButton(
                    //   // option1: "Yes, they do",
                    //   // option2: "No, they don't",
                    //   question: "Does your husband want you to work?",
                    //   questionKey: 'husband_want_you_to_work',
                    //   onOption1Tap: () {
                    //     userProfile.otherDetails!.spouseKnowAboutJob = true;
                    //     userProfileProvider.notifyUserListeners();
                    //   },
                    //   onOption2Tap: () {
                    //     userProfile.otherDetails!.spouseKnowAboutJob = false;
                    //     userProfileProvider.notifyUserListeners();
                    //   },
                    //   checkBoxOption1Value:
                    //       userProfile.otherDetails!.spouseKnowAboutJob ?? false,
                    //   checkBoxOption2Value:
                    //       userProfile.otherDetails!.spouseKnowAboutJob != null
                    //           ? !userProfile.otherDetails!.spouseKnowAboutJob!
                    //           : false,
                    // ),
                    // Gap.gap32h,
                    TrueFalseRadioButton(
                      // option1: "Yes",

                      // option2: "No",
                      mandatory: true,
                      question:
                          "Have you told your family members about Snabbit and the work it involves?",
                      questionKey: 'family_ok_with_cleaning_job',
                      criticalError: userProfile.otherDetails?.familyOkWithCleaningJob
                          ?.isValueAcceptable() ==
                          true
                          ? null
                          : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                      onOption1Tap: () {
                        userProfile.otherDetails!.familyOkWithCleaningJob
                            ?.value = true;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.otherDetails!.familyOkWithCleaningJob
                            ?.value = false;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value: userProfile
                              .otherDetails!.familyOkWithCleaningJob?.value ??
                          false,
                      checkBoxOption2Value: userProfile.otherDetails!
                                  .familyOkWithCleaningJob?.value !=
                              null
                          ? !userProfile
                              .otherDetails!.familyOkWithCleaningJob!.value!
                          : false,
                    ),
                    // if (userProfile.otherDetails!.familyOkWithCleaningJob == false)
                    //   Column(
                    //     children: [
                    //       Gap.gap32h,
                    //       TrueFalseRadioButton(
                    //         // option1: "Yes, I will",
                    //         // option2: "No, I won't",
                    //         question:
                    //         "Will you tell him about the snabbit application in the future?",
                    //         onOption1Tap: () {
                    //           userProfile
                    //               .otherDetails!.tellFamilyInFuture = true;
                    //           userProfileProvider.notifyUserListeners();
                    //         },
                    //         onOption2Tap: () {
                    //           userProfile.otherDetails!
                    //               .tellFamilyInFuture = false;
                    //           userProfileProvider.notifyUserListeners();
                    //         },
                    //         checkBoxOption1Value: userProfile
                    //             .otherDetails!.tellFamilyInFuture ??
                    //             false,
                    //         checkBoxOption2Value: userProfile.otherDetails!
                    //             .tellFamilyInFuture !=
                    //             null
                    //             ? !userProfile
                    //             .otherDetails!.tellFamilyInFuture!
                    //             : false,
                    //       ),
                    //     ],
                    //   ),
                    // Gap.gap32h,
                    // TrueFalseRadioButton(
                    //     option1: "Yes, they do",
                    //     option2: "No, they don't",
                    //     question: "If your husband finds out you’re working cleaning homes will he be unhappy?",
                    //     onOption1Tap: () {
                    //       userProfile.otherDetails!.spouseApproval = true;
                    //       userProfileProvider.notifyUserListeners();
                    //     },
                    //     onOption2Tap: () {
                    //       userProfile.otherDetails!.spouseApproval = false;
                    //       userProfileProvider.notifyUserListeners();
                    //     },
                    //     checkBoxOption1Value:
                    //         userProfile.otherDetails!.spouseApproval ?? false,
                    //     checkBoxOption2Value:
                    //         userProfile.otherDetails!.spouseApproval != null
                    //             ? !userProfile.otherDetails!.spouseApproval!
                    //             : false),
                    Gap.gap16h,
                    TrueFalseRadioButton(
                        // option1: "Yes, I do",
                        // option2: "No, I don't",
                        mandatory: true,
                        question:
                            "Do you stay with parents/ in-laws/ joint family?",
                        questionKey: 'stay_with_parents',
                        onOption1Tap: () {
                          userProfile.otherDetails!.stayWithParents?.value =
                              true;
                          userProfileProvider.notifyUserListeners();
                        },
                        onOption2Tap: () {
                          userProfile.otherDetails!.stayWithParents?.value =
                              false;
                          userProfileProvider.notifyUserListeners();
                        },
                        checkBoxOption1Value:
                            userProfile.otherDetails!.stayWithParents?.value ??
                                false,
                        checkBoxOption2Value: userProfile
                                    .otherDetails!.stayWithParents?.value !=
                                null
                            ? !userProfile.otherDetails!.stayWithParents?.value!
                            : false),
                    Gap.gap16h,
                    TrueFalseRadioButton(
                      question:
                          "Will they approve of you doing house and bathroom cleaning work?",
                      questionKey: 'parents_approval',
                      mandatory: true,
                      onOption1Tap: () {
                        userProfile.otherDetails!.parentsApproval?.value = true;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.otherDetails!.parentsApproval?.value =
                            false;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value:
                          userProfile.otherDetails!.parentsApproval?.value ??
                              false,
                      checkBoxOption2Value: userProfile
                                  .otherDetails!.parentsApproval?.value !=
                              null
                          ? !userProfile.otherDetails!.parentsApproval?.value!
                          : false,
                    ),
                    // if (userProfile.otherDetails?.stayWithParents == true)
                    // Padding(
                    //   padding: EdgeInsets.only(top: 32.h),
                    //   child: TrueFalseRadioButton(
                    //       option1: "Yes, they do",
                    //       option2: "No, they don't",
                    //       question: "If they knew about the work you do at Snabbit, will your parents / in-laws allow you to work here?",
                    //       onOption1Tap: () {
                    //         userProfile.otherDetails!.inLawsApproval = true;
                    //         userProfileProvider.notifyUserListeners();
                    //       },
                    //       onOption2Tap: () {
                    //         userProfile.otherDetails!.inLawsApproval = false;
                    //         userProfileProvider.notifyUserListeners();
                    //       },
                    //       checkBoxOption1Value:
                    //       userProfile.otherDetails!.inLawsApproval ?? false,
                    //       checkBoxOption2Value:
                    //       userProfile.otherDetails!.inLawsApproval != null
                    //           ? !userProfile.otherDetails!.inLawsApproval!
                    //           : false),
                    // ),
                    Gap.gap16h,
                    TrueFalseRadioButton(
                      mandatory: true,
                      question:
                          "Are you allowed to wear t-shirt and pants when you go out?",
                      criticalError: userProfile.otherDetails?.tshirtAllowed
                          ?.isValueAcceptable() ==
                          true
                          ? null
                          : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                      onOption1Tap: () {
                        userProfile.otherDetails!.tshirtAllowed?.value = true;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.otherDetails!.tshirtAllowed?.value = false;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value:
                          userProfile.otherDetails!.tshirtAllowed?.value ??
                              false,
                      checkBoxOption2Value:
                          userProfile.otherDetails!.tshirtAllowed?.value != null
                              ? !userProfile.otherDetails!.tshirtAllowed!.value!
                              : false,
                    ),
                    Gap.gap16h,
                    TrueFalseRadioButton(
                      // option1: "Yes, I do",
                      // option2: "No, I don't",
                      mandatory: true,
                      question: "Do you have kids?",
                      onOption1Tap: () {
                        setState(() {
                          haveChildren = true;
                        });
                      },
                      onOption2Tap: () {
                        // setState(() {
                        haveChildren = false;
                        userProfile.otherDetails?.numberOfChildren?.value = 0;
                        userProfile.otherDetails?.dobOfYoungestChild = null;
                        userProfileProvider.notifyUserListeners();
                        // });
                      },
                      checkBoxOption1Value: haveChildren == true,
                      checkBoxOption2Value: haveChildren == false,
                      // haveChildren != null ? !haveChildren! : false,
                    ),
                    haveChildren == true
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Gap.gap16h,
                              OnboardingQuestion(
                                questionKey: 'number_of_children',
                                questionDefault: 'How many kids do you have?',
                                mandatory: haveChildren,
                                criticalError: userProfile.otherDetails?.numberOfChildren
                                    ?.isValueAcceptable() ==
                                    true
                                    ? null
                                    : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                                answer: Row(
                                  children: List.generate(5, (index) {
                                    /// When changing this list range, think about the 5+ case as well
                                    return Flexible(
                                      flex: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: GestureDetector(
                                          onTap: () {
                                            userProfile
                                                .otherDetails!
                                                .numberOfChildren
                                                ?.value = index + 1;
                                            userProfileProvider
                                                .notifyUserListeners();
                                          },
                                          child: Container(
                                            height: 48,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: AppColors.n60),
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              color: userProfile
                                                          .otherDetails!
                                                          .numberOfChildren
                                                          ?.value ==
                                                      null
                                                  ? Colors.white
                                                  : userProfile
                                                                  .otherDetails!
                                                                  .numberOfChildren
                                                                  !.value! -
                                                              1 ==
                                                          index
                                                      ? AppColors.brand
                                                      : Colors.white,
                                            ),
                                            child: Center(
                                              child: Text(
                                                index == 4
                                                    ? "${index + 1}+"
                                                    : (index + 1).toString(),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: userProfile
                                                              .otherDetails!
                                                              .numberOfChildren
                                                              ?.value ==
                                                          null
                                                      ? Colors.black
                                                      : userProfile
                                                                      .otherDetails!
                                                                      .numberOfChildren
                                                                      !.value! -
                                                                  1 ==
                                                              index
                                                          ? Colors.white
                                                          : Colors.black,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              Gap.gap16h,
                              OnboardingQuestion(
                                questionKey: 'youngest_child_age',
                                questionDefault:
                                    'How old is your youngest child (years)?',
                                mandatory: haveChildren,
                                criticalError: userProfile.otherDetails?.ageOfYoungestChild
                                    ?.isValueAcceptable() ==
                                    true
                                    ? null
                                    : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                                answer: Container(
                                  width: 0.5.sw,
                                  padding: EdgeInsets.only(right: 32.w),
                                  child: TextField(
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9]')),
                                    ],
                                    controller: ageController,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 2,
                                    decoration: InputDecoration(
                                      hintText: languageProvider.getMessage(
                                        'youngest_child_age_hint',
                                        'Eg. 3',
                                      ),
                                      counterText: "",
                                    ),
                                    onChanged: (val) {
                                      if (val.isNotEmpty) {
                                        userProfileProvider
                                            .user
                                            ?.otherDetails
                                            ?.ageOfYoungestChild
                                            ?.value = anyValueToInt(val);
                                      } else {
                                        userProfileProvider.user?.otherDetails
                                            ?.ageOfYoungestChild?.value = null;
                                      }
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(),
                    // Gap.gap32h,
                  ],
                ),
              ),
            ),
          );
  }

  bool continueCondtions() {
    if (userProfile.insuranceData?.spouseName != null &&
        userProfile.insuranceData?.spouseName?.trim().isNotEmpty == true &&
        userProfile.otherDetails?.spouseMonthlyIncome?.value != null &&
        userProfile.otherDetails?.spouseOccupation?.value != null &&
        // userProfile.otherDetails?.spouseApproval != null &&
        userProfile.otherDetails?.tshirtAllowed?.value != null &&
        userProfile.otherDetails?.familyOkWithCleaningJob?.value != null &&
        // userProfile.otherDetails?.spouseKnowAboutJob != null &&
        userProfile.otherDetails?.stayWithParents?.value != null &&
        userProfile.otherDetails?.parentsApproval?.value != null &&
        // ((userProfile.otherDetails?.stayWithParents == true && userProfile.otherDetails?.inLawsApproval != null) || userProfile.otherDetails?.stayWithParents == false) &&
        ((haveChildren == true &&
                (userProfileProvider
                            .user?.otherDetails?.numberOfChildren?.value ??
                        0) >
                    0 &&
                userProfile.otherDetails?.ageOfYoungestChild?.value != null) ||
            haveChildren == false) &&
        userProfileProvider.user?.insuranceData?.spouseDob != null) {
      return true;
      // } else if (userProfile.otherDetails?.spouseName != null &&
      //     userProfile.otherDetails?.spouseMonthlyIncome != null &&
      //     userProfile.otherDetails!.spouseOccupation != null &&
      //     userProfile.otherDetails?.spouseApproval != null &&
      //     userProfile.otherDetails?.tshirtAllowed != null &&
      //     userProfile.otherDetails?.familyOkWithCleaningJob != null &&
      //     userProfile.otherDetails?.spouseKnowAboutJob != null &&
      //     userProfile.otherDetails?.stayWithParents != null &&
      //     userProfile.otherDetails?.inLawsApproval != null &&
      //     (haveChildren != null ? !haveChildren! : false)) {
      //   return true;
    } else {
      return false;
    }
  }

  @override
  void dispose() {
    ageController.dispose();
    spouseNameController.dispose();
    spouseMonthlyIncomeController.dispose();
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
    super.dispose();
  }
}
