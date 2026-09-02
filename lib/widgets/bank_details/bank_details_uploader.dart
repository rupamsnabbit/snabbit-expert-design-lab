import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/registration_details_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/text_form.dart';
import 'package:snabbit_runner/widgets/true_false_radio_button.dart';

import '../../utils/common_methods.dart';

class BankDetailsUploader extends StatefulWidget {
  const BankDetailsUploader({super.key});

  @override
  State<BankDetailsUploader> createState() => _BankDetailsUploaderState();
}

class _BankDetailsUploaderState extends State<BankDetailsUploader> {
  // final _formKey = GlobalKey<FormState>();
  TextEditingController beneficiaryNameController = TextEditingController();
  TextEditingController accountNumberController = TextEditingController();
  TextEditingController confirmAccountNumberController =
      TextEditingController();
  TextEditingController ifscCodeController = TextEditingController();
  String? accessToken;
  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;

  late LanguageProvider languageProvider;
  bool init = true;
  String? ifscCodeError;

  // late BankDetailsValidationProvider bankDetailsValidationProvider;

  var logger = Logger(
    printer: PrettyPrinter(),
  );

  @override
  void initState() {
    getRunnerCredentials();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;
      // userProfile.registrationStep = RunnerRegistrationStep.bank;
      beneficiaryNameController.text =
          userProfile.verifiedBeneficiaryName ?? '';
      accountNumberController.text = userProfile.bankAccountNumber ?? '';
      confirmAccountNumberController.text = userProfile.bankAccountNumber ?? '';
      // filedIncomeTax = userProfile.otherDetails!.filledItrLast2Years;
      ifscCodeController.text = userProfile.bankIfscCode ?? '';
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      // bankDetailsValidationProvider =  Provider.of<BankDetailsValidationProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  getRunnerCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
  }

  bool isValidBankDetails() {
    try {
      return accountNumberController.text ==
              confirmAccountNumberController.text &&
          ifscCodeController.text.length == 11;
    } catch (e) {
      return true;
    }
  }

  Future<void> verifyBankDetails() async {
    if (isValidBankDetails()) {
      // bankDetailsValidationProvider.verificationError = null;
      // bankDetailsValidationProvider.ifscError = null;
      userProfileProvider.loading = true;
      userProfileProvider.error = null;

      final response = await RegistrationDetailsHttp.verifyBankDetails(data: {
        "bank_no": accountNumberController.text,
        "ifsc": ifscCodeController.text,
        "runner_id": userProfile.id
      });

      // logger.i(response?.statusCode);
      // logger.i(response?.data);
      if (response?.statusCode == 200) {
        userProfile.verifiedBeneficiaryName = response?.data['full_name'];
        userProfile.bankIfscCode = ifscCodeController.text;

        userProfileProvider.notifyUserListeners();

        beneficiaryNameController.text = userProfile.verifiedBeneficiaryName!;
        // accountVerified = true;
        userProfileProvider.updateBankVerificationState(true);

        userProfileProvider.loading = false;
        // bankDetailsValidationProvider.verificationError = null;
        // bankDetailsValidationProvider.ifscError = null;
        userProfileProvider.error = null;
      } else {
        String? error;
        try {
          error = response?.data['errors'][0]['message'];
        } catch (e) {
          error = 'Invalid details. Please check your entries.';
        }
        //TODO: IMPLEMENT ERROR HANDLER WHEN START RECEIVING RESPONSE ERROR
        // if(error=="Verification Failed."){
        //   verificationError=error;
        // }else{
        //   ifscError=error;
        // }
        // setState(() {
        //
        //   accountVerified = false;
        // });
        userProfileProvider.error = error;
        userProfileProvider.updateBankVerificationState(false);
        userProfileProvider.loading = false;
        try {
          if (mounted) {
            showSnackbar(context, error!);
          }
        } catch (e) {
          // DO NOTHING
        }
      }
    } else {
      showSnackbar(context, 'Fill up correct details');
    }
  }

  bool isAccountNumberMatching() {
    return confirmAccountNumberController.text !=
            accountNumberController.text &&
        confirmAccountNumberController.text.isNotEmpty;
  }

