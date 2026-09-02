import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/documents_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import 'package:snabbit_runner/widgets/upload_documents/pan_uploader.dart';
import '../../constants/assets_constants.dart';
import '../../utils/colors.dart';
import '../../widgets/common_bottomsheet_setup.dart';
import 'upload_documents.dart';

class UploadDocumentsPan extends StatefulWidget {
  static const String routeName = "/upload_documents_pan";

  const UploadDocumentsPan({super.key});

  @override
  State<UploadDocumentsPan> createState() => _UploadDocumentsPanState();
}

class _UploadDocumentsPanState extends State<UploadDocumentsPan> {
  dynamic error;
  bool loadingButton = false;

  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late DocumentsProvider documentsProvider;
  bool init = true;

  final _formKey = GlobalKey<FormState>();

  late LanguageProvider languageProvider;

  Document? panDocument;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;

      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      documentsProvider = Provider.of<DocumentsProvider>(context, listen: true);
      // panDocument = userProfileProvider.getPanDocument();

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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: canContinue() && !loadingButton
                ? () {
                    if (userProfileProvider.user?.panCardUnavailable == true) {
                      onContinue();
                    } else {
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
                                  'Confirm upload?',
                                  style:
                                      Theme.of(context).textTheme.headlineLarge,
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  'No changes can be made after uploading.',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
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
                                        onPressed: () => Navigator.pop(context),
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
                  titleDefault: 'Identity Documents Upload',
                  subtitleKey: 'id_docs_subtitle',
                  subtitleDefault: 'Please share your ID information',
                ),
                Gap.gap32h,
                const PanUploader(),
                Gap.gap32h,
                const SampleDocument(image: 'assets/pngs/pan_sample.png'),
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
        panImage: documentsProvider.panImage,
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
        showSnackbar(context,
            "Document upload failed. Try again!"); // Or provide a more user-friendly error message
      }
    } finally {
      setState(() {
        loadingButton = false;
      });
    }
  }

  bool canContinue() {
    return userProfileProvider.user?.panCardUnavailable == true ||
        ((userProfileProvider.user?.panCardUnavailable ?? false) == false &&
            (documentsProvider.panImage != null ||
                panDocument?.presignedUrl != null) &&
            (GlobalState().appConfig?.isPanEditable == false ||
                (panDocument?.number ?? "").length == 10));
  }
}
