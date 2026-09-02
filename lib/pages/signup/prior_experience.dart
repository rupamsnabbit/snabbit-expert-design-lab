import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/critical_field.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/server_requests/language_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/ui_helper.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/miscellaneous/tail_widgets.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import 'package:snabbit_runner/widgets/true_false_radio_button.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_strings.dart';
import '../../widgets/circular_checkbox.dart';
import '../../utils/common_methods.dart';

class LanguageProficiency {
  int id;
  String? key;
  String label;
  bool? read;
  bool? write;
  bool? understand;

  LanguageProficiency({
    required this.id,
    this.key,
    required this.label,
    this.read,
    this.write,
    this.understand,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'key': key,
      'label': label,
      'read': read,
      'write': write,
      'understand': understand,
    };
  }

  // Create object from Map
  factory LanguageProficiency.fromMap(Map<String, dynamic> map) {
    return LanguageProficiency(
      id: map['id'] as int,
      key: map['key'] as String?,
      label: map['label'] as String,
      read: map['read'] as bool?,
      write: map['write'] as bool?,
      understand: map['understand'] as bool?,
    );
  }

  bool isValidData() {
    return read == true || write == true || understand == true;
  }
}

class PriorExperience extends StatefulWidget {
  static const String routeName = "/prior_experience";

  const PriorExperience({super.key});

  @override
  State<PriorExperience> createState() => _PriorExperienceState();
}

class _PriorExperienceState extends State<PriorExperience> {
  // TextEditingController priorMonthlySalary = TextEditingController();

  List<String> jobTypeChoices = [
    AppStrings.fullTimeString,
    AppStrings.partTimeString
  ];

  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late LanguageProvider languageProvider;
  bool init = true;

  //  take this from server.
  List<LanguageProficiency> languageProficiency = [];

  List<String>? vehiclesUsed;
  List<String>? priorTasksChoices;
  List<String>? dietaryPreferenceChoices;

