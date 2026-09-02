import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/insurance_profile_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/expert_info_appbar.dart';
import 'package:snabbit_runner/widgets/insurance_support/tier_benefits.dart';
import 'package:snabbit_runner/widgets/pdf_view.dart';

class IdentityCard extends StatefulWidget {
  static const routeName = "identity-card";
  const IdentityCard({super.key});

  @override
  State<IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends State<IdentityCard> {
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late InsuranceProfileProvider insuranceProfileProvider;
  UserProfile? userProfile;
  bool isError = false;
  String? docErrorMsg;
  bool loading = false;
  bool init = true;
  List<Document>? docs;

  Future<void> initProcess() async {
    await populateUserProfile();
    await getAllDocuments();
    insuranceProfileProvider.fetchData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      insuranceProfileProvider = Provider.of<InsuranceProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;
      init = false;
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> populateUserProfile() async {
    try {
      Response? response = await RunnerHttp.runnersMe();
      if (response != null && response.statusCode == 200) {
        userProfile = UserProfile.fromMap(response.data);
      } else {
        isError = true;
      }
    } catch (e) {
      showSnackbar(context, 'Failed to load document: ${e.toString()}');
      Logger().e('Error fetching document: $e');
      isError = true;
    }
  }

  Future<void> getAllDocuments() async {
    try {
      List<String?>? allAvailableDocs = [];
      for (Document t in userProfile?.documents ?? []) {
        allAvailableDocs.add(t.type);
      }
      final response = await RunnerHttp.runnerDocuments(
          runnerId: userProfile?.id,
          queryParameters: {'types': allAvailableDocs});

      if (response?.statusCode == 200 && response?.data != null) {
        docs = response?.data
            .map<Document>((e) => Document.fromMap(e as Map<String, dynamic>))
            .toList();
      } else {
        docErrorMsg = "No documents available";
      }
    } catch (e) {
      Logger().e('Error fetching document: $e');
      docErrorMsg = "Error loading documents";
    }
  }

  @override
  void dispose() {
    insuranceProfileProvider.clearInsuranceProfile();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : isError
              ? const Center(
                  child: Text(
                      'Failed to load Identity Card\n\nIf problem persist, please contact support.'))
              : userProfile == null
                  ? const Center(child: Text('User is not found'))
                  : Column(
                    children: [
                      const ExpertInfoAppbar(),
                      // Expanded(
                      //   child: SingleChildScrollView(
                      //     child: Padding(
                      //         padding:
                      //             EdgeInsets.only(top: 8.h, left: 16.w, right: 16.w),
                      //         child: Column(
                      //           crossAxisAlignment: CrossAxisAlignment.start,
                      //           children: [
                      //             SizedBox(height: 16.h),
                      //             Card(
                      //               color: Colors.white,
                      //               shape: RoundedRectangleBorder(
                      //                 borderRadius: BorderRadius.circular(15),
                      //               ),
                      //               elevation: 4,
                      //               child: Padding(
                      //                 padding: EdgeInsets.all(16.r),
                      //                 child: Column(
                      //                   crossAxisAlignment: CrossAxisAlignment.start,
                      //                   children: [
                      //                     Text(
                      //                       languageProvider.getMessage(
                      //                         'identity_card',
                      //                         'Identity Card',
                      //                       ),
                      //                       style: Theme.of(context)
                      //                           .textTheme
                      //                           .headlineLarge,
                      //                     ),
                      //                     SizedBox(height: 16.h),
                      //                     Container(
                      //                       padding: EdgeInsets.all(16.r),
                      //                       decoration: BoxDecoration(
                      //                         border: Border.all(
                      //                             color: Colors.grey, width: 0.5.w),
                      //                         borderRadius: BorderRadius.circular(15.r),
                      //                       ),
                      //                       child: Column(
                      //                         crossAxisAlignment:
                      //                             CrossAxisAlignment.start,
                      //                         children: [
                      //                           Text(
                      //                               userProfile?.phoneNumber
                      //                                       .toString() ??
                      //                                   '',
                      //                               style: Theme.of(context)
                      //                                   .textTheme
                      //                                   .bodyLarge),
                      //                           Text(
                      //                               '${languageProvider.getMessage('emergency_contact', 'Emergency contact')}: ${userProfile?.alternatePhoneNumber ?? ''}',
                      //                               style: Theme.of(context)
                      //                                   .textTheme
                      //                                   .titleMedium),
                      //                           SizedBox(height: 16.h),
                      //                           Text(
                      //                             userProfileProvider.getCurrentAddress()?.addressLine1
                      //                                     .toString() ??
                      //                                 '',
                      //                             style: Theme.of(context)
                      //                                 .textTheme
                      //                                 .bodyLarge,
                      //                           ),
                      //                           SizedBox(height: 16.h),
                      //                           const Divider(),
                      //                           Text(
                      //                             languageProvider.getMessage(
                      //                               'verification_proof',
                      //                               'Verification Proof',
                      //                             ),
                      //                             style: Theme.of(context)
                      //                                 .textTheme
                      //                                 .headlineSmall,
                      //                           ),
                      //                           SizedBox(height: 8.h),
                      //                           docErrorMsg != null
                      //                               ? Center(
                      //                                   child: Text('$docErrorMsg'),
                      //                                 )
                      //                               : docs == null
                      //                                   ? const Center(
                      //                                       child:
                      //                                           CupertinoActivityIndicator())
                      //                                   : ListView.builder(
                      //                                       shrinkWrap: true,
                      //                                       physics:
                      //                                           const NeverScrollableScrollPhysics(),
                      //                                       itemBuilder:
                      //                                           (context, index) {
                      //                                         return Column(
                      //                                           children: [
                      //                                             Container(
                      //                                                 padding: EdgeInsets
                      //                                                     .symmetric(
                      //                                                         vertical:
                      //                                                             16.h,
                      //                                                         horizontal:
                      //                                                             8.w),
                      //                                                 decoration:
                      //                                                     BoxDecoration(
                      //                                                   border: Border.all(
                      //                                                       color:
                      //                                                           AppColors
                      //                                                               .n40),
                      //                                                   borderRadius:
                      //                                                       BorderRadius
                      //                                                           .circular(
                      //                                                               16.r),
                      //                                                 ),
                      //                                                 child: DocumentItem(
                      //                                                     docs: docs,
                      //                                                     index: index,
                      //                                                     languageProvider:
                      //                                                         languageProvider)),
                      //                                             SizedBox(
                      //                                                 height: 16.h),
                      //                                           ],
                      //                                         );
                      //                                       },
                      //                                       itemCount:
                      //                                           docs?.length ?? 0,
                      //                                     ),
                      //                         ],
                      //                       ),
                      //                     )
                      //                   ],
                      //                 ),
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //       ),
                      //   ),
                      // ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
                          child: TierBenefits(),
                        ),
                      ),
                    ],
                  ),
    );
  }
}

