import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/support_popup.dart';
import 'package:url_launcher/url_launcher.dart';


class DeviceTestFailedWarning extends StatefulWidget {

  const DeviceTestFailedWarning({
    Key? key,
  }) : super(key: key);

  @override
  State<DeviceTestFailedWarning> createState() => _DeviceTestFailedWarningState();
}

class _DeviceTestFailedWarningState extends State<DeviceTestFailedWarning> {
  late LanguageProvider languageProvider;
  bool init = true;
  bool loading = true;
  String? phoneNumber;

  @override
  void didChangeDependencies() {
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
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    try {
      Response? response = await RunnerHttp.runnersMeHelpline(
          queryParameters: {
            'type': SupportType.PRIMARY.name,
          }
      );
      if (response != null && response.statusCode == 200) {
        phoneNumber = response.data['ph_no'];
      }
    } catch (e) {
      // DO NOTHING
    }
  }

  Future<void> launchDialer() async {

    final phone = phoneNumber ?? '';
    if(phone.trim().isNotEmpty){
      await CallUtils.handleCallInitiation(
          phoneNumber: phone,
          context: context,
          callSourceLabel: "DEVICE_TEST_FAILED_WARNING",
          onFailure: ({e,st}) {
            showSnackbar(
              context,
              languageProvider.getMessage('call_support_error', 'Error launching dialer'),
            );
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 1.sw,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8.h),
          // Handle bar
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D1D1),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 24.h),

          // Error Icon
          SizedBox(
            width: 64.w,
            height: 64.w,
            child: SvgPicture.asset(AssetConstants.crossMark), // Use your actual icon if needed
          ),
          SizedBox(height: 16.h),

          // Title & Description
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                languageProvider.getMessage('device_test_failed_warning_title', 'Device test failed repeatedly'),
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 21.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.24,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                languageProvider.getMessage(
                  'device_test_failed_warning_description',
                  'Your phone didn\'t pass some tests. Please\ncontact training centre for help',
                ),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 16.sp,
                  height: 1.5,
                  letterSpacing: -0.24,
                ),
              ),
            ],
          ),
          SizedBox(height: 32.h),

          // Call Support Button
          SizedBox(
            width: 1.sw,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.call, color: AppColors.n0),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.g40,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: launchDialer,
              label: Text(
                languageProvider.getMessage('call_support', 'Call Support'),
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.n0,
                ),
              ),
            ),
          ),

          SizedBox(height: 12.h),

          // Go Back Button
          SizedBox(
            width: 1.sw,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color:AppColors.brand),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                languageProvider.getMessage('go_back', 'Go back'),
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),

        ],
      ),
    );
  }
}

void showDeviceTestFailedWarning(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const DeviceTestFailedWarning(),
    ),
  );
}
