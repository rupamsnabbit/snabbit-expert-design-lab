import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';
import 'package:snabbit_runner/utils/mixins/upload_document_mixin.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_callout.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_status_view.dart';
import 'package:url_launcher/url_launcher.dart';

class PanNumberUpdater extends StatefulWidget {
  static const String routeName = "/pan-number-updater";

  const PanNumberUpdater({super.key, this.disableTDSWarning = false});

  final bool disableTDSWarning;

  @override
  State<PanNumberUpdater> createState() => _PanNumberUpdaterState();
}

class _PanNumberUpdaterState extends State<PanNumberUpdater>
    with UploadDocumentsMixin {
  final TextEditingController panController = TextEditingController();

  dynamic errorPan;
  late UserProfileProvider userProfileProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  bool init = true;

  bool _isValidPanCard(String pan) {
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return panRegex.hasMatch(pan);
  }

  // bool loadingPan = false;
  late LanguageProvider languageProvider;
  dynamic docPanUploadErr;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      panController.text =
          currentQuestion?.previousResponse?.first.freeTextAnswer ?? '';

      languageProvider = Provider.of<LanguageProvider>(context, listen: true);

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

  OnboardingStatusData? _onboardingStatusData;

  @override
  Widget build(BuildContext context) {
    PanDetailsUiConfig? uiConfigData;
    try {
      uiConfigData =
          PanDetailsUiConfig.fromJson(currentQuestion?.uiConfig ?? {});
    } catch (_) {}

    NavActions? navActions = uiConfigData?.navActions;
    if (navActions == null) {
      try {
        final meta = onboardingQuestionGroupUiConfig?.meta;
        if (meta != null && meta['nav_actions'] != null) {
          navActions = NavActions.fromJson(meta['nav_actions']);
        }
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
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
                        backgroundColor:
                            uiConfigData?.panCtaBgColor ?? AppColors.brand),
                    onPressed: !_isValidPanCard(panController.text)
                        ? null
                        : () {
                            if (sessionId == null || currentQuestion == null)
                              return;
                            final payload = {
                              "session_id": sessionId,
                              "question_id": currentQuestion?.id,
                              "pan_number": panController.text,
                            };

                            onboardingStepsProvider.verifyPan(
                              context: context,
                              data: payload,
                              onSuccess: () {},
                              onError: (error) {
                                try {
                                  _onboardingStatusData =
                                      OnboardingStatusData.fromJson(error.data);
                                  setState(() {});
                                } catch (_) {
                                  showSnackbar(
                                      context,
                                      error.message ??
                                          error.title ??
                                          'Something went wrong');
                                }
                              },
                            );
                          },
                    child: Text(
                      uiConfigData?.panCtaText ?? "Continue",
                    ),
                  ),
                ),
              ),
            ],
      body: onboardingStepsProvider.loading
          ? const Center(child: CupertinoActivityIndicator())
          : _onboardingStatusData != null
              ? OnboardingStatusView(
                  onboardingStatusData: _onboardingStatusData)
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    // padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 6.h),
                        OnboardingProgressBar(progressValue: _progressValue),
                        SizedBox(height: 33.h),
                        OnboardingPageHeaderV2(
                          title: onboardingQuestionGroupUiConfig?.title ??
                              "Input PAN Details",
                          description: onboardingQuestionGroupUiConfig
                                  ?.description ??
                              "We need to verify your PAN Card details to proceed",
                          titleStyle:
                              Theme.of(context).textTheme.headlineMedium,
                          subtitleStyle: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: AppColors.n70),
                          // padding: EdgeInsets.zero,
                        ),
                        SizedBox(height: 28.h),
                        OnboardingQuestion(
                          questionKey:
                              currentQuestion?.question ?? 'pan_card_number',
                          questionDefault:
                              currentQuestion?.question ?? 'PAN card number',
                          mandatory: true,
                          error: userProfileProvider.user?.panCardUnavailable ==
                                  true
                              ? null
                              : errorPan,
                          answer: TextFormField(
                            controller: panController,
                            // enabled:
                            //     userProfileProvider.user?.panCardUnavailable ==
                            //         false,
                            maxLength: 10,
                            onChanged: (v) {
                              setState(() {
                                panController.text = v.toUpperCase();
                              });
                            },
                            decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                hintText: uiConfigData?.panCardInputHint ??
                                    languageProvider.getMessage(
                                      'pan_number_hint',
                                      'Enter your PAN Card number',
                                    ),
                                hintStyle: AppTextTheme.hintStyle,
                                counter: const SizedBox()),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        OnboardingCallout(callOut: uiConfigData?.callOutData),
                        SizedBox(height: 12.h),
                        ActionableText(
                          statement: uiConfigData?.panCardCreateNowStatement ??
                              "Don't have a PAN ? ",
                          actionable:
                              uiConfigData?.panCardCreateNowActionable ??
                                  "Create now ",
                          action: uiConfigData?.panCardCreateNowUrl == null
                              ? null
                              : () async {
                                  userProfileProvider.panCardUnavailable = true;
                                  try {
                                    await launchUrl(Uri.parse(
                                        uiConfigData?.panCardCreateNowUrl ??
                                            ''));
                                  } catch (_) {}
                                },
                        ),
                        if (navActions != null)
                          Column(
                            children: [
                              ...(navActions.actions.map((action) {
                                return ActionableText(
                                  statement: action.label ?? "",
                                  actionable: action.taskLabel ?? "",
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

class PanDetailsUiConfig {
  final String? panCardInputHint;
  final String? panCardRequiredMessage;
  final String? panCardCreateNowStatement;
  final String? panCardCreateNowActionable;
  final String? panCardCreateNowUrl;
  final String? panCardUploadLaterStatement;
  final String? panCardUploadLaterActionable;
  final String? panCtaText;
  final Color? panCtaBgColor;
  final String? loadingMessage;
  final CallOutData? callOutData;
  final NavActions? navActions;

  const PanDetailsUiConfig({
    this.panCardInputHint,
    this.panCardRequiredMessage,
    this.panCardCreateNowStatement,
    this.panCardCreateNowActionable,
    this.panCardCreateNowUrl,
    this.panCardUploadLaterStatement,
    this.panCardUploadLaterActionable,
    this.panCtaText,
    this.panCtaBgColor,
    this.loadingMessage,
    this.callOutData,
    this.navActions,
  });

  factory PanDetailsUiConfig.fromJson(Map<String, dynamic> json) {
    return PanDetailsUiConfig(
      panCardInputHint: json['placeholder'],
      panCardRequiredMessage: json['pan_card_required_message'],
      panCardCreateNowStatement: json['pan_card_create_now_statement'],
      panCardCreateNowActionable: json['pan_card_create_now_actionable'],
      panCardCreateNowUrl: json['pan_card_create_now_url'],
      panCardUploadLaterStatement: json['pan_card_upload_later_statement'],
      panCardUploadLaterActionable: json['pan_card_upload_later_actionable'],
      panCtaText: json['pan_cta_text'],
      panCtaBgColor: json['pan_cta_bg_color'] != null
          ? hexToColor(json['pan_cta_bg_color'])
          : null,
      loadingMessage: json['pan_loading_message'],
      callOutData: json['callout'] != null
          ? CallOutData.fromJson(json['callout'])
          : null,
      navActions: json['nav_actions'] != null
          ? NavActions.fromJson(json['nav_actions'])
          : null,
    );
  }
}
