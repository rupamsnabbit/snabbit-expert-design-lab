import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/signup/bank_details.dart';
import 'package:snabbit_runner/pages/signup/integrity_test.dart';
import 'package:snabbit_runner/providers/documents_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/registration_details_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/runner_registration_step.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import 'package:snabbit_runner/widgets/upload_documents/aadhar_uploader.dart';
import '../../services/globals.dart';
import '../../utils/colors.dart';
import '../../utils/custom_themes/text_themes.dart';

class UploadDocuments extends StatefulWidget {
  static const String routeName = "/upload_documents";

  const UploadDocuments({super.key});

  @override
  State<UploadDocuments> createState() => _UploadDocumentsState();
}

class _UploadDocumentsState extends State<UploadDocuments> {
  dynamic error;
  bool loadingButton = false;

  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late DocumentsProvider documentsProvider;
  bool init = true;

  final _formKey = GlobalKey<FormState>();

  late LanguageProvider languageProvider;
  Document? aadharFrontDocument;
  Document? aadharBackDocument;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;

      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      documentsProvider = Provider.of<DocumentsProvider>(context, listen: true);
      aadharFrontDocument = userProfileProvider.getAadharFrontDocument();
      aadharBackDocument = userProfileProvider.getAadharBackDocument();

      setState(() {});
    }
    super.didChangeDependencies();
  }

  Widget getVerifiedIndicator() {
    return Container(
      height: 14.r,
      width: 14.r,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.g40,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check,
        color: AppColors.n0,
        size: 7.sp,
      ),
    );
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
                  Text("This may take up to 20 seconds", style: Theme.of(context).textTheme.bodyLarge,)
                ],
              ),
            ),
          )
        : Scaffold(
            appBar: const CommonAppBar(),
            persistentFooterButtons: [
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand),
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
                                      'Do you want to upload?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge,
                                    ),
                                    SizedBox(height: 10.h),
                                    Text(
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
                                            child: const Text('No'),
                                          ),
                                        ),
                                        SizedBox(width: 16.w),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              onContinue();
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Yes'),
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
                          languageProvider.getMessage(
                            'continue',
                            "Continue",
                          ),
                        ),
                ),
              ),
            ],
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ProgressIndicatorAtTop(value: 6),
                      Gap.gap32h,
                      const OnboardingPageHeader(
                        titleKey: 'id_docs_title',
                        titleDefault: 'Aadhaar Details',
                        subtitleKey: 'id_docs_subtitle',
                        subtitleDefault: 'We need to verify your Aadhaar Card documents to proceed',
                      ),
                      Gap.gap32h,
                      const AadharUploader(),
                      Gap.gap32h,
                      const SampleDocument(
                          image: 'assets/pngs/aadhar_sample.png'),
                    ],
                  ),
                ),
              ),
            ),
          );
  }

  void onContinue() async {
    setState(() {
      loadingButton = true;
    });
    try {
      await userProfileProvider.submitDocs(
        context: context,
        aadharBackImage: documentsProvider.aadhaarBackImage,
        aadharFrontImage: documentsProvider.aadhaarFrontImage,
        onError: (response) {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              if (mounted) {
                showSnackbar(
                  context,
                  responseError.errors?.first.message ?? "Something went wrong",
                  durationInSeconds: 12,
                );
              }
            },
          );
        },
      );
    } catch (e) {
      // Handle any potential errors that might occur
      // during the execution of onSuccessfulRegistration()
      if (mounted) {
        showSnackbar(
          context,
          "Document upload failed. Try again!",
        ); // Or provide a more user-friendly error message
      }
    } finally {
      setState(() {
        loadingButton = false;
      });
    }
  }

  bool canContinue() {
    try {
      return (documentsProvider.aadhaarFrontImage != null ||
              aadharFrontDocument?.presignedUrl != null) &&
          (documentsProvider.aadhaarBackImage != null ||
              aadharBackDocument?.presignedUrl != null) &&
          (GlobalState().appConfig?.isAadharEditable == false ||
              (aadharFrontDocument?.number ?? "").length == 12);
    } catch (e) {
      return false;
    }
  }
}

class SampleDocument extends StatelessWidget {
  final String image;

  const SampleDocument({
    super.key,
    required this.image,
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
                'How to take a good photo',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 14.sp),
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
                        Text(
                          '• Lay the card on a flat surface',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 12.sp, color: AppColors.n0),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          '• Make sure area is well lit',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 12.sp, color: AppColors.n0),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          '• Position camera above directly',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 12.sp, color: AppColors.n0),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          '• Frame entire card without cutting corners',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 12.sp, color: AppColors.n0),
                        ),
                      ],
                    ),
                  ),
                ),
                decoration: const BoxDecoration(
                  color: Color(0xff6D7783),
                ),
                showDuration: Duration(seconds: 20),
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(Icons.help_outline_rounded),
              )
            ],
          ),
          SizedBox(height: 10.h),
          Image.asset(
            image,
            height: 88.h,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}
