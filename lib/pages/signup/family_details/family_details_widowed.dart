import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/widgets/dob_selector.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/true_false_radio_button.dart';
import '../../../widgets/common_app_bar.dart';
import '../../../widgets/progress_indicator.dart';
import '../../../utils/colors.dart';
import '../../../utils/common_methods.dart';
import '../../../widgets/text_form.dart';

class FamilyDetailsIfWidowed extends StatefulWidget {
  static const String routeName = "/family_details_widowed";

  const FamilyDetailsIfWidowed({super.key});

  @override
  State<FamilyDetailsIfWidowed> createState() => _FamilyDetailsIfWidowedState();
}

class _FamilyDetailsIfWidowedState extends State<FamilyDetailsIfWidowed> {
  TextEditingController ageOfYoungestChild = TextEditingController();
  TextEditingController spouseNameController = TextEditingController();

  // bool? stayWithParents;
  // bool? isDecisionSupportedByParents;
  bool? haveChildren;

  // int? numberofKids;

  // final List<String> kidsCount = ["1", "2", "3", "4"];
  // String dobYoungestKid = "";
  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late LanguageProvider languageProvider;
  bool init = true;

  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();


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
      userProfile = userProfileProvider.user!;

      // stayWithParents = userProfile.otherDetails!.stayWithParents;
      // isDecisionSupportedByParents = userProfile.otherDetails!.parentsApproval;
      // haveChildren= userProfile.otherDetails!.numberOfChildren! > 0 ? true : false;
      // numberofKids = userProfile.otherDetails!.numberOfChildren;

      // userProfile.registrationStep = RunnerRegistrationStep.family;
      if (userProfile.otherDetails?.numberOfChildren?.value != null) {
        haveChildren = userProfile.otherDetails!.numberOfChildren!.value! > 0;
      }

      spouseNameController = TextEditingController(
          text: userProfile.insuranceData?.spouseName ?? '');

      if (userProfileProvider.user?.insuranceData != null) {
        DateTime? spouseDob =
            userProfileProvider.user?.insuranceData?.spouseDob;
        if (spouseDob != null) {
          dayController.text = spouseDob.day.toString().padLeft(2, '0');
          monthController.text = spouseDob.month.toString().padLeft(2, '0');
          yearController.text = spouseDob.year.toString();
        }
      }

      // DateTime? youngestChildDobBackend =
      //     userProfile.otherDetails!.dobOfYoungestChild;

      // if (youngestChildDobBackend != null) {
      //   dobDay.text = youngestChildDobBackend.day.toString().padLeft(2, '0');
      //   dobMonth.text =
      //       youngestChildDobBackend.month.toString().padLeft(2, '0');
      //   dobYear.text = youngestChildDobBackend.year.toString();
      // }
      if (userProfile.otherDetails?.ageOfYoungestChild?.value != null) {
        ageOfYoungestChild.text =
            userProfile.otherDetails?.ageOfYoungestChild?.value?.toString() ?? '';
      }

      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
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
    final initialDate = currentDate.subtract(
        const Duration(days: 365 * 18));
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
                  onPressed: continueCondtions() && !userProfileProvider.loading
                      ? onContinue
                      : null,
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
                    Gap.gap32h,
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
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
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
                    TrueFalseRadioButton(
                      mandatory: true,
                      question: "Do you stay with your parents / in-laws?",
                      onOption1Tap: () {
                        userProfile.otherDetails!.stayWithParents?.value = true;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.otherDetails!.stayWithParents?.value = false;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value:
                          userProfile.otherDetails!.stayWithParents?.value ?? false,
                      checkBoxOption2Value:
                          userProfile.otherDetails!.stayWithParents?.value != null
                              ? !userProfile.otherDetails!.stayWithParents?.value!
                              : false,
                    ),
                    Gap.gap16h,
                    TrueFalseRadioButton(
                      mandatory: true,
                      question:
                          "Will they approve of you doing house and bathroom cleaning work?",
                      onOption1Tap: () {
                        userProfile.otherDetails!.parentsApproval?.value = true;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.otherDetails!.parentsApproval?.value = false;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value:
                          userProfile.otherDetails!.parentsApproval?.value ?? false,
                      checkBoxOption2Value:
                          userProfile.otherDetails!.parentsApproval?.value != null
                              ? !userProfile.otherDetails!.parentsApproval?.value!
                              : false,
                    ),
                    Gap.gap16h,
                    TrueFalseRadioButton(
                      mandatory: true,
                      option1: "Yes",
                      option2: "No",
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
                          userProfile.otherDetails!.tshirtAllowed?.value ?? false,
                      checkBoxOption2Value:
                          userProfile.otherDetails!.tshirtAllowed?.value != null
                              ? !userProfile.otherDetails!.tshirtAllowed!.value!
                              : false,
                    ),
                    Gap.gap16h,
                    TrueFalseRadioButton(
                      mandatory: true,
                      // option1: "Yes, I do",
                      // option2: "No, I don't",
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
                                mandatory: true,
                                questionKey: 'number_of_children',
                                questionDefault: 'How many kids do you have?',
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
                                            userProfile.otherDetails!
                                                .numberOfChildren?.value = index + 1;
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
                                              color: userProfile.otherDetails!
                                                          .numberOfChildren?.value ==
                                                      null
                                                  ? Colors.white
                                                  : userProfile.otherDetails!
                                                                  .numberOfChildren!.value! -
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
                                                              .numberOfChildren?.value ==
                                                          null
                                                      ? Colors.black
                                                      : userProfile.otherDetails!
                                                                      .numberOfChildren!.value! -
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
                              if ((userProfileProvider.user?.otherDetails!
                                          .numberOfChildren?.value ??
                                      0) >
                                  0)
                                Padding(
                                  padding: EdgeInsets.only(top: 16.h),
                                  child: OnboardingQuestion(
                                    mandatory: true,
                                    questionKey: 'youngest_child_age',
                                    questionDefault:
                                        'How old is your youngest child (years)?',
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
                                        controller: ageOfYoungestChild,
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
                                                    ?.ageOfYoungestChild?.value =
                                                anyValueToInt(val);
                                          } else {
                                            userProfileProvider
                                                .user
                                                ?.otherDetails
                                                ?.ageOfYoungestChild?.value = null;
                                          }
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Container(),
                  ],
                ),
              ),
            ),
          );
  }

  bool continueCondtions() {
    if (userProfile.otherDetails?.stayWithParents?.value != null &&
        (userProfile.insuranceData?.spouseName?.trim().isNotEmpty ?? false) &&
        userProfile.otherDetails?.parentsApproval?.value != null &&
        userProfile.otherDetails?.tshirtAllowed?.value != null &&
        ((haveChildren == true &&
                ((userProfile.otherDetails?.numberOfChildren?.value??0)>0 &&
                    userProfile.otherDetails?.ageOfYoungestChild?.value!=null)) ||
            haveChildren == false)
        && userProfileProvider.user?.insuranceData?.spouseDob!=null
    ) {
      return true;
    } else {
      return false;
    }
  }

  @override
  void dispose() {
    ageOfYoungestChild.dispose();
    spouseNameController.dispose();
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
    super.dispose();
  }
}
