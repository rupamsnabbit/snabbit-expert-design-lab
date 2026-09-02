import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import '../../providers/language_provider.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import '../../widgets/circular_checkbox.dart';
import '../../widgets/gap.dart';
import '../../widgets/progress_indicator.dart';

class CustomerService extends StatefulWidget {
  static const String routeName = "/customer-service";

  const CustomerService({super.key});

  @override
  State<CustomerService> createState() => _CustomerServiceState();
}

class _CustomerServiceState extends State<CustomerService> {
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  UserProfile? userProfile;
  bool init = true;
  List<AnswerKeyDefault> glassBreakOptions = [
    AnswerKeyDefault(
      key: "glass_break_option_1",
      defaultValue: "Hide it and won’t let them find out",
    ),
    AnswerKeyDefault(
      key: "glass_break_option_2",
      defaultValue: "Inform the employer, accept your mistake and apologise",
    ),
    AnswerKeyDefault(
      key: "glass_break_option_3",
      defaultValue: "Panic, and call my manager",
    ),
  ];
  List<AnswerKeyDefault> lateAndCustomerAngryOptions = [
    AnswerKeyDefault(
      key: "late_and_customer_angry_option_1",
      defaultValue: "Apologize and ensure their work will be done quickly",
    ),
    AnswerKeyDefault(
      key: "late_and_customer_angry_option_2",
      defaultValue: "Ignore the issue",
    ),
    AnswerKeyDefault(
      key: "late_and_customer_angry_option_3",
      defaultValue: "Explain reasons why you were late and defend yourself",
    ),
  ];
  List<AnswerKeyDefault> customerRudeOptions = [
    AnswerKeyDefault(
      key: "customer_rude_option_1",
      defaultValue:
          "Stay calm, respond peacefully and help them resolve the issue",
    ),
    AnswerKeyDefault(
      key: "customer_rude_option_2",
      defaultValue: "If they are wrong and I am right I must prove my point",
    ),
    AnswerKeyDefault(
      key: "customer_rude_option_3",
      defaultValue: "If they get angry at me I can get angry at them",
    ),
  ];

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

  bool canContinue() {
    try {
      return userProfile?.otherDetails?.glassBreak?.value != null &&
          userProfile?.otherDetails?.lateAndCustomerAngry?.value != null &&
          userProfile?.otherDetails?.customerRude?.value != null;
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: canContinue() && !userProfileProvider.loading
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
      body: userProfileProvider.loading
          ? const Center(child: CupertinoActivityIndicator())
          : userProfile == null
              ? const Center(child: Text("Error: User profile not found"))
              : Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ProgressIndicatorAtTop(value: 10),
                        Gap.gap32h,
                        const OnboardingPageHeader(
                          titleKey: 'customer_service_title',
                          titleDefault: 'Customer service',
                          subtitleKey: 'customer_service_subtitle',
                          subtitleDefault:
                              'How would you handle these situations',
                        ),
                        Gap.gap16h,
                        OnboardingQuestion(
                          questionKey: 'glass_break',
                          questionDefault:
                              'If you break a plate or glass by mistake, what will you do?',
                          criticalError: userProfile?.otherDetails?.glassBreak
                              ?.isValueAcceptable() ==
                              true
                              ? null
                              : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                          answer: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 1,
                            childAspectRatio: 6,
                            children: glassBreakOptions.map((e) {
                              String currentAnswer = languageProvider
                                  .getMessage(e.key, e.defaultValue);
                              return GestureDetector(
                                onTap: () {
                                  userProfile!.otherDetails?.glassBreak?.value =
                                      currentAnswer;
                                  userProfileProvider.notifyUserListeners();
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                      value: userProfile!
                                              .otherDetails?.glassBreak?.value ==
                                          currentAnswer,
                                    ),
                                    SizedBox(width: 6.w),
                                    Expanded(
                                      child: Text(
                                        currentAnswer,
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
                        Gap.gap16h,
                        OnboardingQuestion(
                          questionKey: 'late_and_customer_angry',
                          questionDefault:
                              'If you reach 30 mins late and the customer is angry and rude to you, how will you react?',
                          criticalError: userProfile?.otherDetails?.lateAndCustomerAngry
                              ?.isValueAcceptable() ==
                              true
                              ? null
                              : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                          answer: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 1,
                            childAspectRatio: 6,
                            children: lateAndCustomerAngryOptions.map((e) {
                              String currentAnswer = languageProvider
                                  .getMessage(e.key, e.defaultValue);
                              return GestureDetector(
                                onTap: () {
                                  userProfile!.otherDetails
                                      ?.lateAndCustomerAngry?.value = currentAnswer;
                                  userProfileProvider.notifyUserListeners();
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                      value: userProfile!.otherDetails
                                              ?.lateAndCustomerAngry?.value ==
                                          currentAnswer,
                                    ),
                                    SizedBox(width: 6.w),
                                    Expanded(
                                      child: Text(
                                        currentAnswer,
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
                        Gap.gap16h,
                        OnboardingQuestion(
                          questionKey: 'customer_rude',
                          questionDefault:
                              'If the customer is rude to you or angry with you, how will you react?',
                          criticalError: userProfile?.otherDetails?.customerRude
                              ?.isValueAcceptable() ==
                              true
                              ? null
                              : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                          answer: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 1,
                            childAspectRatio: 6,
                            children: customerRudeOptions.map((e) {
                              String currentAnswer = languageProvider
                                  .getMessage(e.key, e.defaultValue);
                              return GestureDetector(
                                onTap: () {
                                  userProfile!.otherDetails?.customerRude?.value =
                                      currentAnswer;
                                  userProfileProvider.notifyUserListeners();
                                },
                                child: Row(
                                  children: [
                                    CircularCheckbox(
                                      value: userProfile!
                                              .otherDetails?.customerRude?.value ==
                                          currentAnswer,
                                    ),
                                    SizedBox(width: 6.w),
                                    Expanded(
                                      child: Text(
                                        currentAnswer,
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
                      ],
                    ),
                  ),
                ),
    );
  }
}

class AnswerKeyDefault {
  String key;
  String defaultValue;

  AnswerKeyDefault({
    required this.key,
    required this.defaultValue,
  });
}