class DocumentItem extends StatelessWidget {
  final LanguageProvider languageProvider;
  final List<Document>? docs;
  final int index;

  const DocumentItem(
      {super.key,
      required this.docs,
      required this.index,
      required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DocumentPrefixIcon(
          docs: docs,
          index: index,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            languageProvider.getMessage(
              docs?[index].type ?? '',
              docs?[index].type ?? '',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SizedBox(width: 8.w),
        DocumentStatusSuffix(
          docs: docs,
          index: index,
          languageProvider: languageProvider,
        ),
      ],
    );
  }
}

class DocumentPrefixIcon extends StatelessWidget {
  final List<Document>? docs;
  final int index;
  const DocumentPrefixIcon({
    super.key,
    this.docs,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return docs?[index].status == DocumentStatus.SUCCESS
        ? CircularCheckbox(
            value: true,
            bgColor: AppColors.g40,
            circularCheckboxPadding: 2.r,
          )
        : docs?[index].status == DocumentStatus.PENDING
            ? SvgPicture.asset(
                'assets/svgs/pendingVerification.svg',
              )
            : Container();
  }
}

class DocumentStatusSuffix extends StatelessWidget {
  final List<Document>? docs;
  final int index;
  final LanguageProvider languageProvider;
  const DocumentStatusSuffix({
    super.key,
    required this.docs,
    required this.index,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return docs?[index].status == DocumentStatus.SUCCESS
        ? GestureDetector(
            onTap: () async {
              try {
                if (docs?[index].presignedUrl != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          PdfViewPage(url: docs?[index].presignedUrl ?? ''),
                    ),
                  );
                } else {
                  showSnackbar(context, 'Document not available');
                }
              } catch (e) {
                Logger().e('Error fetching document: $e');
                showSnackbar(
                    context, 'Failed to load document: ${e.toString()}');
              }
            },
            child: Row(
              children: [
                Text(
                  languageProvider.getMessage('view', 'View'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Icon(Icons.chevron_right)
              ],
            ),
          )
        : docs?[index].status == DocumentStatus.PENDING
            ? Text(
                languageProvider.getMessage('pending', "Pending"),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.y50,
                    ),
              )
            : docs?[index].status == DocumentStatus.FAILED
                ? Text(
                    languageProvider.getMessage('failed', "Failed"),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.r50,
                        ),
                  )
                : Container();
  }
}
