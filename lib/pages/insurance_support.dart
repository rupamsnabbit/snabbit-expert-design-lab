import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/debug/network_inspector.dart';
import 'package:snabbit_runner/services/server_requests/insurance_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/support_popup.dart';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:io';

import '../models/errors/response_error.dart';
import '../widgets/expert_info_appbar.dart';

class InsuranceSupport extends StatefulWidget {
  static const String routeName = '/insurance-support';

  const InsuranceSupport({super.key});

  @override
  State<InsuranceSupport> createState() => _InsuranceSupportState();
}

class _InsuranceSupportState extends State<InsuranceSupport> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  String? insuranceFile;
  String? error;
  File? healthCardPdf;
  File? policyPdf;
  String? supportPhoneNumber;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> initProcess() async {
    try {
      final response = await InsuranceHttp.getInsurance();
      if (response?.statusCode == 200) {
        error = null;
        insuranceFile = response?.data;

        if (insuranceFile != null) {
          await downloadAndExtractZip(insuranceFile!);
        }
      } else {
        try {
          error =
              ResponseError.fromMap(response?.data).getFirstError()?.message ??
                  "Server error - ${response?.statusCode}";
        } catch (e) {
          error = "Error while parsing custom error - $e";
        }
      }
    } catch (e) {
      error = "Client error - $e";
    }
    try {
      final supportResponse = await InsuranceHttp.getInsuranceSupport();
      supportPhoneNumber = supportResponse?.data['ph_no'];
    } catch (e) {
      // DO NOTHING
    }
  }

  Future<void> openWhatsApp() async {
    try {
      final Uri whatsappUri = Uri.parse("https://wa.me/$supportPhoneNumber");

      // if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      // } else {
      //   throw 'Could not launch WhatsApp';
      // }
    } catch (e) {
      if (mounted) {
        showSnackbar(context, "Something went wrong.");
      }
    }
  }

  Future<void> downloadAndExtractZip(String url) async {
    try {
      // Raw Dio (external URL — no Snabbit auth headers). Attach the debug
      // network inspector so the download still shows up in Chucker.
      final dio = Dio();
      DebugNetworkInspector.instance.attach(dio);
      // Download the zip file
      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // Get temp directory to save files
      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/insurance.zip');
      await zipFile.writeAsBytes(response.data);

      // Read and decode the zip file
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Extract the PDFs
      for (final file in archive) {
        if (file.isFile) {
          final filename = file.name.toLowerCase();
          final outputFile = File('${tempDir.path}/${file.name}');

          await outputFile.writeAsBytes(file.content as List<int>);

          if (filename.contains('healthcard') ||
              filename.contains('health_card')) {
            healthCardPdf = outputFile;
            // healthCardFileName = file.name;
          } else if (filename.endsWith('.pdf')) {
            policyPdf = outputFile;
            // policyFileName = file.name;
          }
        }
      }

      // Delete the zip file
      await zipFile.delete();
    } catch (e) {
      error = "Error extracting insurance documents: $e";
    }
  }

  Future<void> openPolicyPdf() async {
    try {
      if (policyPdf != null) {
        if (await File(policyPdf!.path).exists()) {
          final result = await OpenFilex.open(policyPdf!.path);
        } else {
          // print("PDF file does not exist at path: $filePath");
        }
      }
      //   showModalBottomSheet(
      //     context: context,
      //     backgroundColor: Colors.transparent,
      //     isScrollControlled: true,
      //     enableDrag: false,
      //     constraints: BoxConstraints(
      //       maxHeight: 0.9.sh,
      //       minHeight: 0.9.sh,
      //     ),
      //     builder: (_) {
      //       return ClipRRect(
      //         borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      //         child: Container(
      //           color: AppColors.n0,
      //           child: Column(
      //             children: [
      //               Padding(
      //                 padding: EdgeInsets.symmetric(horizontal: 16.w),
      //                 child: Row(
      //                   children: [
      //                     Expanded(
      //                       child: Text(
      //                         languageProvider.getMessage(
      //                           'insurance_policy',
      //                           'Insurance Policy',
      //                         ),
      //                         style: Theme.of(context).textTheme.bodyLarge,
      //                       ),
      //                     ),
      //                     IconButton(
      //                       onPressed: () {
      //                         Navigator.of(context).pop();
      //                       },
      //                       icon: const Icon(Icons.close_rounded),
      //                     ),
      //                   ],
      //                 ),
      //               ),
      //               Expanded(
      //                 child: PDFView(
      //                   filePath: policyPdf!.path,
      //                 ),
      //               ),
      //             ],
      //           ),
      //         ),
      //       );
      //     },
      //   );
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open policy file')),
        );
      }
    }
  }

  Widget get claimButton {
    if (supportPhoneNumber != null) {
      return SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton(
          onPressed: openWhatsApp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.g40,
          ),
          child: Text(
            languageProvider.getMessage(
              'claim_insurance',
              'Claim Insurance',
            ),
          ),
        ),
      );
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.n30,
      appBar: CommonAppBar(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16.w,
              24.h,
              16.w,
              16.h,
            ),
            child: Row(
              children: [
                SvgPicture.asset(AssetConstants.healthCard),
                Text(
                  languageProvider.getMessage('health_card', "Health Card"),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Color(0xFF1D2129),
                        // CSS: var(--Neutral-Foreground-Primary, #1D2129);
                        fontSize: 21.0,
                        // CSS: font-size: 21px;
                        fontStyle: FontStyle.normal,
                        // CSS: font-style: normal;
                        fontWeight: FontWeight.w700,
                        // CSS: font-weight: 700;
                        height: 18 / 21,
                        // CSS: line-height: 18px; (calculated as line-height / font-size)
                        letterSpacing: -0.24, // CSS: letter-spacing: -0.24px;
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16.h),
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                decoration: BoxDecoration(
                    color: AppColors.n0,
                    borderRadius: BorderRadius.circular(
                      8.r,
                    )),
                child: loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : error != null
                        ? Center(
                            child: Column(
                              children: [
                                Text(
                                  "$error",
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.r40),
                                ),
                                if (supportPhoneNumber != null)
                                  const Divider(
                                    color: AppColors.n50,
                                  ),
                                if (supportPhoneNumber != null)
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.h),
                                    child: Text(
                                      languageProvider.getMessage(
                                        'claim_assistance_help',
                                        'Click below for claim related queries',
                                      ),
                                      textAlign: TextAlign.center,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                claimButton,
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(24.r),
                                decoration: BoxDecoration(
                                  color: AppColors.n0,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    healthCardPdf != null
                                        ? Stack(
                                            children: [
                                              SizedBox(
                                                height: 170.h,
                                                child: PDFView(
                                                  filePath: healthCardPdf!.path,
                                                  enableSwipe: true,
                                                  swipeHorizontal: true,
                                                  autoSpacing: false,
                                                  pageFling: false,
                                                  pageSnap: false,
                                                  fitPolicy: FitPolicy.WIDTH,
                                                ),
                                              ),
                                              Positioned(
                                                right: 0,
                                                child: IconButton(
                                                  onPressed: () async {
                                                    if (await File(
                                                            healthCardPdf!.path)
                                                        .exists()) {
                                                      final result =
                                                          await OpenFilex.open(
                                                              healthCardPdf!
                                                                  .path);
                                                    } else {
                                                      // print("PDF file does not exist at path: $filePath");
                                                    }
                                                  },
                                                  icon: const Icon(
                                                    Icons.download,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : SizedBox(
                                            height: 170.h,
                                            child: const Center(
                                              child: Text(
                                                  "Health card preview not available"),
                                            ),
                                          ),
                                    SizedBox(height: 24.h),
                                    // Call button
                                    claimButton,
                                    SizedBox(height: 16.h),
                                    // View Policy
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48.h,
                                      child: OutlinedButton(
                                        onPressed: policyPdf != null
                                            ? openPolicyPdf
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.n80,
                                          side: const BorderSide(
                                              color: AppColors.n50),
                                        ),
                                        child: Text(
                                          languageProvider.getMessage(
                                            'view_policy',
                                            'View Policy',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showModalBottomNeedHelp() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return const CommonBottomSheetSetup(
          child: SupportPopup(
            type: SupportType.INSURANCE,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // Clean up temporary files
    healthCardPdf?.delete();
    policyPdf?.delete();
    super.dispose();
  }
}
