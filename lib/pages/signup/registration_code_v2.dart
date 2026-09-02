import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/models/training_center.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/server_requests/maps_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/registration_flow/work_schedule_selection.dart';
import '../../providers/language_provider.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/onboarding_question.dart';
import '../../widgets/remote_image_handler.dart';
import '../../utils/extensions/cdn_extensions.dart';

class RegistrationCodeV2 extends StatefulWidget {
  static const String routeName = "/registration-code-v2";

  const RegistrationCodeV2({super.key});

  @override
  State<RegistrationCodeV2> createState() => _RegistrationCodeV2State();
}

class _RegistrationCodeV2State extends State<RegistrationCodeV2> {
  bool init = true;
  late UserProfileProvider userProfileProvider;
  TextEditingController registrationCodeTextController =
      TextEditingController();
  TextEditingController onboardingAgentCodeTextController =
      TextEditingController();
  late LanguageProvider languageProvider;
  List<TrainingCenter> trainingCenters = [];
  bool _resendingCode = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      registrationCodeTextController.text =
          userProfileProvider.user?.registrationCode ?? "";
      onboardingAgentCodeTextController.text =
          userProfileProvider.user?.onboardingAgentCode ?? "";
    }
    super.didChangeDependencies();
  }

  ///[canContinue] will validate the form entries for [registrationCodeTextController] and [onboardingAgentCodeTextController]
  ///and will only proceed if they contain non empty Strings
  bool canContinue() {
    bool result = false;
    try {
      result = !userProfileProvider.loading &&
          (userProfileProvider.user?.registrationCode?.trim().isNotEmpty ??
              false) &&
          (userProfileProvider.user?.onboardingAgentCode?.trim().isNotEmpty ??
              false) &&
          (userProfileProvider.user?.tc != null);
    } catch (e) {
      result = false;
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  void initialize() async {
    final response = await MapsHttp.fetchTrainingCenters();

    if (response != null) {
      if (response.statusCode == 200) {
        trainingCenters = response.data
            .map<TrainingCenter>((e) => TrainingCenter.fromJson(e))
            .toList();
        setState(() {});
      }
    }
  }

  /// Resend registration code via SMS and WhatsApp
  Future<void> _resendRegistrationCode() async {
    if (_resendingCode) return;

    setState(() {
      _resendingCode = true;
    });

    try {
      final response = await RunnerHttp.resendRegistrationCode();

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        showSnackbar(
          context,
          languageProvider.getMessage(
            'code_resent_success',
            'Registration code resent successfully',
          ),
        );
      } else {
        final backendErrorMessage = ResponseError.fromMap(response?.data ?? {}).getFirstError()?.message;
        showSnackbar(
          context,
          backendErrorMessage??languageProvider.getMessage(
            'code_resend_failed',
            'Failed to resend code. Please try again.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(
          context,
          languageProvider.getMessage(
            'code_resend_error',
            'An error occurred while resending code',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _resendingCode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.getMessage(
              "registration_details_title", "Registration Details"),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        leading: InkWell(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.n80,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),
            //TextField for onboarding agent code
            OnboardingQuestion(
              questionKey: 'onboarding_agent_code',
              questionDefault: 'Onboarding Agent Code',
              answer: TextField(
                enabled: !userProfileProvider.loading,
                controller: onboardingAgentCodeTextController,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.number,
                maxLength: 10,
                onChanged: (value) {
                  if (value.isEmpty) {
                    userProfileProvider.user?.onboardingAgentCode = null;
                  } else {
                    userProfileProvider.user?.onboardingAgentCode = value;
                  }
                  setState(() {});
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: languageProvider.getMessage(
                    'agent_code_hint',
                    'Enter code',
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            //TextField for Registration code
            OnboardingQuestion(
              questionKey: 'registration_code',
              questionDefault: 'Registration Code',
              answer: TextField(
                enabled: !userProfileProvider.loading,
                controller: registrationCodeTextController,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  if (value.isEmpty) {
                    userProfileProvider.user?.registrationCode = null;
                  } else {
                    userProfileProvider.user?.registrationCode = value;
                  }
                  setState(() {});
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: languageProvider.getMessage(
                    'reg_code_hint',
                    'Enter code',
                  ),
                ),
              ),
              questionTrailingItem: Padding(
                padding: EdgeInsets.only(left: 8.w),
                // Todo: Add the icons at the end of the message and shape the tooltip
                child: Tooltip(
                  waitDuration: const Duration(milliseconds: 300),
                  showDuration: const Duration(seconds: 3),
                  triggerMode: TooltipTriggerMode.tap,
                  preferBelow: false,
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.n0,
                    border: Border.all(
                      color: Color(0x330C0C0D),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  richMessage: WidgetSpan(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Todo: key does not exist
                        Text(
                          languageProvider.getMessage(
                              "resend_code_tooltip_message",
                              "Code was already sent to WhatsApp and SMS."),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color: Color(0x8C0C0C0D),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RemoteImageHandler(
                              imageUrl: "onboarding/whatsapp_icon.png".cdn,
                              width: 20.r,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(width: 4.w),
                            RemoteImageHandler(
                              imageUrl: "onboarding/sms_icon.png".cdn,
                              width: 18.r,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: const Color(0xff6D7783),
                  ),
                ),
              ),
            ),
            // SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              child: Row(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          height: 16.h,
                          width: 16.h,
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12.r,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 150.w,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              languageProvider.getMessage(
                                  'sent_via_sms', "Sent via SMS"),
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        VerticalDivider(
                          width: 0,
                          thickness: 1,
                          color: AppColors.n70,
                        ),
                        SizedBox(width: 6.w),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _resendingCode ? null : _resendRegistrationCode,
                      child: Text(
                        languageProvider.getMessage(
                            'resend_code', "Resend code"),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _resendingCode
                                ? AppColors.n70
                                : AppColors.brand,
                            decoration: TextDecoration.underline,
                            decorationColor: _resendingCode
                                ? AppColors.n70
                                : AppColors.brand),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            OnboardingQuestion(
              questionKey: 'training_center',
              questionDefault: 'Preferred training centre location',
              answer: CustomDropdown<TrainingCenter>(
                onSelected: (val) {
                  userProfileProvider.tc = val;
                },
                hintText: languageProvider.getMessage(
                  'tc_hint',
                  'Choose one option',
                ),
                items: trainingCenters,
                selectedItem: userProfileProvider.user?.tc,
              ),
            ),
            SizedBox(height: 16.h),
            OnboardingQuestion(
              questionKey: 'work_schedule',
              questionDefault: 'Work schedule',
              criticalError: userProfileProvider
                              .user?.workSchedule?.acceptedValues?.isNotEmpty ==
                          true &&
                      userProfileProvider.user?.workSchedule?.contains(
                              userProfileProvider
                                  .user?.workSchedule?.value?.key) ==
                          true
                  ? languageProvider.getMessage(
                      'pls_review_answer_carefully',
                      "Please review this answer carefully",
                    )
                  : null,
              answer: const WorkScheduleSelection(),
            ),
            if (userProfileProvider.error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  userProfileProvider.error!,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.r50),
                ),
              ),
          ],
        ),
      ),
      persistentFooterButtons: [
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              onPressed: !userProfileProvider.loading && canContinue()
                  ? () async {
                      await userProfileProvider
                          .runnerRegistrationAndErrorHandler(
                        context: context,
                        onError: (errorMessage) {
                          showSnackbar(
                              context, errorMessage ?? "Something went wrong");
                        },
                      );
                    }
                  : null,
              child: userProfileProvider.loading
                  ? const CupertinoActivityIndicator()
                  : Text(
                      languageProvider.getMessage(
                        'start_registration',
                        'Start Registration',
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    registrationCodeTextController.dispose();
    onboardingAgentCodeTextController.dispose();
    super.dispose();
  }
}