  String? showErrorForConfirmBank() {
    // return bankDetailsValidationProvider.verificationError==null && isAccountNumberMatching()?languageProvider.getMessage('account_number_match_error',"Account number does not match",):null;
    return userProfileProvider.error == null && isAccountNumberMatching()
        ? languageProvider.getMessage(
            'account_number_match_error',
            "Account number does not match",
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return userProfileProvider.loading == true
        ? const Center(
            child: CupertinoActivityIndicator(),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OnboardingQuestion(
                mandatory: true,
                error: userProfileProvider.error ?? showErrorForConfirmBank(),
                questionKey: 'bank_account_number',
                questionDefault: 'Bank account number',
                answer: TextFormSnabbit(
                  controller: accountNumberController,
                  hintText: languageProvider.getMessage(
                      'bank_account_number_hint', 'Enter account number'),
                  keyboardType: TextInputType.number,
                  isLoading: userProfileProvider.loading,
                  isFieldValidAndVerified:
                      userProfileProvider.user?.bankVerified ?? false,
                  onChanged: (v) {
                    userProfile.bankAccountNumber = v;
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
                    // verifyBankDetails();
                  },
                ),
              ),
              Gap.gap16h,
              OnboardingQuestion(
                mandatory: true,
                error: userProfileProvider.error ?? showErrorForConfirmBank(),
                questionKey: 'confirm_bank_account_number',
                questionDefault: 'Confirm bank account number',
                answer: TextFormSnabbit(
                  controller: confirmAccountNumberController,
                  hintText: languageProvider.getMessage(
                    'confirm_bank_account_number_hint',
                    'Enter account number',
                  ),
                  keyboardType: TextInputType.number,
                  isLoading: userProfileProvider.loading,
                  isFieldValidAndVerified:
                      userProfileProvider.user?.bankVerified ?? false,
                  obscureText: true,
                  onChanged: (v) {
                    setState(() {
                      confirmAccountNumberController.text = v;
                    });
                    userProfileProvider.notifyUserListeners();

                    if (showErrorForConfirmBank() != null) {
                      // setState(() {
                      //   accountVerified = false;
                      //
                      // });
                      userProfileProvider.error = null;
                      userProfileProvider.loading = false;
                      userProfileProvider.updateBankVerificationState(false);
                    } else {
                      // if (_formKey.currentState!.validate()) {
                      // verifyBankDetails();
                      // }
                    }
                  },
                ),
              ),
              Gap.gap16h,
              OnboardingQuestion(
                mandatory: true,
                questionKey: 'ifsc_code',
                questionDefault: 'IFSC Code',
                // error: bankDetailsValidationProvider.verificationError ?? bankDetailsValidationProvider.ifscError,
                error: ifscCodeError,
                answer: TextFormSnabbit(
                  controller: ifscCodeController,
                  hintText: languageProvider.getMessage(
                    'ifsc_code_hint',
                    'Eg. HDFC0001234',
                  ),
                  isLoading: userProfileProvider.loading,
                  isFieldValidAndVerified:
                      userProfileProvider.user?.bankVerified ?? false,
                  maxLength: 11,
                  onChanged: (v) {
                    userProfile.bankIfscCode = v;
                    userProfileProvider.notifyUserListeners();

                    setState(() {
                      ifscCodeController.text = v.toUpperCase();
                    });
                    if (v.length == 11) {
                      ifscCodeError = null;
                      // if (_formKey.currentState!.validate()) {
                      // verifyBankDetails();
                      // }
                    } else {
                      // setState(() {
                      //   accountVerified = false;
                      // });
                      userProfileProvider.loading = false;
                      userProfileProvider.error = null;
                      ifscCodeError = "IFSC code should be 11 characters long";
                      userProfileProvider.updateBankVerificationState(false);
                    }
                  },
                ),
              ),
              Gap.gap16h,
              OnboardingQuestion(
                mandatory: true,
                questionKey: 'account_holder_name',
                questionDefault: 'Account holder name',
                answer: TextFormSnabbit(
                  fillColor: AppColors.n20,
                  controller: beneficiaryNameController,
                  hintText: languageProvider.getMessage(
                      'account_holder_name_hint', 'Account holder name'),
                  readOnly: true,
                  isLoading: userProfileProvider.loading,
                  isFieldValidAndVerified:
                      userProfileProvider.user?.bankVerified ?? false,
                ),
              ),
              Gap.gap16h,
              TrueFalseRadioButton(
                  mandatory: true,
                  questionKey: 'itr_filled_in_2yrs',
                  question:
                      "Have you filed your Income Tax Return at least once in the last 2 years?",
                  criticalError: userProfile.otherDetails?.filledItrLast2Years
                      ?.isValueAcceptable() ==
                      true
                      ? null
                      : languageProvider.getMessage('pls_review_answer_carefully', "Please review this answer carefully",),
                  onOption1Tap: () {
                    userProfile.otherDetails!.filledItrLast2Years?.value = true;
                    userProfileProvider.notifyUserListeners();
                  },
                  onOption2Tap: () {
                    userProfile.otherDetails!.filledItrLast2Years?.value = false;
                    userProfileProvider.notifyUserListeners();
                  },
                  checkBoxOption1Value:
                      userProfile.otherDetails!.filledItrLast2Years?.value ?? false,
                  checkBoxOption2Value:
                      userProfile.otherDetails!.filledItrLast2Years?.value != null
                          ? !userProfile.otherDetails!.filledItrLast2Years?.value!
                          : false),
              if (canContinue() != true &&
                  userProfileProvider.error == null &&
                  isValidBankDetails() && userProfileProvider.user?.bankVerified != true)
                Container(
                  width: 1.sw,
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: ElevatedButton(
                    onPressed: userProfileProvider.loading != true
                        ? () async {
                            userProfileProvider.loading = true;
                            setState(() {});
                            await verifyBankDetails();
                            userProfileProvider.loading = false;
                            setState(() {});
                          }
                        : null,
                    child: Text(
                      languageProvider.getMessage(
                        'verify',
                        'Verify',
                      ),
                    ),
                  ),
                ),
            ],
          );
  }

  bool canContinue() {
    if (userProfileProvider.user?.bankAccountNumber?.isNotEmpty == true &&
        userProfileProvider.user?.bankIfscCode?.length == 11 &&
        userProfileProvider.user?.bankVerified == true &&
        userProfileProvider.user?.otherDetails!.filledItrLast2Years != null) {
      return true;
    } else {
      return false;
    }
  }
}
