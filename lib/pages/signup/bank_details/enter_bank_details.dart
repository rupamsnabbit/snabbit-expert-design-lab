import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/bank_details/bank_account_details_screen.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/onboarding_question_v2.dart';
import 'package:snabbit_runner/widgets/text_form.dart';
import 'package:snabbit_runner/widgets/text_form_v2.dart';

class EnterBankDetails extends StatefulWidget {
  static const String routeName = "/enter_bank_details";
  const EnterBankDetails({super.key});

  @override
  State<EnterBankDetails> createState() => _EnterBankDetailsState();
}

class _EnterBankDetailsState extends State<EnterBankDetails> {
  bool init = true;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  late UserProfile? userProfile;
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController confirmAccountNumberController =
      TextEditingController();
  final TextEditingController ifscCodeController = TextEditingController();
  String? ifscCodeError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: false);
      userProfile = userProfileProvider.user;
      accountNumberController.text = userProfile?.bankAccountNumber ?? '';
      confirmAccountNumberController.text =
          userProfile?.bankAccountNumber ?? '';
      ifscCodeController.text = userProfile?.bankIfscCode ?? '';
      init = false;
      setState(() {});
    }
  }

  bool canContinue() {
    return accountNumberController.text.isNotEmpty &&
        confirmAccountNumberController.text.isNotEmpty &&
        ifscCodeController.text.isNotEmpty &&
        !isAccountNumberMatching(); // Only allow if account numbers match
  }

  bool isAccountNumberMatching() {
    return confirmAccountNumberController.text !=
            accountNumberController.text &&
        confirmAccountNumberController.text.isNotEmpty;
  }

  String? showErrorForConfirmBank() {
    return userProfileProvider.error == null && isAccountNumberMatching()
        ? languageProvider.getMessage(
            'this_bank_account_number_is_incorrect',
            "This bank account number is incorrect",
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingStepsProvider>(
      builder: (context, onboardingProvider, child) {
        return Scaffold(
          appBar: CommonAppBar(
            elevation: 6,
            centerTitle: true,
            title: Text(
              languageProvider.getMessage(
                  "enter_bank_details", "Enter Bank Details"),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 16.sp,
                  ),
            ),
          ),
          persistentFooterButtons: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 48.h,
                      maxWidth: 1.sw,
                    ),
                    child: ElevatedButton(
                      onPressed: canContinue() && !onboardingProvider.loading
                          ? onContinue
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        minimumSize: Size.fromHeight(48.h),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: onboardingProvider.loading
                            ? null
                            : Text(
                                languageProvider.getMessage(
                                    'confirm', "Confirm"),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: canContinue()
                                          ? AppColors.n0
                                          : AppColors.n60,
                                    ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 1.sw,
                      maxHeight: 48.h,
                    ),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.brand,
                          width: 1.r,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        minimumSize: Size.fromHeight(48.h),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          languageProvider.getMessage('go_back', "Go Back"),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: AppColors.brand),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          body: onboardingProvider.loading == true
              ? const Center(
                  child: CupertinoActivityIndicator(),
                )
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Column(
                        children: [
                          SizedBox(height: 40.h),
                          OnboardingQuestionV2(
                            mandatory: true,
                            questionTextStyle:
                                Theme.of(context).textTheme.labelMedium,
                            questionKey: 'bank_account_number',
                            questionDefault: 'Bank account number',
                            padding: EdgeInsets.zero,
                            answer: TextFormSnabbitV2(
                              controller: accountNumberController,
                              hintText: languageProvider.getMessage(
                                  'bank_account_number_hint',
                                  'Enter account number'),
                              keyboardType: TextInputType.number,
                              isLoading: onboardingProvider.loading,
                              isFieldValidAndVerified:
                                  userProfileProvider.user?.bankVerified ??
                                      false,
                              onChanged: (v) {
                                userProfile?.bankAccountNumber = v;
                                userProfileProvider.notifyUserListeners();
                                setState(() {
                                  accountNumberController.text = v;
                                });
                                if (userProfileProvider.loading) {
                                  userProfileProvider.loading = false;
                                }
                                if (userProfileProvider.error != null) {
                                  userProfileProvider.error = null;
                                }
                              },
                            ),
                          ),
                          SizedBox(height: 24.h),
                          OnboardingQuestionV2(
                            mandatory: true,
                            questionTextStyle:
                                Theme.of(context).textTheme.labelMedium,
                            questionKey: 'confirm_bank_account_number',
                            questionDefault: 'Confirm bank account number',
                            padding: EdgeInsets.zero,
                            answer: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormSnabbit(
                                  controller: confirmAccountNumberController,
                                  hintText: languageProvider.getMessage(
                                    'confirm_bank_account_number_hint',
                                    'Enter account number',
                                  ),
                                  keyboardType: TextInputType.number,
                                  isLoading: onboardingProvider.loading,
                                  isFieldValidAndVerified:
                                      userProfileProvider.user?.bankVerified ??
                                          false,
                                  obscureText: true,
                                  onChanged: (v) {
                                    setState(() {
                                      confirmAccountNumberController.text = v;
                                    });
                                    userProfileProvider.notifyUserListeners();
                                    if (showErrorForConfirmBank() != null) {
                                      userProfileProvider.error = null;
                                      userProfileProvider.loading = false;
                                      userProfileProvider
                                          .updateBankVerificationState(false);
                                    }
                                  },
                                ),
                                if (showErrorForConfirmBank() != null) ...[
                                  SizedBox(height: 8.h),
                                  Text(
                                    showErrorForConfirmBank()!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.r40,
                                        ),
                                  )
                                ]
                              ],
                            ),
                          ),
                          SizedBox(height: 24.h),
                          OnboardingQuestionV2(
                            mandatory: true,
                            questionTextStyle:
                                Theme.of(context).textTheme.labelMedium,
                            questionKey: 'ifsc_code',
                            questionDefault: 'IFSC Code ',
                            padding: EdgeInsets.zero,
                            answer: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormSnabbitV2(
                                  controller: ifscCodeController,
                                  hintText: languageProvider.getMessage(
                                    'ifsc_code_hint',
                                    'Enter IFSC code',
                                  ),
                                  isLoading: onboardingProvider.loading,
                                  maxLength: 11,
                                  isFieldValidAndVerified:
                                      userProfileProvider.user?.bankVerified ??
                                          false,
                                  onChanged: (v) {
                                    userProfile?.bankIfscCode = v;
                                    userProfileProvider.notifyUserListeners();
                                    setState(() {
                                      ifscCodeController.text = v.toUpperCase();
                                    });
                                    ifscCodeError = null;
                                    userProfileProvider.loading = false;
                                    userProfileProvider.error = null;
                                  },
                                ),
                                if (ifscCodeError != null) ...[
                                  SizedBox(height: 8.h),
                                  Text(
                                    ifscCodeError!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.r40,
                                        ),
                                  )
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  void onContinue() async {
    await onboardingStepsProvider.verifyBankOrUpi(
      context: context,
      data: {
        "account_number": accountNumberController.text.trim(),
        "ifsc_code": ifscCodeController.text.trim(),
      },
      onSuccess: () {
        // Check if status is REGISTERED before navigating
        if (onboardingStepsProvider.bankVerificationResponse?.status ==
            "REGISTERED") {
          Navigator.of(context)
              .pushReplacementNamed(BankAccountDetailsScreen.routeName);
        } else {
          // Handle other statuses if needed
          showSnackbar(context, "Verification incomplete. Please try again.");
        }
      },
      onError: (error) {
        // Update the UI with the error
        showSnackbar(context, error.message ?? "Something went wrong");
      },
    );
  }
}
