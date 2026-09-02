import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:snabbit_runner/pages/signup/bank_details/account_otp_verification.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/login_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';

class AccountConfirmationTnC extends StatefulWidget {
  static const String routeName = "/account_confirmation_tnc";

  const AccountConfirmationTnC({super.key});

  @override
  State<AccountConfirmationTnC> createState() => _AccountConfirmationTnCState();
}

class _AccountConfirmationTnCState extends State<AccountConfirmationTnC> {
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  late UserProfileProvider userProfileProvider;
  bool loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    onboardingStepsProvider =
        Provider.of<OnboardingStepsProvider>(context, listen: false);
    userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        elevation: 6,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage(
              "consent_and_agreement", "Consent and Agreement"),
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
                  onPressed: loading
                      ? null
                      : () async {
                          await sendOtpAndNavigate();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    minimumSize: Size.fromHeight(48.h),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: loading
                        ? null
                        : Text(
                            languageProvider.getMessage(
                                'agree_and_continue', "Agree and continue"),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.n0,
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
                      languageProvider.getMessage('go_back', "Go back"),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: Text(
            languageProvider.getMessage(
              'account_confirmation_tnc_text',
              "By proceeding with this account verification, you hereby confirm and agree to our terms and conditions:\n\n"
                  "Please read these terms carefully before proceeding. If you do not agree with any of these conditions, please do not proceed with the account verification process.",
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  fontSize: 14.sp,
                ),
          ),
        ),
      ),
    );
  }

  Future<void> sendOtpAndNavigate() async {
    setState(() {
      loading = true;
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
        if (mounted) {
          Navigator.of(context).pushNamed(AccountOtpVerification.routeName);
        }
      } else {
        // Handle error - show snackbar or error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.getMessage(
                  'otp_send_failed',
                  'Failed to send OTP. Please try again.',
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getMessage(
                'otp_send_failed',
                'Failed to send OTP. Please try again.',
              ),
            ),
          ),
        );
      }
    }

    setState(() {
      loading = false;
    });
  }
}
