import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/pages/signup/pan_number_updater.dart';
import 'package:snabbit_runner/providers/documents_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/upload_documents/aadhaar_photo_uploader.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_callout.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_status_view.dart';
import '../../services/globals.dart';
import '../../utils/colors.dart';

class UploadAadhaarPhotos extends StatefulWidget {
  static const String routeName = "/upload_aadhaar_photos";

  const UploadAadhaarPhotos({super.key});

  @override
  State<UploadAadhaarPhotos> createState() => _UploadAadhaarPhotosState();
}

class _UploadAadhaarPhotosState extends State<UploadAadhaarPhotos> {
  dynamic error;
  bool loadingButton = false;

  late UserProfileProvider userProfileProvider;
  late DocumentsProvider documentsProvider;
  bool init = true;

  final _formKey = GlobalKey<FormState>();

  late LanguageProvider languageProvider;
  Document? aadhaarFrontDocument;
  Document? aadhaarBackDocument;
  late OnboardingStepsProvider onboardingStepsProvider;
  OnboardingStatusData? _onboardingStatusData;
  UploadAadhaarPhotosUiConfig? uiConfigData;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      documentsProvider = Provider.of<DocumentsProvider>(context, listen: true);
      aadhaarFrontDocument = userProfileProvider.getAadharFrontDocument();
      aadhaarBackDocument = userProfileProvider.getAadharBackDocument();
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      try {
        if (onboardingQuestionGroupUiConfig?.rawJson != null) {
          uiConfigData = UploadAadhaarPhotosUiConfig.fromJson(
              onboardingQuestionGroupUiConfig!.rawJson!);
        }
      } catch (_) {}
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

  String? get frontImageUrl {
    final questions = onboardingQuestionResponse?.questions ?? [];
    if (questions.isEmpty) return aadhaarFrontDocument?.presignedUrl;

    // First question is front image
    final frontResponse = questions[0].previousResponse?.first;
    return frontResponse?.freeTextAnswer ?? aadhaarFrontDocument?.presignedUrl;
  }

  String? get backImageUrl {
    final questions = onboardingQuestionResponse?.questions ?? [];
    if (questions.length < 2) return aadhaarBackDocument?.presignedUrl;

    // Second question is back image
    final backResponse = questions[1].previousResponse?.first;
    return backResponse?.freeTextAnswer ?? aadhaarBackDocument?.presignedUrl;
  }

