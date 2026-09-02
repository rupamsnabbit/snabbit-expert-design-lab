import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/runner_http.dart';

import '../services/clevertap.dart';
import '../utils/colors.dart';
import '../utils/common_methods.dart';
import '../utils/tracking_events.dart';
import 'common_bottomsheet_setup.dart';

enum SupportType {
  PRIMARY,
  PAYOUT,
  INSURANCE
}

void showModalBottomNeedHelp(BuildContext context, {SupportType? type}) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return CommonBottomSheetSetup(
        child: SupportPopup(
          type: type ?? SupportType.PRIMARY,
        ),
      );
    },
  );
}

class SupportPopup extends StatefulWidget {
  final SupportType type;

  const SupportPopup({super.key, this.type = SupportType.PRIMARY});

  @override
  State<SupportPopup> createState() => _SupportPopupState();
}

class _SupportPopupState extends State<SupportPopup> {
  bool init = true;
  bool loading = true;
  String? phoneNumber;
  late LanguageProvider languageProvider;

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
      Response? response = await RunnerHttp.runnersMeHelpline(queryParameters: {
        'type': widget.type.name,
      });
      if (response != null && response.statusCode == 200) {
        phoneNumber = response.data['ph_no'];
      }
    } catch (e) {
      // DO NOTHING
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? SizedBox(
            height: 0.25.sh,
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Text(
                  languageProvider.getMessage("need_help", "Need help?"),
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.n90,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Text(
                  languageProvider.getMessage("connect_to_representative",
                      "We will connect you with one of our representatives to resolve your concern promptly"),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.n80,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.g40,
                  ),
                  onPressed: () async {
                    launchDialer(phoneNumber);
                    Navigator.of(context).pop();

                    await ClevertapSetup.logEvent(
                        TrackingEvents.contactUsButtonClcked,
                        {"home": "contact us button clicked"});
                  },
                  child:
                      Text(languageProvider.getMessage("call_us", "Call us")),
                ),
              ),
              SizedBox(height: 12.h),
            ],
          );
  }
}
