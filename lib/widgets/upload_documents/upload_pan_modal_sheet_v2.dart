import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/onboarding_steps_services.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:url_launcher/url_launcher.dart';

class UploadPanModalSheetV2 extends StatefulWidget {
  const UploadPanModalSheetV2({super.key});

  @override
  State<UploadPanModalSheetV2> createState() => _UploadPanModalSheetV2State();
}

class _UploadPanModalSheetV2State extends State<UploadPanModalSheetV2> {
  final TextEditingController panController = TextEditingController();
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  bool init = true;
  bool loading = false;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      init = false;
    }
  }

  bool _isValidPanCard(String pan) {
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return panRegex.hasMatch(pan);
  }

  void onContinue() async {
    if (panController.text.isEmpty || !_isValidPanCard(panController.text)) {
      setState(() {
        error = "Please enter a valid PAN number";
      });
      return;
    }

    setState(() {
      error = null;
      loading = true;
    });

    try {
      final response = await OnboardingStepsServices.updatePan(data: {
        "pan_number": panController.text,
      });

      if (response?.statusCode == 200) {
        final responseData = response!.data;
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('errors') &&
            responseData['errors'] is List &&
            responseData['errors'].isNotEmpty) {
          // Handle custom error in success response
          final errorData = responseData['errors'][0];
          final customError = CustomError(
            title: errorData['title'] ?? "Verification Error",
            message: errorData['message'] ?? "PAN verification failed",
            errorMessageCode: errorData['code'] ?? "VALIDATION_ERROR",
          );
          if (mounted) {
            showSnackbar(
                context, customError.message ?? "PAN verification failed");
            setState(() {
              error = customError.message ?? "PAN verification failed";
            });
          }
        } else {
          if (mounted) {
            userProfileProvider.runnersMeSetup();
            Navigator.of(context).pop();
          }
        }
      } else {
        final responseData = response?.data;
        String errorMessage = "PAN verification failed. Please try again.";

        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('errors') &&
            responseData['errors'] is List &&
            responseData['errors'].isNotEmpty) {
          final errorData = responseData['errors'][0];
          final customError = CustomError(
            title: errorData['title'] ?? "Verification Error",
            message: errorData['message'] ?? "PAN verification failed",
            errorMessageCode: errorData['code'] ?? "VALIDATION_ERROR",
          );
          errorMessage = customError.message ?? errorMessage;
        }

        if (mounted) {
          showSnackbar(context, errorMessage);
          setState(() {
            error = errorMessage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context, "PAN verification failed. Please try again.");
        setState(() {
          error = "PAN verification failed. Please try again.";
        });
      }
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonBottomSheetSetup(
      horizontalPadding: 0,
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 8.h,
            ),
            Text(
              languageProvider.getMessage(
                  "pan_card_details", "PAN card details"),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.left,
            ),
            SizedBox(
              height: 18.h,
            ),
            Text(
              languageProvider.getMessage('pan_card_number', 'PAN card number'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    height: 18 / 13,
                    letterSpacing: -0.24,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: panController,
              maxLength: 10,
              onChanged: (v) {
                setState(() {
                  panController.text = v.toUpperCase();
                });
              },
              decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: languageProvider.getMessage(
                    'pan_number_hint',
                    'Enter your PAN Card number',
                  ),
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.n50,
                      ),
                  counter: const SizedBox()),
            ),
            SizedBox(height: 12.h),
            ActionableText(
              statement: "Don't have a PAN ? ",
              actionable: "Create ePAN ",
              action: () async {
                userProfileProvider.panCardUnavailable = true;
                try {
                  await launchUrl(Uri.parse(
                      'https://eportal.incometax.gov.in/iec/foservices/#/pre-login/instant-e-pan/getNewEpan')); // Hardcoded URL
                } catch (_) {}
              },
            ),
            SizedBox(height: 20.h),
            if (error != null)
              Text(
                '$error',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.r50),
              ),
            SizedBox(
              width: 1.sw,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
                onPressed: _isValidPanCard(panController.text) && !loading
                    ? onContinue
                    : null,
                child: loading
                    ? const CupertinoActivityIndicator()
                    : Text(
                        languageProvider.getMessage(
                          'continue',
                          "Continue",
                        ),
                      ),
              ),
            ),
            SizedBox(
              height: 16.h,
            ),
          ],
        ),
      ),
    );
  }
}

class ActionableText extends StatelessWidget {
  final String statement;
  final String actionable;
  final VoidCallback? action;
  final EdgeInsets? padding;

  const ActionableText({
    super.key,
    required this.statement,
    required this.actionable,
    required this.action,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final staticTextStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 20 / 15,
          letterSpacing: -0.24,
        );

    final actionTextStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          height: 20 / 15,
          letterSpacing: -0.24,
          color: action == null ? AppColors.n50 : AppColors.brand,
          decoration: TextDecoration.underline,
          decorationColor: action == null ? AppColors.n50 : AppColors.brand,
        );
    return Padding(
      padding: padding ?? const EdgeInsets.all(16.0),
      child: RichText(
        text: TextSpan(
          style: staticTextStyle,
          children: <InlineSpan>[
            TextSpan(
              text: statement,
            ),
            WidgetSpan(
              baseline: TextBaseline.alphabetic,
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: action,
                child: Text(
                  actionable,
                  style: actionTextStyle,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
