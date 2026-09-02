import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/pan_number_updater.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';
import 'package:snabbit_runner/utils/mixins/upload_document_mixin.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_callout.dart';

class VoterIDUpdater extends StatefulWidget {
  static const String routeName = "/voter_id_updater";

  const VoterIDUpdater({super.key});

  @override
  State<VoterIDUpdater> createState() => _VoterIDUpdaterState();
}

class _VoterIDUpdaterState extends State<VoterIDUpdater>
    with UploadDocumentsMixin {
  final TextEditingController voterController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  dynamic errorAadhaar;
  String? accessToken;

  bool init = true;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      voterController.text =
          currentQuestion?.previousResponse?.first.freeTextAnswer ?? '';
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);

      // Validate prefilled value and enable CTA if valid
      final prefilledValue = voterController.text.trim();
      if (prefilledValue.isNotEmpty) {
        final regex = RegExp(r'^[A-Z]{3}[0-9]{7}$');
        enableCta = regex.hasMatch(prefilledValue);
      } else {
        enableCta = false;
      }

      setState(() {});
    }
    super.didChangeDependencies();
  }

  OnboardingQuestionResponse? get onboardingQuestionResponse =>
      onboardingStepsProvider.onboardingQuestionResponse;

  OnboardingQuestionGroup? get onboardingQuestionGroupGroup =>
      onboardingStepsProvider.currentQuestionsData;

  OnboardingQuestionGroupUIConfig? get onboardingQuestionGroupUiConfig =>
      onboardingQuestionGroupGroup?.uiConfig;

  OnboardingQuestionData? get currentQuestion =>
      onboardingQuestionResponse?.questions?.first;

  int? get sessionId => onboardingQuestionResponse?.sessionId;

  int get _currentIndex =>
      onboardingQuestionResponse?.currentQuestionNumber ?? 0;

  int get _totalSteps => onboardingQuestionResponse?.totalQuestions ?? 0;

  double get _progressValue =>
      _totalSteps == 0 ? 0 : _currentIndex / _totalSteps;

  bool enableCta = false;

  @override
  Widget build(BuildContext context) {
    VoterDetailsUiConfig? uiConfigData;
    try {
      uiConfigData =
          VoterDetailsUiConfig.fromJson(currentQuestion?.uiConfig ?? {});
    } catch (_) {}

    // Get navActions from question group UI config only
    NavActions? navActions = onboardingQuestionGroupUiConfig?.navActions;

    return Scaffold(
      appBar: onboardingStepsProvider.loading
          ? null
          : AppBar(
              elevation: 6,
              leading: InkWell(
                onTap: () => onboardingStepsProvider.goBackToPreviousQuestion(
                    context, onboardingQuestionResponse!.moduleId!),
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColors.n80,
                ),
              ),
            ),
      persistentFooterButtons: onboardingStepsProvider.loading
          ? null
          : [
              SizedBox(
                width: 1.sw,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand),
                    onPressed: !enableCta
                        ? null
                        : () {
                            if (sessionId == null || currentQuestion == null)
                              return;
                            final payload = {
                              "session_id": sessionId,
                              "question_id": currentQuestion?.id,
                              "voter_id_number": voterController.text,
                            };
                            onboardingStepsProvider.verifyVoterId(
                              context: context,
                              data: payload,
                              onSuccess: () {},
                              onError: (error) {
                                if (mounted) {
                                  showSnackbar(
                                      context,
                                      error.message ??
                                          error.title ??
                                          'An error occurred');
                                }
                              },
                            );
                          },
                    child: Text(
                      onboardingQuestionGroupUiConfig?.ctaText ?? "Continue",
                    ),
                  ),
                ),
              ),
            ],
      body: onboardingStepsProvider.loading
          ? Center(child: CupertinoActivityIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 6.h),
                      OnboardingProgressBar(progressValue: _progressValue),
                      SizedBox(height: 33.h),
                      OnboardingPageHeaderV2(
                        title: onboardingQuestionGroupUiConfig?.title ??
                            "Input Voter ID",
                        description: onboardingQuestionGroupUiConfig
                                ?.description ??
                            "We need to verify your Voter ID details to proceed",
                        titleStyle: Theme.of(context).textTheme.headlineMedium,
                        subtitleStyle: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppColors.n70),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: 28.h),
                      OnboardingQuestion(
                        questionKey:
                            currentQuestion?.question ?? 'voter_id_question',
                        questionDefault:
                            currentQuestion?.question ?? 'Voter ID number',
                        mandatory: currentQuestion?.mandatory ?? false,
                        padding: EdgeInsets.zero,
                        answer: TextFormField(
                          controller: voterController,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 10,
                          validator: (value) {
                            final regex = RegExp(r'^[A-Z]{3}[0-9]{7}$');
                            if (value == null || value.trim().isEmpty) {
                              return uiConfigData?.voterIdRequiredMessage ??
                                  'Voter ID is required';
                            }
                            if (!regex.hasMatch(value.trim())) {
                              return 'Invalid Voter ID';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            final isValid =
                                _formKey.currentState?.validate() ?? false;
                            setState(() => enableCta = isValid);
                          },
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: uiConfigData?.voterIdInputHint ??
                                "Enter your Voter ID number",
                            hintStyle: AppTextTheme.hintStyle,
                            counter: const SizedBox(),
                            errorStyle: const TextStyle(height: 0, fontSize: 0),
                            errorBorder: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (onboardingQuestionGroupUiConfig?.callOutData !=
                          null) ...[
                        SizedBox(height: 16.h),
                        OnboardingCallout(
                          callOut: onboardingQuestionGroupUiConfig?.callOutData,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                      if (navActions != null)
                        Column(
                          children: [
                            SizedBox(height: 14.h),
                            ...(navActions.actions.map((action) {
                              return ActionableText(
                                statement: action.label ?? "",
                                actionable: action.taskLabel ?? "",
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                action: () {
                                  if (action.task == null) return;

                                  final sessionId =
                                      onboardingQuestionResponse?.sessionId;
                                  if (sessionId == null) return;

                                  final payload = {
                                    "session_id": sessionId,
                                    "action": action.task,
                                  };

                                  onboardingStepsProvider.performAction(
                                    context: context,
                                    data: payload,
                                    navigateOnSuccess: true,
                                  );
                                },
                              );
                            }).toList()),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class VoterDetailsUiConfig {
  final String? voterIdInputHint;
  final String? voterIdRequiredMessage;
  final String? loadingMessage;
  final String? switchBackToAadhaarText;
  final String? iDontHaveAVoterIdText;
  final CallOutData? callOutData;
  final NavActions? navActions;

  const VoterDetailsUiConfig({
    this.voterIdInputHint,
    this.voterIdRequiredMessage,
    this.loadingMessage,
    this.switchBackToAadhaarText,
    this.iDontHaveAVoterIdText,
    this.callOutData,
    this.navActions,
  });

  factory VoterDetailsUiConfig.fromJson(Map<String, dynamic> json) {
    return VoterDetailsUiConfig(
      voterIdInputHint: json['voter_id_input_hint'],
      voterIdRequiredMessage: json['voter_id_required_message'],
      loadingMessage: json['voter_id_loading_message'],
      switchBackToAadhaarText: json['switch_back_to_aadhaar_text'],
      iDontHaveAVoterIdText: json['i_dont_have_a_voter_id_text'],
      callOutData: json['callout'] != null
          ? CallOutData.fromJson(json['callout'])
          : null,
      navActions: json['nav_actions'] != null
          ? NavActions.fromJson(json['nav_actions'])
          : null,
    );
  }
}
