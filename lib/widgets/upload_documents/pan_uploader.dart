import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/documents_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/registration_details_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';
import 'package:snabbit_runner/utils/mixins/upload_document_mixin.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/upload_documents/image_uploader.dart';

import '../../services/globals.dart';

class PanUploader extends StatefulWidget {
  const PanUploader({super.key, this.disableTDSWarning = false});

  final bool disableTDSWarning;

  @override
  State<PanUploader> createState() => _PanUploaderState();
}

class _PanUploaderState extends State<PanUploader> with UploadDocumentsMixin {
  final TextEditingController panController = TextEditingController();

  dynamic errorPan;
  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late DocumentsProvider documentsProvider;
  bool init = true;
  late LanguageProvider languageProvider;
  dynamic docPanUploadErr;

  Document? panDocument;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;

      // panDocument = userProfileProvider.getPanDocument();

      if (panDocument?.number != null) {
        panController.text = panDocument?.number.toString() ?? '';
      }

      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      documentsProvider = Provider.of<DocumentsProvider>(context, listen: true);

      setState(() {});
    }
    super.didChangeDependencies();
  }

  // Future<void> verifyPan() async {
  //   setState(() {
  //     loadingPan = true;
  //     errorPan = null;
  //   });
  //
  //   final response = await RegistrationDetailsHttp.verifyPanNumber(data: {
  //     "pan_number": panController.text,
  //     "runner_id": userProfile.id,
  //   });
  //
  //   if (response?.statusCode == 200) {
  //     setState(() {
  //       loadingPan = false;
  //       errorPan = null;
  //       docPanUploadErr = null;
  //     });
  //
  //     userProfileProvider.updateDocumentVerification(
  //       true,
  //       panDocument,
  //     );
  //   } else {
  //     setState(() {
  //       loadingPan = false;
  //       errorPan = response?.data['detail'];
  //     });
  //     userProfileProvider.updateDocumentVerification(
  //       false,
  //       panDocument,
  //     );
  //   }
  // }

  Future<XFile?> pickPanImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    documentsProvider.panImage = pickedFile?.path;
    return pickedFile;
  }

  Widget? getSuffix() {
    return panDocument?.verified == true ? getVerifiedIndicator() : null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (GlobalState().appConfig?.isPanEditable == true)
            OnboardingQuestion(
              questionKey: 'pan_card_number',
              questionDefault: 'PAN card number',
              error: userProfileProvider.user?.panCardUnavailable == true
                  ? null
                  : errorPan,
              answer: TextFormField(
                controller: panController,
                enabled: userProfileProvider.user?.panCardUnavailable == false,
                maxLength: 10,
                onChanged: (v) {
                  setState(() {
                    panController.text = v.toUpperCase();
                  });

                  if (v.length == 10) {
                    // userProfile.documents.add(Document(
                    //   type: 'PAN',
                    //   number: panController.text,
                    // ));
                    panDocument?.number = panController.text;

                    userProfileProvider.notifyUserListeners();

                    // setState(() {
                    //   loadingPan = true;
                    // });
                    // verifyPan();
                  } else if (v.length != 10) {
                    setState(() {
                      errorPan = null;
                    });
                    // userProfileProvider.panVerified = false;
                    userProfileProvider.updateDocumentVerification(
                      false,
                      panDocument,
                    );
                  }
                },
                decoration: InputDecoration(
                    suffix: getSuffix(),
                    border: const OutlineInputBorder(),
                    hintText: languageProvider.getMessage(
                      'pan_number_hint',
                      'Enter your PAN Card number',
                    ),
                    hintStyle: AppTextTheme.hintStyle,
                    counter: const SizedBox()),
              ),
            ),
          if (!widget.disableTDSWarning)
            Padding(
              padding: EdgeInsets.only(
                left: 16.w,
                top: 4.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final noPanCard =
                              userProfileProvider.user?.panCardUnavailable;

                          userProfileProvider.panCardUnavailable =
                              noPanCard == false;
                        },
                        child: CircularCheckbox(
                          value: userProfileProvider.user?.panCardUnavailable ==
                              true,
                          squircle: true,
                          circularCheckboxPadding: 3,
                          borderColor:
                              userProfileProvider.user?.panCardUnavailable ==
                                      true
                                  ? AppColors.brand
                                  : AppColors.n40,
                          bgColor:
                              userProfileProvider.user?.panCardUnavailable ==
                                      true
                                  ? AppColors.brand
                                  : Colors.transparent,
                        ),
                      ),
                      SizedBox(
                        width: 8.w,
                      ),
                      Text(
                          languageProvider.getMessage(
                            "no_pan_declaration",
                            "I don’t have Pan card right now",
                          ),
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  if (userProfileProvider.user?.panCardUnavailable == true)
                    Padding(
                      padding: EdgeInsets.only(
                        left: 2.w,
                        top: 4.h,
                      ),
                      child: Text(
                        languageProvider.getMessage(
                          "tds_warning",
                          "20% TDS will be applicable on your earnings",
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.r40,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    )
                ],
              ),
            ),
          Gap.gap16h,
          OnboardingQuestion(
            questionKey: 'pan_card',
            questionDefault: 'PAN card',
            answer: SizedBox(
              width: 242.w,
              child: GestureDetector(
                onTap: userProfileProvider.user?.panCardUnavailable == true
                    ? null
                    : () async {
                        await pickPanImage(ImageSource.gallery);
                      },
                child: ImageUploader(
                  localImage: documentsProvider.panImage,
                  storedImage: panDocument?.presignedUrl,
                  label: languageProvider.getMessage(
                    'pic_upload',
                    "Upload a pic",
                  ),
                  onDelete: () {
                    if (panDocument?.presignedUrl != null) {
                      userProfileProvider.updatePresignedUrl(null, panDocument);
                    } else {
                      documentsProvider.panImage = null;
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
