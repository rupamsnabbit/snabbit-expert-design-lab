import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/documents_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/server_requests/registration_details_http.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';
import 'package:snabbit_runner/utils/mixins/upload_document_mixin.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/upload_documents/image_uploader.dart';

//TODO: CLEAN AND OPTIMIZE
class AadharUploader extends StatefulWidget {
  const AadharUploader({super.key});

  @override
  State<AadharUploader> createState() => _AadharUploaderState();
}

class _AadharUploaderState extends State<AadharUploader>
    with UploadDocumentsMixin {
  final TextEditingController aadhaarController = TextEditingController();

  dynamic errorAadhaar;
  String? accessToken;
  dynamic docAadhaarUploadErr;
  bool loadingAadhaarDoc = false;
  bool uploadDocAadhaarSuccess = false;

  // bool loadingAadhaar = false;

  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late DocumentsProvider documentsProvider;
  bool init = true;
  late LanguageProvider languageProvider;
  Document? aadhaarFrontDocument;
  Document? aadhaarBackDocument;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;
      documentsProvider = Provider.of<DocumentsProvider>(context, listen: true);

      aadhaarFrontDocument = userProfileProvider.getAadharFrontDocument();
      aadhaarBackDocument = userProfileProvider.getAadharBackDocument();
      aadhaarController.text =
          aadhaarFrontDocument?.number ?? aadhaarBackDocument?.number ?? '';

      languageProvider = Provider.of<LanguageProvider>(context, listen: true);

      setState(() {});
    }
    super.didChangeDependencies();
  }

  Future<XFile?> pickAadhaarImage(ImageSource source, bool isFront) async {
    final pickedFile = await picker.pickImage(source: source);

    if (isFront) {
      documentsProvider.aadhaarFrontImage = pickedFile?.path;
    } else {
      documentsProvider.aadhaarBackImage = pickedFile?.path;
    }

    return pickedFile;
  }

  // Future<void> verifyAadhaar() async {
  //   setState(() {
  //     loadingAadhaar = true;
  //     errorAadhaar = null;
  //   });
  //
  //   final response = await RegistrationDetailsHttp.verifyAadhaarNumber(
  //       aadhaarController.text);
  //
  //   if (response?.statusCode == 200) {
  //     setState(() {
  //       loadingAadhaar = false;
  //       errorAadhaar = null;
  //       docAadhaarUploadErr = null;
  //     });
  //     userProfileProvider.updateDocumentVerification(
  //       true,
  //       aadhaarFrontDocument,
  //     );
  //   } else {
  //     setState(() {
  //       errorAadhaar = response?.data['detail'];
  //       loadingAadhaar = false;
  //     });
  //     userProfileProvider.updateDocumentVerification(
  //       false,
  //       aadhaarFrontDocument,
  //     );
  //   }
  // }

  Widget? getSuffix() {
    return aadhaarFrontDocument?.verified == true
            ? getVerifiedIndicator()
            : null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (GlobalState().appConfig?.isAadharEditable == true)
          OnboardingQuestion(
            mandatory: true,
            questionKey: 'aadhaar_card_number',
            questionDefault: 'Aadhaar card number',
            error: errorAadhaar,
            answer: TextFormField(
              controller: aadhaarController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              onChanged: (v) {
                if (v.length == 12) {
                  // userProfile.documents.add(Document(
                  //   type: DocumentStrings.aadhaar,
                  //   number: aadhaarController.text,
                  // ));
                  aadhaarFrontDocument?.number = aadhaarController.text;
                  aadhaarBackDocument?.number = aadhaarController.text;

                  userProfileProvider.notifyUserListeners();

                  // setState(() {
                  //   loadingAadhaar = true;
                  // });
                  // verifyAadhaar();
                } else if (v.length != 12) {
                  setState(() {
                    errorAadhaar = null;
                  });

                  userProfileProvider.updateDocumentVerification(
                    false,
                    aadhaarFrontDocument,
                  );
                }
              },
              decoration: InputDecoration(
                  suffix: getSuffix(),
                  border: const OutlineInputBorder(),
                  hintText: languageProvider.getMessage(
                    'aadhaar_number_hint',
                    'Enter your Aadhaar Card number',
                  ),
                  hintStyle: AppTextTheme.hintStyle,
                  counter: const SizedBox()),
            ),
          ),
        Gap.gap16h,
        OnboardingQuestion(
          mandatory: true,
          questionKey: 'aadhaar_card',
          questionDefault: 'Aadhaar card',
          answer: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await pickAadhaarImage(ImageSource.gallery, true);
                  },
                  child: ImageUploader(
                    localImage: documentsProvider.aadhaarFrontImage,
                    storedImage: aadhaarFrontDocument?.presignedUrl,
                    label: languageProvider.getMessage(
                      'aadhaar_front_upload',
                      "Upload a pic of the front",
                    ),
                    onDelete: () {
                      if (aadhaarFrontDocument?.presignedUrl != null) {
                        userProfileProvider.updatePresignedUrl(
                            null, aadhaarFrontDocument);
                      } else {
                        documentsProvider.aadhaarFrontImage = null;
                      }
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
                  child: ImageUploader(
                    localImage: documentsProvider.aadhaarBackImage,
                    storedImage: aadhaarBackDocument?.presignedUrl,
                    label: languageProvider.getMessage(
                      'aadhaar_back_upload',
                      "Upload a pic of the back",
                    ),
                    onDelete: () {
                      if (aadhaarBackDocument?.presignedUrl != null) {
                        userProfileProvider.updatePresignedUrl(
                            null, aadhaarBackDocument);
                      } else {
                        documentsProvider.aadhaarBackImage = null;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