  void updateLanguageProficiencyList() async {
    final response = await LanguageHttp.fetchLanguageProficiencies();

    if (response != null) {
      if (response.statusCode == 200) {
        languageProficiency = response.data
            .map<LanguageProficiency>((e) => LanguageProficiency.fromMap(e))
            .toList();
        var userData =
            userProfileProvider.user?.otherDetails?.languageProficiency?.value ?? [];
        //
        // // Create a map from user data for quick lookup
        Map<int, LanguageProficiency> userMap = {
          for (var entry in userData) entry.id: entry
        };
        //
        // Merge user data into languageProficiency list
        languageProficiency = languageProficiency.map((lang) {
          return userMap[lang.id] ??
              lang; // Take from user data if exists, else keep original
        }).toList();
        setState(() {});
      } else {
        // print("error occurred on parsing language proficiency data  ${response.data}");
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
      userProfile = userProfileProvider.user!;
      updateLanguageProficiencyList();
      // if (userProfile.otherDetails?.lastDrawnSalary != null) {
      //   priorMonthlySalary.text =
      //       userProfile.otherDetails!.lastDrawnSalary.toString();
      // }

      vehiclesUsed = GlobalState().appConfig?.vehiclesUsed;
      priorTasksChoices = GlobalState().appConfig?.priorTasks;
      dietaryPreferenceChoices = GlobalState().appConfig?.dietaryPreference;

      setState(() {});
    }
    super.didChangeDependencies();
  }

  void addOrUpdateLanguageProficiency(LanguageProficiency newEntry) {
    var list = userProfileProvider.user?.otherDetails?.languageProficiency;

    // If the list is null, initialize it
    if (list?.value == null) {
      userProfileProvider.user?.otherDetails?.languageProficiency?.value = [newEntry];
      return;
    }

    // Check if an entry with the same id exists
    int index = list!.value!.indexWhere((lang) => lang.id == newEntry.id);

    if (index != -1) {
      // Update existing record
      list.value?[index] = newEntry;
    } else {
      // Add new record
      list.value?.add(newEntry);
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
                  onPressed:
                      !userProfileProvider.loading && continueConditions()
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
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProgressIndicatorAtTop(value: 3),
                    Gap.gap32h,
                    const OnboardingPageHeader(
                      titleKey: 'additional_details_title',
                      titleDefault: 'Additional details',
                      subtitleKey: 'additional_details_subtitle',
                      subtitleDefault: "Please provide accurate information",
                    ),
                    Gap.gap32h,
                    TrueFalseRadioButton(
                      mandatory: true,
                      option1: "Yes",
                      option2: "No",
                      questionKey: "has_own_smartphone",
                      question: "Do you have your own smartphone?",
                      criticalError: userProfile.otherDetails?.ownSmartphone?.getCriticalError(languageProvider),
                      onOption1Tap: () {
                        userProfile.otherDetails?.ownSmartphone?.value = true;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.otherDetails?.ownSmartphone?.value = false;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value:
                          userProfile.otherDetails?.ownSmartphone?.value == true,
                      checkBoxOption2Value:
                          userProfile.otherDetails?.ownSmartphone?.value == false,
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'prior_tasks',
                      questionDefault:
                          'How many of these tasks have you done before?\n(select all that apply)',
                      answer: priorTasksChoices == null
                          ? UiHelper.showLoadFailError(context)
                          : GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 3,
                              mainAxisSpacing: 3,
                              childAspectRatio: 3,
                              children: priorTasksChoices!.map((taskChoice) {
                                final enumValue =
                                    getPriorTasksFromString(taskChoice);
                                return GestureDetector(
                                  onTap: () {
                                    try {
                                      if (enumValue != null) {
                                        if (userProfile
                                            .otherDetails!.priorTasks!.value!
                                            .contains(enumValue)) {
                                          userProfile.otherDetails!.priorTasks!.value?.remove(enumValue);
                                        } else {
                                          userProfile.otherDetails!.priorTasks!.value?.add(enumValue);
                                        }
                                        userProfileProvider
                                            .notifyUserListeners();
                                      }
                                    } catch (e) {
                                      showSnackbar(
                                          context, "Something went wrong - $e");
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      CircularCheckbox(
                                        squircle: true,
                                        value: enumValue != null &&
                                            userProfile
                                                .otherDetails!.priorTasks!.value!
                                                .contains(enumValue),
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          languageProvider.getMessage(
                                            taskChoice,
                                            toBeginningOfSentenceCase(taskChoice
                                                    .replaceAll("_", " ")) ??
                                                '',
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: AppColors.n80),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Gap.gap16h,
                        TrueFalseRadioButton(
                          // option1: "Yes",
                          // option2: "No",
                          mandatory: true,
                          question:
                              "Are you willing to clean homes with dogs / other pets?",
                          questionKey: 'willing_to_clean_home_with_pets',
                          criticalError: userProfile.otherDetails!
                              .willingToCleanHomeWithPets?.getCriticalError(languageProvider),
                          onOption1Tap: () {
                            userProfile.otherDetails!
                                .willingToCleanHomeWithPets?.value = true;
                            userProfileProvider.notifyUserListeners();
                          },
                          onOption2Tap: () {
                            userProfile.otherDetails!
                                .willingToCleanHomeWithPets?.value = false;
                            userProfileProvider.notifyUserListeners();
                          },
                          checkBoxOption1Value: userProfile
                                  .otherDetails!.willingToCleanHomeWithPets?.value ??
                              false,
                          checkBoxOption2Value: userProfile.otherDetails!
                                      .willingToCleanHomeWithPets?.value !=
                                  null
                              ? !userProfile
                                  .otherDetails!.willingToCleanHomeWithPets!.value!
                              : false,
                        ),
                        Gap.gap16h,
                        TrueFalseRadioButton(
                          // option1: "Yes",
                          // option2: "No",
                          mandatory: true,
                          question: "Are you willing to clean pooja room?",
                          questionKey: 'willing_to_clean_pooja_room',
                          criticalError: userProfile.otherDetails?.willingToCleanPoojaRoom?.getCriticalError(languageProvider),
                          onOption1Tap: () {
                            userProfile.otherDetails!.willingToCleanPoojaRoom?.value =
                                true;
                            userProfileProvider.notifyUserListeners();
                          },
                          onOption2Tap: () {
                            userProfile.otherDetails!.willingToCleanPoojaRoom?.value =
                                false;
                            userProfileProvider.notifyUserListeners();
                          },
                          checkBoxOption1Value: userProfile
                                  .otherDetails!.willingToCleanPoojaRoom?.value ??
                              false,
                          checkBoxOption2Value: userProfile
                                      .otherDetails!.willingToCleanPoojaRoom?.value !=
                                  null
                              ? !userProfile
                                  .otherDetails!.willingToCleanPoojaRoom!.value!
                              : false,
                        ),
                        Gap.gap16h,
                        TrueFalseRadioButton(
                          // option1: "Yes",
                          // option2: "No",
                          mandatory: true,
                          question: "Are you willing to clean bathrooms?",
                          questionKey: 'willing_to_clean_bathrooms',
                          criticalError: userProfile.otherDetails?.willingToCleanBathrooms?.getCriticalError(languageProvider),
                          onOption1Tap: () {
                            userProfile.otherDetails!.willingToCleanBathrooms?.value =
                                true;
                            userProfileProvider.notifyUserListeners();
                          },
                          onOption2Tap: () {
                            userProfile.otherDetails!.willingToCleanBathrooms?.value =
                                false;
                            userProfileProvider.notifyUserListeners();
                          },
                          checkBoxOption1Value: userProfile
                                  .otherDetails!.willingToCleanBathrooms?.value ??
                              false,
                          checkBoxOption2Value: userProfile
                                      .otherDetails!.willingToCleanBathrooms?.value !=
                                  null
                              ? !userProfile
                                  .otherDetails!.willingToCleanBathrooms!.value!
                              : false,
                        ),
                      ],
                    ),
                    Gap.gap16h,
                    TrueFalseRadioButton(
                      mandatory: true,
                      // option1: "Yes",
                      // option2: "No",
                      question: "Do you keep fasts?",
                      questionKey: 'keep_fasts',
                      criticalError: userProfile.otherDetails?.keepFasts?.getCriticalError(languageProvider),
                      onOption1Tap: () {
                        userProfile.otherDetails!.keepFasts?.value = true;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.otherDetails!.keepFasts?.value = false;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value:
                          userProfile.otherDetails!.keepFasts?.value ?? false,
                      checkBoxOption2Value:
                          userProfile.otherDetails!.keepFasts?.value != null
                              ? !userProfile.otherDetails!.keepFasts!.value!
                              : false,
                    ),
                    if (userProfile.otherDetails?.keepFasts?.value == true)
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: TrueFalseRadioButton(
                          mandatory: true,
                          // option1: "Yes",
                          // option2: "No",
                          question:
                              "Will you be able to complete all tasks during fasts (including bathroom cleaning)?",
                          questionKey: 'tasks_during_fasts',
                          criticalError: userProfile.otherDetails?.tasksDuringFast?.getCriticalError(languageProvider),
                          onOption1Tap: () {
                            userProfile.otherDetails!.tasksDuringFast?.value = true;
                            userProfileProvider.notifyUserListeners();
                          },
                          onOption2Tap: () {
                            userProfile.otherDetails!.tasksDuringFast?.value = false;
                            userProfileProvider.notifyUserListeners();
                          },
                          checkBoxOption1Value:
                              userProfile.otherDetails!.tasksDuringFast?.value ??
                                  false,
                          checkBoxOption2Value:
                              userProfile.otherDetails!.tasksDuringFast?.value != null
                                  ? !userProfile.otherDetails!.tasksDuringFast!.value!
                                  : false,
                        ),
                      ),
                    Gap.gap16h,
                    // OnboardingQuestion(
                    //   questionKey: 'sect',
                    //   questionDefault: 'Group',
                    //   answer: GridView.count(
                    //     shrinkWrap: true,
                    //     physics: const NeverScrollableScrollPhysics(),
                    //     crossAxisCount: 2,
                    //     crossAxisSpacing: 3,
                    //     mainAxisSpacing: 3,
                    //     childAspectRatio: 4,
                    //     children: List.generate(
                    //       Sect.values.length,
                    //       (index) {
                    //         return GestureDetector(
                    //           onTap: () {
                    //             userProfile.otherDetails?.sect =
                    //                 Sect.values.elementAt(index);
                    //             userProfileProvider.notifyUserListeners();
                    //           },
                    //           child: Row(
                    //             children: [
                    //               CircularCheckbox(
                    //                 value: userProfile.otherDetails?.sect ==
                    //                     Sect.values.elementAt(index),
                    //               ),
                    //               Gap.gap8w,
                    //               Text(
                    //                 toBeginningOfSentenceCase(
                    //                     Sect.values.elementAt(index).name),
                    //                 style: Theme.of(context).textTheme.bodyMedium,
                    //               ),
                    //             ],
                    //           ),
                    //         );
                    //       },
                    //     ),
                    //   ),
                    // ),
                    // Gap.gap16h,
                    // OnboardingQuestion(
                    //   questionKey: 'highest_education',
                    //   questionDefault: 'Highest education level',
                    //   answer: GridView.count(
                    //     shrinkWrap: true,
                    //     physics: const NeverScrollableScrollPhysics(),
                    //     crossAxisCount: 2,
                    //     crossAxisSpacing: 3,
                    //     mainAxisSpacing: 3,
                    //     childAspectRatio: 4,
                    //     children: List.generate(
                    //       Education.values.length,
                    //       (index) {
                    //         return GestureDetector(
                    //           onTap: () {
                    //             userProfile.otherDetails!.highestEducation =
                    //                 Education.values.elementAt(index);
                    //             Logger()
                    //                 .d(userProfile.otherDetails!.highestEducation);
                    //             userProfileProvider.notifyUserListeners();
                    //           },
                    //           child: Row(
                    //             children: [
                    //               CircularCheckbox(
                    //                 value:
                    //                     userProfile.otherDetails!.highestEducation ==
                    //                         Education.values.elementAt(index),
                    //               ),
                    //               Gap.gap8w,
                    //               Text(
                    //                 toBeginningOfSentenceCase(Education.values
                    //                     .elementAt(index)
                    //                     .name
                    //                     .toLowerCase()
                    //                     .replaceAll("_", " ")),
                    //                 style: Theme.of(context).textTheme.bodyMedium,
                    //               ),
                    //             ],
                    //           ),
                    //         );
                    //       },
                    //     ),
                    //   ),
                    // ),
                    // Gap.gap16h,
                    OnboardingQuestion(
                      questionKey: 'dietary_preference',
                      questionDefault: 'What are your dietary preferences?',
                      criticalError: userProfile.otherDetails?.dietaryPreference
                          ?.isValueAcceptable() ==
                      true
                      ? null
                          : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                      answer: dietaryPreferenceChoices == null
                          ? UiHelper.showLoadFailError(context)
                          : GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 3,
                              mainAxisSpacing: 3,
                              childAspectRatio: 7,
                              children: dietaryPreferenceChoices!
                                  .map((preferenceChoice) {
                                final enumValue =
                                    getDietaryPreferenceFromString(
                                        preferenceChoice);
                                return GestureDetector(
                                  onTap: () {
                                    if (enumValue != null) {
                                      userProfile.otherDetails!
                                          .dietaryPreference?.value = enumValue;
                                      userProfileProvider.notifyUserListeners();
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      CircularCheckbox(
                                        value: enumValue != null &&
                                            userProfile.otherDetails!
                                                    .dietaryPreference?.value ==
                                                enumValue,
                                      ),
                                      Gap.gap8w,
                                      Text(
                                        languageProvider.getMessage(
                                          preferenceChoice,
                                          toBeginningOfSentenceCase(
                                                  preferenceChoice.replaceAll(
                                                      "_", " ")) ??
                                              '',
                                        ),
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
                    if (userProfile.otherDetails!.dietaryPreference?.value ==
                        DietaryPreference.Strictly_Vegetarian)
                      Column(
                        children: [
                          Gap.gap16h,
                          TrueFalseRadioButton(
                            // option1: "Yes",
                            // option2: "No",
                            question:
                                "Will you be okay working in non-vegetarian households and completing tasks like dishwashing?",
                            questionKey: 'can_clean_non_veg_kitchen',
                            criticalError: userProfile.otherDetails?.canCleanNonVegKitchen?.getCriticalError(languageProvider),
                            onOption1Tap: () {
                              userProfile.otherDetails!.canCleanNonVegKitchen?.value =
                                  true;
                              userProfileProvider.notifyUserListeners();
                            },
                            onOption2Tap: () {
                              userProfile.otherDetails!.canCleanNonVegKitchen?.value =
                                  false;
                              userProfileProvider.notifyUserListeners();
                            },
                            checkBoxOption1Value: userProfile
                                    .otherDetails!.canCleanNonVegKitchen?.value ??
                                false,
                            checkBoxOption2Value: userProfile
                                        .otherDetails!.canCleanNonVegKitchen?.value !=
                                    null
                                ? !userProfile
                                    .otherDetails!.canCleanNonVegKitchen!.value!
                                : false,
                          ),
                        ],
                      ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'language_comfortable',
                      questionDefault:
                          'How comfortable are you with each language?',
                      answer: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: SizedBox()),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    languageProvider.getMessage(
                                      'read',
                                      'Read',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.n80),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    languageProvider.getMessage(
                                      'write',
                                      'Write',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.n80),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    languageProvider.getMessage(
                                      'understand',
                                      'Understand',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.n80),
                                  ),
                                ),
                              ),
                              const Expanded(child: SizedBox()),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 120.h,
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: languageProficiency.map((e) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 10.h),
                                        child: Text(
                                          languageProvider.getMessage(
                                            e.key ?? e.label,
                                            e.label,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: AppColors.n80),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SizedBox(
                                  height: 120.h,
                                  child: Column(
                                    children: languageProficiency.map((e) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 10.h),
                                        child: InkWell(
                                          onTap: () {
                                            e.read = !(e.read ?? false);
                                            addOrUpdateLanguageProficiency(e);
                                            setState(() {});
                                          },
                                          child: CircularCheckbox(
                                            value: e.read ?? false,
                                            squircle: true,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SizedBox(
                                  height: 120.h,
                                  child: Column(
                                    children: languageProficiency.map((e) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 10.h),
                                        child: InkWell(
                                          onTap: () {
                                            e.write = !(e.write ?? false);
                                            addOrUpdateLanguageProficiency(e);
                                            setState(() {});
                                          },
                                          child: CircularCheckbox(
                                            value: e.write ?? false,
                                            squircle: true,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SizedBox(
                                  height: 120.h,
                                  child: Column(
                                    children: languageProficiency.map((e) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 10.h),
                                        child: InkWell(
                                          onTap: () {
                                            e.understand =
                                                !(e.understand ?? false);
                                            addOrUpdateLanguageProficiency(e);
                                            setState(() {});
                                          },
                                          child: CircularCheckbox(
                                            value: e.understand ?? false,
                                            squircle: true,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: SizedBox(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    // OnboardingQuestion(
                    //   questionKey: 'last_drawn_salary',
                    //   questionDefault: 'Last drawn monthly income',
                    //   answer: SizedBox(
                    //     width: MediaQuery.of(context).size.width / 2,
                    //     child: TextField(
                    //       maxLength: 8,
                    //       controller: priorMonthlySalary,
                    //       keyboardType: TextInputType.number,
                    //       inputFormatters: [
                    //         FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    //       ],
                    //       decoration: InputDecoration(
                    //         counterText: "",
                    //         hintText: 'Ex. ₹10000',
                    //         hintStyle: AppTextTheme.hintStyle,
                    //         border: const OutlineInputBorder(),
                    //       ),
                    //       onChanged: (v) {
                    //         if (v.isNotEmpty) {
                    //           userProfile.otherDetails!.lastDrawnSalary =
                    //               int.tryParse(v);
                    //         } else {
                    //           userProfile.otherDetails?.lastDrawnSalary = null;
                    //         }
                    //         userProfileProvider.notifyUserListeners();
                    //       },
                    //     ),
                    //   ),
                    // ),
                    // Gap.gap16h,
                    TrueFalseRadioButton(
                      mandatory: true,
                      option1: "Yes",
                      option2: "No",
                      questionKey: "pet_preference",
                      question: "Are you afraid of pets?",
                      questionSubtitle: languageProvider.getMessage(
                        'pet_preference_subtitle',
                        "Mark yes only if you are truly scared of pets, as it may affect your chance of clearing registration.",
                      ),
                      questionTrailingItem: TailWidgets.petAverse,
                      criticalError: userProfile.petAverse?.getCriticalError(languageProvider),
                      onOption1Tap: () {
                        userProfile.petAverse?.value = true;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.petAverse?.value = false;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value:
                      userProfile.petAverse?.value == true,
                      checkBoxOption2Value:
                      userProfile.petAverse?.value == false,
                    ),
                    Gap.gap16h,
                    TrueFalseRadioButton(
                      mandatory: true,
                      option1: "Yes",
                      option2: "No",
                      questionKey: "has_used_google_maps",
                      question: "Have you ever used Google Maps?",
                      criticalError: userProfile.otherDetails?.usedGoogleMaps
                          ?.isValueAcceptable() ==
                          true
                          ? null
                          : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                      onOption1Tap: () {
                        userProfile.otherDetails?.usedGoogleMaps?.value = true;
                        userProfileProvider.notifyUserListeners();
                      },
                      onOption2Tap: () {
                        userProfile.otherDetails?.usedGoogleMaps?.value = false;
                        userProfileProvider.notifyUserListeners();
                      },
                      checkBoxOption1Value:
                          userProfile.otherDetails?.usedGoogleMaps?.value == true,
                      checkBoxOption2Value:
                          userProfile.otherDetails?.usedGoogleMaps?.value == false,
                    ),

                    Padding(
                      padding: EdgeInsets.only(top: 16.h),
                      child: OnboardingQuestion(
                        mandatory: true,
                        questionKey: 'vehicles_used',
                        questionDefault:
                            'Do you know how to ride any of the following?\n(select all that apply) ',
                        answer: vehiclesUsed == null
                            ? UiHelper.showLoadFailError(context)
                            : GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                crossAxisSpacing: 3,
                                mainAxisSpacing: 3,
                                childAspectRatio: 4,
                                children: vehiclesUsed!.map((e) {
                                  return GestureDetector(
                                    onTap: () {
                                      try {
                                        if (e == AppStrings.noneOfTheAbove) {
                                          if(cannotRideVehicles) {
                                            userProfile
                                                .otherDetails!.vehiclesUsed!.value!
                                                .remove(e);
                                          } else {
                                            userProfile.otherDetails
                                                ?.vehiclesUsed?.value = [e];
                                          }
                                        } else {
                                          if(cannotRideVehicles) {
                                            userProfile
                                                .otherDetails!.vehiclesUsed!.value!
                                                .remove(AppStrings.noneOfTheAbove);
                                          }
                                          if ((userProfile
                                                      .otherDetails
                                                      ?.vehiclesUsed
                                                      ?.value?.isNotEmpty ??
                                                  false) &&
                                              userProfile.otherDetails
                                                      ?.vehiclesUsed?.value
                                                      ?.contains(e) ==
                                                  true) {
                                            userProfile
                                                .otherDetails!.vehiclesUsed!.value!
                                                .remove(e);
                                          } else {
                                            if (userProfile.otherDetails
                                                    ?.vehiclesUsed?.value !=
                                                null) {
                                              userProfile
                                                  .otherDetails!.vehiclesUsed?.value
                                                  ?.add(e);
                                            } else {
                                              userProfile.otherDetails
                                                  ?.vehiclesUsed?.value = [e];
                                            }
                                          }
                                        }
                                        if (canRideEBike) {
                                          userProfile.otherDetails?.willingToLearnEBike?.value = null;
                                        }
                                        userProfileProvider.notifyUserListeners();
                                      } catch (e) {
                                        showSnackbar(
                                            context, 'Something went wrong - $e');
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        CircularCheckbox(
                                          squircle: true,
                                          value: userProfile
                                                  .otherDetails?.vehiclesUsed?.value
                                                  ?.contains(e) ??
                                              false,
                                        ),
                                        Gap.gap8w,
                                        Expanded(
                                          child: Text(
                                            languageProvider.getMessage(e, e),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                    if (!canRideEBike)
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: TrueFalseRadioButton(
                          mandatory: true,
                          option1: "Yes",
                          option2: "No",
                          questionKey: "willing_to_learn_ebike",
                          question:
                              "Would you be willing to learn how to ride E-Bike?",
                          criticalError: userProfile.otherDetails?.willingToLearnEBike
                              ?.isValueAcceptable() ==
                              true
                              ? null
                              : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                          onOption1Tap: () {
                            userProfile.otherDetails?.willingToLearnEBike?.value =
                                true;
                            userProfileProvider.notifyUserListeners();
                          },
                          onOption2Tap: () {
                            userProfile.otherDetails?.willingToLearnEBike?.value =
                                false;
                            userProfileProvider.notifyUserListeners();
                          },
                          checkBoxOption1Value:
                              userProfile.otherDetails?.willingToLearnEBike?.value ==
                                  true,
                          checkBoxOption2Value:
                              userProfile.otherDetails?.willingToLearnEBike?.value ==
                                  false,
                        ),
                      ),
                    if (GlobalState().appConfig?.eBikeTrainingLink != null)
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 24.h),
                        child: InkWell(
                          onTap: () async {
                            try {
                              final trainingLink = Uri.parse(
                                  GlobalState().appConfig!.eBikeTrainingLink!);
                              await launchUrl(trainingLink,
                                  mode: LaunchMode.externalApplication);
                            } catch (e) {
                              if (context.mounted) {
                                showSnackbar(
                                    context, "Something went wrong - $e");
                              }
                            }
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: AppColors.brand)),
                            ),
                            child: Text(
                              languageProvider.getMessage(
                                'learn_how_to_ride_ebike',
                                'Learn how to ride an E-Bike',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.brand),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
  }

  bool hasAnyProficiency(List<LanguageProficiency>? list) {
    return list?.any((lang) => (lang.read == true ||
            lang.write == true ||
            lang.understand == true)) ??
        false;
  }

  bool get canRideEBike {
    try {
      return userProfile.otherDetails!.vehiclesUsed!.value!
          .contains(AppStrings.ebikeKey);
    } catch (e) {
      return false;
    }
  }

  bool get cannotRideVehicles {
    try {
      return userProfile.otherDetails?.vehiclesUsed?.value?.contains(AppStrings.noneOfTheAbove)==true;
    } catch (e) {
      return false;
    }
  }

  bool continueConditions() {
    if (userProfile.otherDetails?.willingToCleanBathrooms?.value == null ||
        userProfile.otherDetails?.willingToCleanHomeWithPets?.value == null ||
        userProfile.otherDetails?.willingToCleanPoojaRoom?.value == null) {
      return false;
    }

    if ((userProfile.otherDetails?.dietaryPreference?.value ==
            DietaryPreference.Strictly_Vegetarian) &&
        userProfile.otherDetails?.canCleanNonVegKitchen?.value == null) {
      return false;
    }
    if (userProfile.otherDetails?.keepFasts?.value == true &&
        userProfile.otherDetails?.tasksDuringFast?.value == null) {
      return false;
    }
    if (userProfile.otherDetails?.priorTasks?.value != null &&
        userProfile.otherDetails!.priorTasks!.value?.isNotEmpty==true &&
        userProfile.otherDetails?.ownSmartphone?.value == true &&
        // userProfile.otherDetails?.lastDrawnSalary != null &&
        // userProfile.otherDetails?.highestEducation != null &&
        userProfile.otherDetails?.dietaryPreference?.value != null &&
        userProfile.petAverse?.value!=null &&
        hasAnyProficiency(userProfile.otherDetails?.languageProficiency?.value) ==
            true &&
        userProfile.otherDetails?.keepFasts?.value != null &&
        userProfile.otherDetails?.usedGoogleMaps?.value != null &&
        (vehiclesUsed == null ||
            (userProfile.otherDetails?.vehiclesUsed?.value != null &&
                userProfile.otherDetails!.vehiclesUsed!.value!.isNotEmpty)) &&
        (canRideEBike ||
            userProfile.otherDetails?.willingToLearnEBike?.value != null)) {
      return true;
    } else {
      return false;
    }
  }

}