  @override
  Widget build(BuildContext context) {
    return loadingButton
        ? Scaffold(
            body: SizedBox(
              height: 1.sh,
              width: 1.sw,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CupertinoActivityIndicator(),
                  SizedBox(height: 20.h),
                  Text(
                    uiConfigData?.aadhaarLoadingTimeMessage ??
                        "This may take up to 20 seconds",
                    style: Theme.of(context).textTheme.bodyLarge,
                  )
                ],
              ),
            ),
          )
        : Scaffold(
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
            persistentFooterButtons: [
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          onboardingQuestionGroupUiConfig?.ctaColor ??
                              AppColors.brand),
                  onPressed: canContinue() && !loadingButton
                      ? () {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) {
                              return CommonBottomSheetSetup(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(height: 20.h),
                                    Image.asset(
                                      AssetConstants.fpWarningPng,
                                      height: 45.h,
                                    ),
                                    SizedBox(height: 20.h),
                                    Text(
                                      uiConfigData?.doYouWantToUpload ??
                                          'Do you want to upload?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge,
                                    ),
                                    SizedBox(height: 10.h),
                                    Text(
                                      uiConfigData
                                              ?.noChangesCanBeMadeAfterSubmitting ??
                                          'No changes can be made after submitting.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    SizedBox(height: 20.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.n30,
                                              foregroundColor: AppColors.r50,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child:
                                                Text(uiConfigData?.no ?? 'No'),
                                          ),
                                        ),
                                        SizedBox(width: 16.w),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              onContinue();
                                              Navigator.pop(context);
                                            },
                                            child: Text(
                                                uiConfigData?.yes ?? 'Yes'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20.h),
                                  ],
                                ),
                              );
                            },
                          );
                        }
                      : null,
                  child: loadingButton
                      ? const CupertinoActivityIndicator()
                      : Text(
                          onboardingQuestionGroupUiConfig?.ctaText ??
                              languageProvider.getMessage(
                                'continue',
                                "Continue",
                              ),
                        ),
                ),
              ),
            ],
            body: onboardingStepsProvider.loading
                ? Center(child: CupertinoActivityIndicator())
                : _onboardingStatusData != null
                    ? OnboardingStatusView(
                        onboardingStatusData: _onboardingStatusData)
                    : SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 6.h),
                                OnboardingProgressBar(
                                    progressValue: _progressValue),
                                SizedBox(height: 33.h),
                                const AadhaarPhotoUploader(),
                                SizedBox(
                                  height: 32.h,
                                ),
                                SampleDocument(
                                  imageUrl: uiConfigData?.sampleDocumentImage ??
                                      "onboarding/aadhar_sample_image".cdn,
                                  fallbackImage: uiConfigData
                                          ?.sampleDocumentFallbackImage ??
                                      AssetConstants.sampleAadhaarPhoto,
                                  howToTakeAGoodPhotoSteps:
                                      uiConfigData?.howToTakeAGoodPhotoSteps,
                                ),
                                SizedBox(height: 16.h),
                                Column(
                                  children: [
                                    ...?(uiConfigData?.navActions?.actions
                                        .map((action) {
                                      return ActionableText(
                                        statement: action.label ?? "",
                                        actionable: action.taskLabel ?? "",
                                        action: () {
                                          if (action.task == null) return;
                                          final sessionId =
                                              onboardingQuestionResponse
                                                  ?.sessionId;
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
                                if (uiConfigData?.callOutData != null) ...[
                                  OnboardingCallout(
                                    callOut: uiConfigData?.callOutData,
                                  ),
                                  SizedBox(height: 28.h),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
          );
  }

  void onContinue() async {
    if (sessionId == null) return;

    final questions = onboardingQuestionResponse?.questions ?? [];
    if (questions.length < 2) {
      showSnackbar(context, "Invalid question data");
      return;
    }

    setState(() {
      loadingButton = true;
    });

    try {
      final formData = FormData.fromMap({
        'session_id': sessionId,
        'front_question_id': questions[0].id,
        'back_question_id': questions[1].id,
        if (documentsProvider.aadhaarFrontImage != null)
          'front_image': await MultipartFile.fromFile(
            documentsProvider.aadhaarFrontImage!,
            filename: 'aadhaar_front.jpg',
          )
        else if (frontImageUrl != null)
          'front_image_url': frontImageUrl!,
        if (documentsProvider.aadhaarBackImage != null)
          'back_image': await MultipartFile.fromFile(
            documentsProvider.aadhaarBackImage!,
            filename: 'aadhaar_back.jpg',
          )
        else if (backImageUrl != null)
          'back_image_url': backImageUrl!,
      });

      await onboardingStepsProvider.uploadAadhaar(
        context: context,
        data: formData,
        onSuccess: () {
          //todo: handle success
        },
        onError: (error) {
          try {
            _onboardingStatusData = OnboardingStatusData.fromJson(error.data);
            setState(() {});
          } catch (_) {
            if (mounted) {
              showSnackbar(
                context,
                error.title ?? "Something went wrong",
                durationInSeconds: 12,
              );
            }
          }
        },
      );
    } catch (e) {
      // Handle any potential errors that might occur
      if (mounted) {
        showSnackbar(
          context,
          uiConfigData?.documentUploadFailed ??
              "Document upload failed. Try again!",
        );
      }
    } finally {
      setState(() {
        loadingButton = false;
      });
    }
  }

  bool canContinue() {
    try {
      bool hasFrontImage =
          documentsProvider.aadhaarFrontImage != null || frontImageUrl != null;
      bool hasBackImage =
          documentsProvider.aadhaarBackImage != null || backImageUrl != null;
      bool aadhaarCondition =
          GlobalState().appConfig?.isAadharEditable == false ||
              aadhaarFrontDocument == null ||
              (aadhaarFrontDocument?.number ?? "").length == 12;

      return hasFrontImage && hasBackImage && aadhaarCondition;
    } catch (e) {
      return false;
    }
  }
}

class SampleDocument extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackImage;
  final String? howToTakeAGoodPhoto;
  final List<String>? howToTakeAGoodPhotoSteps;

  const SampleDocument({
    super.key,
    this.imageUrl,
    this.fallbackImage,
    this.howToTakeAGoodPhoto,
    this.howToTakeAGoodPhotoSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                howToTakeAGoodPhoto ?? 'How to take a good photo',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              SizedBox(width: 2.w),
              Tooltip(
                padding: EdgeInsets.zero,
                richMessage: WidgetSpan(
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...(howToTakeAGoodPhotoSteps ?? []).map(
                          (e) => Padding(
                            padding: EdgeInsets.only(bottom: 5.h),
                            child: Text(
                              e,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      fontSize: 12.sp, color: AppColors.n0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                decoration: const BoxDecoration(
                  color: Color(0xff6D7783),
                ),
                showDuration: Duration(seconds: 20),
                triggerMode: howToTakeAGoodPhotoSteps != null
                    ? TooltipTriggerMode.tap
                    : TooltipTriggerMode.manual,
                child: Icon(
                  Icons.help_outline_rounded,
                  color: howToTakeAGoodPhotoSteps != null
                      ? null
                      : AppColors.n50, // Make it appear disabled
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          RemoteImageHandler(
            imageUrl: imageUrl ?? '',
            height: 101.h,
            errorWidget: Image.asset(
              fallbackImage ?? '',
              height: 101.h,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }
}

class UploadAadhaarPhotosUiConfig {
  final String? sampleDocumentImage;
  final String? sampleDocumentFallbackImage;
  final String? howToTakeAGoodPhoto;
  final List<String>? howToTakeAGoodPhotoSteps;
  final String? doYouWantToUpload;
  final String? noChangesCanBeMadeAfterSubmitting;
  final String? yes;
  final String? no;
  final String? dontHaveAadhaarCard;
  final String? tryWithVoterId;
  final String? documentUploadFailed;
  final String? aadhaarPhotoUploadLoadingMessage;
  final String? aadhaarLoadingTimeMessage;
  final CallOutData? callOutData;
  final String? title;
  final String? description;
  final NavActions? navActions;

  const UploadAadhaarPhotosUiConfig({
    this.sampleDocumentImage,
    this.sampleDocumentFallbackImage,
    this.howToTakeAGoodPhoto,
    this.howToTakeAGoodPhotoSteps,
    this.doYouWantToUpload,
    this.noChangesCanBeMadeAfterSubmitting,
    this.yes,
    this.no,
    this.dontHaveAadhaarCard,
    this.tryWithVoterId,
    this.documentUploadFailed,
    this.aadhaarPhotoUploadLoadingMessage,
    this.aadhaarLoadingTimeMessage,
    this.callOutData,
    this.title,
    this.description,
    this.navActions,
  });

  factory UploadAadhaarPhotosUiConfig.fromJson(Map<String, dynamic> json) {
    return UploadAadhaarPhotosUiConfig(
      sampleDocumentImage: json['sample_document_image'],
      sampleDocumentFallbackImage: json['sample_document_fallback_image'],
      howToTakeAGoodPhoto: json['how_to_take_a_good_photo'],
      howToTakeAGoodPhotoSteps: json['how_to_take_a_good_photo_steps'],
      doYouWantToUpload: json['do_you_want_to_upload'],
      noChangesCanBeMadeAfterSubmitting:
          json['no_changes_can_be_made_after_submitting'],
      yes: json['yes'],
      no: json['no'],
      dontHaveAadhaarCard: json['dont_have_aadhaar_card'],
      tryWithVoterId: json['try_with_voter_id'],
      documentUploadFailed: json['document_upload_failed'],
      aadhaarPhotoUploadLoadingMessage:
          json['aadhaar_photo_upload_loading_message'],
      aadhaarLoadingTimeMessage: json['aadhaar_loading_time_message'],
      callOutData: json['callout'] != null
          ? CallOutData.fromJson(json['callout'])
          : null,
      title: json['title'],
      description: json['description'],
      navActions: json['nav_actions'] != null
          ? NavActions.fromJson(json['nav_actions'])
          : null,
    );
  }
}
