import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/go_live_flow_controller.dart';
import 'package:snabbit_runner/pages/signup/onboarding_screen.dart';
import 'package:snabbit_runner/pages/signup/training_progress.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/debug/network_inspector.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/navigation_utils.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';

class TncAcceptPage extends StatefulWidget {
  static const String routeName = '/tnc-accept';

  const TncAcceptPage({super.key});

  @override
  State<TncAcceptPage> createState() => _TncAcceptPageState();
}

class _TncAcceptPageState extends State<TncAcceptPage> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  File? _pdfFile;
  bool _hasScrolledToEnd = false;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<File> downloadPdf(String url) async {
    // Raw Dio (external S3 URL — no Snabbit auth headers). Attach the debug
    // network inspector so the download still shows up in Chucker.
    final dio = Dio();
    DebugNetworkInspector.instance.attach(dio);
    final response = await dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/downloaded.pdf');
    await file.writeAsBytes(response.data);
    return file;
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context);
      userProfileProvider = Provider.of<UserProfileProvider>(context);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    try {
      Response? response = await RunnerHttp.getPrivacyPolicy();
      if (response != null && response.statusCode == 200) {
        _pdfFile = await downloadPdf(response.data);
      } else {
        _pdfFile = await downloadPdf(
            'https://snabbit-app-policies.s3.ap-south-1.amazonaws.com/Privacy_Policy_Expert_App.pdf');
      }
    } catch (e) {
      _pdfFile = await downloadPdf(
          'https://snabbit-app-policies.s3.ap-south-1.amazonaws.com/Privacy_Policy_Expert_App.pdf');
    }
  }

  void _continue() async {
    await userProfileProvider.runnerRegistrationAndErrorHandler(
      context: context,
      onSuccess: () {},
      onError: (errorMessage) {},
      navigateNext: true,
    );
  }

  // void _acceptTerms() {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (_) {
  //       return CommonBottomSheetSetup(
  //         child: Column(
  //           children: [
  //             SizedBox(height: 35.h),
  //             Image.asset(
  //               'assets/pngs/selfie_icon.png',
  //               height: 85.h,
  //             ),
  //             SizedBox(height: 28.h),
  //             Text(
  //               languageProvider.getMessage(
  //                 'selfie_snabbit_uniform_message',
  //                 'Please take a selfie in your Snabbit uniform',
  //               ),
  //               textAlign: TextAlign.center,
  //               style: Theme.of(context).textTheme.headlineMedium,
  //             ),
  //             SizedBox(height: 12.h),
  //             Text(
  //               languageProvider.getMessage(
  //                 'id_card_message',
  //                 'This will be your ID card picture ',
  //               ),
  //               textAlign: TextAlign.center,
  //               style: Theme.of(context).textTheme.headlineMedium?.copyWith(
  //                     fontSize: 19.sp,
  //                     color: AppColors.n70,
  //                   ),
  //             ),
  //             SizedBox(height: 43.h),
  //             SizedBox(
  //               width: 1.sw,
  //               child: ElevatedButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop();
  //                   Navigator.of(context).pushReplacement(
  //                     MaterialPageRoute(
  //                       builder: (context) => SelfieCapturePage(
  //                         onSubmit: (File image) async {
  //                           Response? response = await RunnerHttp.goLive(image);
  //                           if (response != null &&
  //                               response.statusCode == 200 &&
  //                               context.mounted) {
  //                             GlobalState().showSnabbitCongratsPopup = true;
  //                             Navigator.pushNamedAndRemoveUntil(context,
  //                                 PartnerHome.routeName, (route) => false);
  //                           } else {
  //                             try {
  //                               final resError =
  //                                   ResponseError.fromMap(response?.data);
  //                               if (resError.errors?.isNotEmpty == true) {
  //                                 _handleSelfieResponseErrors(resError);
  //                               } else {
  //                                 showSnackbar(
  //                                   context,
  //                                   "Something went wrong (${response?.statusCode}) - ${GlobalState().appError.value.description ?? ""}",
  //                                 );
  //                               }
  //                             } catch (e) {
  //                               showSnackbar(
  //                                 context,
  //                                 "Something went wrong ${GlobalState().appError.value.description ?? ""}",
  //                               );
  //                             }
  //                           }
  //                         },
  //                         onCancel: () {},
  //                       ),
  //                     ),
  //                   );
  //                 },
  //                 child: Text(
  //                   languageProvider.getMessage(
  //                     'take_selfie',
  //                     'Take selfie',
  //                   ),
  //                 ),
  //               ),
  //             ),
  //             SizedBox(height: 20.h),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // The optimized function to handle errors
  void _handleSelfieResponseErrors(ResponseError resError) {
    // Check if there are any errors to process
    final errors = resError.errors;
    if (errors == null || errors.isEmpty) {
      return;
    }

    // Iterate over the errors once to find the first matching one
    for (final error in errors) {
      if (error.errorMessageCode == AppStrings.retakeSelfie) {
        List<String> errors = (error.data as List).cast<String>();
        showSelfieError(errors, context);
        return; // Exit after handling the first error
      } else if (error.errorMessageCode ==
          AppStrings.redirectToPotentialEarnings) {
        NavigationUtils.openTrainingWebView(
          context: context,
          popUntil: true,
        );
        GoLiveFlowController.startFlow(context);
        showSnackbar(
          context,
          error.message ?? '',
        );
        return; // Exit after handling the first error
      } else {
        showSnackbar(
          context,
          error.message ?? '',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        elevation: 5.r,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage(
            'tnc_title',
            'Terms and conditions',
          ),
          style: textTheme.bodyLarge,
        ),
      ),
      persistentFooterButtons: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  backgroundColor: AppColors.n0,
                  side: BorderSide(
                    color: _hasScrolledToEnd ? AppColors.brand : AppColors.n40,
                    width: 1.r,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                onPressed: _hasScrolledToEnd
                    ? () {
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(
                  languageProvider.getMessage(
                    'decline',
                    'Decline',
                  ),
                ),
              ),
            ),
            SizedBox(width: 25.w),
            Expanded(
              child: ElevatedButton(
                onPressed: (_hasScrolledToEnd || userProfileProvider.loading)
                    ? _continue
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                child: userProfileProvider.loading
                    ? CupertinoActivityIndicator()
                    : Text(
                        languageProvider.getMessage(
                          'accept',
                          'Accept',
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 16.h,
        ),
        child: loading
            ? const Center(child: CupertinoActivityIndicator())
            : Container(
                width: 1.sw,
                padding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 25.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.n0,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      languageProvider.getMessage(
                        'please_read_understand',
                        'Please read and understand',
                      ),
                      style: textTheme.headlineSmall,
                    ),
                    Text(
                      'Page ${_currentPage + 1} of $_totalPages',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.n70,
                      ),
                    ),
                    // SizedBox(height: 16.h),
                    // Text(
                    //   languageProvider.getMessage(
                    //     'scroll_to_bottom',
                    //     'Scroll to the bottom to accept',
                    //   ),
                    //   style: textTheme.bodyMedium?.copyWith(
                    //     color: AppColors.n70,
                    //   ),
                    // ),
                    SizedBox(height: 16.h),
                    if (_pdfFile != null)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: PDFView(
                                filePath: _pdfFile!.path,
                                enableSwipe: true,
                                swipeHorizontal: false,
                                autoSpacing: false,
                                pageFling: false,
                                pageSnap: false,
                                fitPolicy: FitPolicy.WIDTH,
                                onRender: (pages) {
                                  setState(() {
                                    _totalPages = pages!;
                                  });
                                },
                                onPageChanged: (int? page, int? total) {
                                  setState(() {
                                    _currentPage = page!;
                                    if (_currentPage == _totalPages - 1) {
                                      _hasScrolledToEnd = true;
                                    }
                                  });
                                },
                              ),
                            ),
                            if (!_hasScrolledToEnd)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_downward,
                                      color: AppColors.n70,
                                      size: 18.r,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      languageProvider.getMessage(
                                        'scroll_to_end',
                                        'Please scroll to the end',
                                      ),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.n70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      const Text('No file found'),
                    // Expanded(
                    //   child: Text(
                    //     languageProvider.getMessage(
                    //       'tnc_data',
                    //       'Contact Snabbit support for Terms and Conditions',
                    //     ),
                    //     style: textTheme.bodyMedium?.copyWith(
                    //       color: AppColors.n80,
                    //     ),
                    //   ),
                    // ),
                    // if (!_hasScrolledToBottom)
                    //   Padding(
                    //     padding: EdgeInsets.only(top: 12.h),
                    //     child: Center(
                    //       child: Column(
                    //         children: [
                    //           Icon(
                    //             Icons.arrow_downward,
                    //             color: AppColors.n60,
                    //             size: 24.r,
                    //           ),
                    //           SizedBox(height: 4.h),
                    //           Text(
                    //             languageProvider.getMessage(
                    //               'scroll_to_continue',
                    //               'Scroll down to continue',
                    //             ),
                    //             style: textTheme.bodySmall?.copyWith(
                    //               color: AppColors.n60,
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   ),
                  ],
                ),
              ),
      ),
    );
  }
}
