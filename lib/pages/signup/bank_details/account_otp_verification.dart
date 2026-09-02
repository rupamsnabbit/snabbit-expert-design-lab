import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:snabbit_runner/pages/signup/bank_details/account_details_status_view.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/login_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';

class AccountOtpVerification extends StatefulWidget {
  static const String routeName = "/account_otp_verification";

  const AccountOtpVerification({super.key});

  @override
  State<AccountOtpVerification> createState() => _AccountOtpVerificationState();
}

class _AccountOtpVerificationState extends State<AccountOtpVerification> {
  final TextEditingController otpController = TextEditingController();
  bool init = true;
  int counter = 30;
  Timer? timer;
  bool isError = false;
  bool loadingResendOtp = false;
  bool loadingVerify = false;
  String? errorMessage;
  String codeValue = "";
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingProvider;
  late UserProfileProvider userProfileProvider;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    startTimer();
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      onboardingProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: false);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
    }
    super.didChangeDependencies();
  }

  void initPlatformState() async {
    await SmsAutoFill().listenForCode();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        counter -= 1;
      });
      if (counter == 0) {
        timer?.cancel();
      }
    });
  }

  Future<void> resendOtp() async {
    setState(() {
      loadingResendOtp = true;
    });

    try {
      String appSignature = await SmsAutoFill().getAppSignature;
      final response = await LoginHttp.sendAccountVerificationOtp(
        data: {
          "phone": userProfileProvider.user?.phoneNumber ?? "",
          "app_signature": appSignature,
        },
      );

      if (response?.statusCode == 200) {
        setState(() {
          loadingResendOtp = false;
          counter = 30;
        });
        timer = Timer.periodic(
          const Duration(seconds: 1),
          (t) {
            setState(() {
              counter -= 1;
            });
            if (counter == 0) {
              timer?.cancel();
            }
          },
        );
      } else {
        setState(() {
          loadingResendOtp = false;
          errorMessage = languageProvider.getMessage(
            'otp_resend_failed',
            'Failed to resend OTP. Please try again.',
          );
        });
      }
    } catch (e) {
      setState(() {
        loadingResendOtp = false;
        errorMessage = languageProvider.getMessage(
          'otp_resend_failed',
          'Failed to resend OTP. Please try again.',
        );
      });
    }
  }

  Future<void> verifyOtp() async {
    setState(() {
      loadingVerify = true;
      isError = false;
    });

    try {
      int? moduleId;
      if (onboardingProvider.onboardingModules?.modules != null) {
        try {
          final bankingModule = onboardingProvider.onboardingModules!.modules
              .firstWhere((module) => module.moduleKey == 'bank_details');
          moduleId = bankingModule.id;
        } catch (e) {
          moduleId = null;
        }
      }

      // Get session_id from module response
      final sessionId =
          onboardingProvider.onboardingQuestionResponse?.sessionId;

      // Prepare data for bank OTP verification
      final Map<String, dynamic> otpData = {
        "country_code": "+91",
        "phone_number": userProfileProvider.user?.phoneNumber ?? "",
        "otp": otpController.text,
      };

      // Only add module_id and session_id if they exist
      if (moduleId != null) {
        otpData["module_id"] = moduleId;
      }
      if (sessionId != null) {
        otpData["session_id"] = sessionId;
      }

      final verificationResponse = onboardingProvider.bankVerificationResponse;
      final selectedPayoutOption = onboardingProvider.selectedPayoutOption;

      if (selectedPayoutOption == PayoutOption.upi) {
        final storedUpiId = onboardingProvider.currentUpiId;

        if (verificationResponse?.upiId != null) {
          otpData["upi_id"] = verificationResponse!.upiId;
        } else if (storedUpiId != null) {
          // Use the stored UPI ID if response doesn't contain it
          otpData["upi_id"] = storedUpiId;
        } else {
          setState(() {
            isError = true;
            errorMessage = "UPI details not available for verification";
          });
          return;
        }
      } else if (selectedPayoutOption == PayoutOption.bankDetails) {
        final accountNumber = verificationResponse?.accountNumber;
        final ifscCode = verificationResponse?.ifscCode;
        if (accountNumber != null && ifscCode != null) {
          otpData["account_number"] = accountNumber;
          otpData["ifsc_code"] = ifscCode;
        } else {
          setState(() {
            isError = true;
            errorMessage = "Bank details not available for verification";
          });
          return;
        }
      } else {
        setState(() {
          isError = true;
          errorMessage = "No payout option selected";
        });
        return;
      }

      await onboardingProvider.verifyBankOtp(
        context: context,
        data: otpData,
        onSuccess: () {
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => AccountDetailsStatusView(
                  status: AccountVerificationStatus.success,
                  payoutOption: onboardingProvider.selectedPayoutOption,
                ),
              ),
            );
          }
        },
        onError: (error) {
          if (context.mounted) {
            if (error.errorMessageCode == "OTP_VERIFICATION_ERROR") {
              showSnackbar(context, error.message ?? "OTP verification failed");
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => AccountDetailsStatusView(
                    status: AccountVerificationStatus.failure,
                    payoutOption: onboardingProvider.selectedPayoutOption,
                  ),
                ),
              );
            }
          }
        },
      );
    } catch (e) {
      setState(() {
        isError = true;
        errorMessage = languageProvider.getMessage(
          'otp_verification_error',
          'Error verifying OTP. Please try again.',
        );
      });
    }

    setState(() {
      loadingVerify = false;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    SmsAutoFill().unregisterListener();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 50,
      textStyle:
          Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.n50),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.n40),
        borderRadius: BorderRadius.circular(10),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.brand),
      borderRadius: BorderRadius.circular(10),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: AppColors.n80,
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: AppColors.r50),
      ),
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: AppColors.n80,
      ),
    );

    return Scaffold(
      appBar: CommonAppBar(
        elevation: 6,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage("otp_verification", "OTP Verification"),
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
                  onPressed: otpController.text.length >= 4 && !loadingVerify
                      ? () async {
                          await verifyOtp();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    minimumSize: Size.fromHeight(48.h),
                  ),
                  child: loadingVerify
                      ? const CupertinoActivityIndicator(color: AppColors.n0)
                      : Text(
                          languageProvider.getMessage('continue', "Continue"),
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.n0,
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
                  child: Text(
                    languageProvider.getMessage('go_back', "Go back"),
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppColors.brand),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 40.h),
            child: Column(
              children: [
                Text(
                  languageProvider.getMessage(
                    'otp_sent_message',
                    "OTP has been sent to your registered mobile number",
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                SizedBox(height: 40.h),

                Pinput(
                  isCursorAnimationEnabled: false,
                  cursor: Text(
                    "0",
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: AppColors.n50),
                  ),
                  controller: otpController,
                  preFilledWidget: Text(
                    "0",
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: AppColors.n50),
                  ),
                  errorBuilder: (String? errorText, String pin) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          errorText ?? "",
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: AppColors.r50),
                        ),
                      ),
                    );
                  },
                  mainAxisAlignment: MainAxisAlignment.center,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme:
                      isError ? errorPinTheme : submittedPinTheme,
                  errorPinTheme: errorPinTheme,
                  length: 4,
                  pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                  showCursor: true,
                  onChanged: (value) {
                    if (isError) {
                      setState(() {
                        isError = false;
                        errorMessage = null;
                      });
                    }
                  },
                ),

                if (errorMessage != null) ...[
                  SizedBox(height: 16.h),
                  Text(
                    errorMessage!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.r50,
                          fontWeight: FontWeight.w500,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],

                SizedBox(height: 32.h),

                // Resend OTP section
                if (counter <= 0)
                  loadingResendOtp
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: LinearProgressIndicator(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(16),
                            backgroundColor: Colors.transparent,
                          ),
                        )
                      : TextButton(
                          onPressed: () async {
                            await SmsAutoFill().unregisterListener();
                            await SmsAutoFill().listenForCode();
                            await resendOtp();
                          },
                          child: Text(
                            languageProvider.getMessage(
                                'resend_otp', "Resend OTP"),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.n90,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),

                if (counter > 0)
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(children: [
                      TextSpan(
                        text: languageProvider.getMessage(
                          'resend_otp_in',
                          "Resend OTP in",
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.n70),
                      ),
                      const WidgetSpan(child: SizedBox(width: 8)),
                      TextSpan(
                        text: "00:${counter.toString().padLeft(2, '0')}",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ]),
                  ),

                Opacity(
                  opacity: 0,
                  child: PinFieldAutoFill(
                    currentCode: codeValue,
                    codeLength: 4,
                    onCodeChanged: (code) async {
                      setState(() {
                        otpController.text = code ?? "";
                        codeValue = code.toString();
                      });
                      if (code?.length == 4) {
                        await verifyOtp();
                      }
                    },
                    onCodeSubmitted: (val) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
