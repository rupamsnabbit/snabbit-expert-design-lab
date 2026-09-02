import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/providers/documents_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/mixins/upload_document_mixin.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/utils/colors.dart';

class AadhaarPhotoUploader extends StatefulWidget {
  const AadhaarPhotoUploader({super.key});

  @override
  State<AadhaarPhotoUploader> createState() => _AadhaarPhotoUploaderState();
}

class _AadhaarPhotoUploaderState extends State<AadhaarPhotoUploader>
    with UploadDocumentsMixin {
  dynamic errorAadhaar;
  String? accessToken;
  dynamic docAadhaarUploadErr;
  bool loadingAadhaarDoc = false;
  bool uploadDocAadhaarSuccess = false;

  late UserProfileProvider userProfileProvider;
  late DocumentsProvider documentsProvider;
  bool init = true;
  late LanguageProvider languageProvider;
  Document? aadhaarFrontDocument;
  Document? aadhaarBackDocument;
  late OnboardingStepsProvider onboardingStepsProvider;

  bool _frontImageDeleted = false;
  bool _backImageDeleted = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      documentsProvider = Provider.of<DocumentsProvider>(context, listen: true);

      aadhaarFrontDocument = userProfileProvider.getAadharFrontDocument();
      aadhaarBackDocument = userProfileProvider.getAadharBackDocument();
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);

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

  String? get frontImageUrl {
    if (_frontImageDeleted) return null;

    final questions = onboardingQuestionResponse?.questions ?? [];
    if (questions.isEmpty) return aadhaarFrontDocument?.presignedUrl;

    // First question is front image
    final frontResponse = questions[0].previousResponse?.first;
    return frontResponse?.freeTextAnswer ?? aadhaarFrontDocument?.presignedUrl;
  }

  String? get backImageUrl {
    if (_backImageDeleted) return null;

    final questions = onboardingQuestionResponse?.questions ?? [];
    if (questions.length < 2) return aadhaarBackDocument?.presignedUrl;

    // Second question is back image
    final backResponse = questions[1].previousResponse?.first;
    return backResponse?.freeTextAnswer ?? aadhaarBackDocument?.presignedUrl;
  }

  Future<XFile?> pickAadhaarImage(ImageSource source, bool isFront) async {
    final pickedFile = await picker.pickImage(source: source);

    if (isFront) {
      documentsProvider.aadhaarFrontImage = pickedFile?.path;
      _frontImageDeleted = false; // Reset deleted flag when new image is picked
    } else {
      documentsProvider.aadhaarBackImage = pickedFile?.path;
      _backImageDeleted = false; // Reset deleted flag when new image is picked
    }

    setState(() {});
    return pickedFile;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    AadhaarPhotoUploaderUiConfig? uiConfigData;
    try {
      uiConfigData = AadhaarPhotoUploaderUiConfig.fromJson(
          currentQuestion?.uiConfig ?? {});
    } catch (_) {}

    return OnboardingQuestion(
      questionKey: currentQuestion?.question ?? 'upload_aadhaar_card_photos',
      questionDefault:
          currentQuestion?.question ?? 'Upload Aadhaar card photos',
      questionTextStyle: textTheme.headlineMedium,
      qaGap: 20.h,
      answer: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await pickAadhaarImage(ImageSource.gallery, true);
              },
              child: AadhaarImageUploader(
                localImage: documentsProvider.aadhaarFrontImage,
                storedImage: frontImageUrl,
                iconUrl: uiConfigData?.aadhaarFrontUploadIcon ??
                    "onboarding/upload_aadhar_icon.svg".cdn,
                label: uiConfigData?.aadhaarFrontUploadLabel ??
                    languageProvider.getMessage(
                      'aadhaar_front_upload',
                      "Upload a pic of the front",
                    ),
                onDelete: () {
                  _frontImageDeleted = true;
                  if (aadhaarFrontDocument?.presignedUrl != null) {
                    userProfileProvider.updatePresignedUrl(
                        null, aadhaarFrontDocument);
                  } else {
                    documentsProvider.aadhaarFrontImage = null;
                  }
                  setState(() {});
                },
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await pickAadhaarImage(ImageSource.gallery, false);
              },
              child: AadhaarImageUploader(
                localImage: documentsProvider.aadhaarBackImage,
                storedImage: backImageUrl,
                iconUrl: uiConfigData?.aadhaarBackUploadIcon ??
                    "onboarding/upload_aadhar_icon.svg".cdn,
                label: uiConfigData?.aadhaarBackUploadLabel ??
                    languageProvider.getMessage(
                      'aadhaar_back_upload',
                      "Upload a pic of the back",
                    ),
                onDelete: () {
                  _backImageDeleted = true;
                  if (aadhaarBackDocument?.presignedUrl != null) {
                    userProfileProvider.updatePresignedUrl(
                        null, aadhaarBackDocument);
                  } else {
                    documentsProvider.aadhaarBackImage = null;
                  }
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AadhaarImageUploader extends StatelessWidget {
  const AadhaarImageUploader({
    super.key,
    this.localImage,
    this.storedImage,
    this.label,
    this.onDelete,
    this.iconUrl,
  });

  final String? localImage;
  final String? storedImage;
  final String? label;
  final VoidCallback? onDelete;
  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 113.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.brand)),
      child: storedImage == null && localImage == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RemoteImageHandler(
                  imageUrl: iconUrl?.cdn ?? '',
                  height: 40.h,
                  errorWidget: Image.asset(
                    AssetConstants.uploadPic,
                    height: 40.h,
                  ),
                ),
                SizedBox(height: 4.h),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      label ?? "Upload a pic",
                      textAlign: TextAlign.center,
                      // overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.n70,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              height: 80.h,
              width: 120.w,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(12.r),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: localImage != null
                            ? Image.file(
                                File(localImage!),
                                fit: BoxFit.cover,
                              )
                            : storedImage != null
                                ? Image.network(
                                    storedImage!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: getLoadingBuilder,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Text(
                                      "Image not found",
                                      textAlign: TextAlign.center,
                                    )),
                                  )
                                : null,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: SvgPicture.asset(
                        AssetConstants.cancelUploadPic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget
  getLoadingBuilder(
      BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress?.cumulativeBytesLoaded ==
        loadingProgress?.expectedTotalBytes) {
      return child; // Image is fully loaded
    }
    return Container(
      height: 80.h,
      width: 120.w,
      decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.n40,
          ),
          borderRadius: BorderRadius.circular(
            8.r,
          )),
      child: const CupertinoActivityIndicator(),
    );
  }
}

class AadhaarPhotoUploaderUiConfig {
  final String? aadhaarFrontUploadLabel;
  final String? aadhaarBackUploadLabel;
  final String? aadhaarFrontUploadIcon;
  final String? aadhaarBackUploadIcon;

  const AadhaarPhotoUploaderUiConfig({
    this.aadhaarFrontUploadLabel,
    this.aadhaarBackUploadLabel,
    this.aadhaarFrontUploadIcon,
    this.aadhaarBackUploadIcon,
  });

  factory AadhaarPhotoUploaderUiConfig.fromJson(Map<String, dynamic> json) {
    return AadhaarPhotoUploaderUiConfig(
      aadhaarFrontUploadLabel: json['aadhaar_front_upload_label'],
      aadhaarBackUploadLabel: json['aadhaar_back_upload_label'],
      aadhaarFrontUploadIcon: json['aadhaar_front_upload_icon'],
      aadhaarBackUploadIcon: json['aadhaar_back_upload_icon'],
    );
  }
}
