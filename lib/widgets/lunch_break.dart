import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/lunch_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/support_popup.dart';

import '../services/clevertap.dart';
import '../utils/app_strings.dart';
import '../utils/tracking_events.dart';

class LunchWidgetData {
  bool lunchApplicable;
  String? title;
  String? description;
  String? buttonType;
  String? buttonText;

  LunchWidgetData({
    this.lunchApplicable = false,
    this.title,
    this.description,
    this.buttonType,
    this.buttonText,
  });

  factory LunchWidgetData.fromMap(Map<String, dynamic> map) {
    return LunchWidgetData(
      lunchApplicable: map['break_given'] ?? false,
      title: map['title'],
      description: map['description'],
      buttonType: map['button_type'],
      buttonText: map['button_text'],
    );
  }
}

class LunchInfo {
  String? type;
  DateTime? start;

  LunchInfo({
    this.type,
    this.start,
  });

  factory LunchInfo.fromMap(Map<String, dynamic> map) {
    return LunchInfo(
      type: map['break_start'],
      start: DateTime.tryParse(map['break_start_time'] ?? "")?.toLocal(),
    );
  }
}

class LunchBreak extends StatefulWidget {
  const LunchBreak({
    super.key,
  });

  @override
  State<LunchBreak> createState() => _LunchBreakState();
}

class _LunchBreakState extends State<LunchBreak> {
  bool init = true;
  bool loading = true;
  String? error;
  late RunnerRtDataProvider runnerRtDataProvider;
  late LanguageProvider languageProvider;
  LunchWidgetData? lunchWidgetData;
  LunchInfo? lunchInfo;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
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
      Response? response = await LunchHttp.runnersMeBreak();
      if (response != null && response.statusCode == 200) {
        // SUCCESS
        error = null;
        lunchWidgetData = LunchWidgetData.fromMap(response.data);
      } else {
        error = "Something went wrong on server - ${response?.statusCode}";
      }
    } catch (e) {
      error = "Something went wrong - $e";
    }
  }

  Widget mainBreakWidget() {
    if (lunchInfo == null) {
      return Column(
        children: [
          SizedBox(height: 32.h),
          Text(
            languageProvider.getMessage(
              lunchWidgetData?.title ?? "",
              lunchWidgetData?.lunchApplicable == true
                  ? "Take a break"
                  : "You are not eligible for the break",
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 16.h),
          Text(
            languageProvider.getMessage(
              lunchWidgetData?.description ?? "",
              lunchWidgetData?.lunchApplicable == true
                  ? "You've been working for long. Take a short break while waiting for your next job!"
                  : "You need to work longer to become eligible for breaks",
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.n80),
          ),
          SizedBox(height: 31.h),
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: SizedBox(
              width: 1.sw,
              child: lunchWidgetData?.buttonType == "action"
                  ? ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          loading = true;
                        });
                        try {
                          ClevertapSetup.logEvent(
                            TrackingEvents.breakStartButtonClicked,
                            {},
                          );
                          Response? response =
                              await LunchHttp.runnersMeBreakStart();
                          if (response != null && response.statusCode == 200) {
                            lunchInfo = LunchInfo.fromMap(response.data);
                          } else {
                            lunchInfo = LunchInfo(type: "ERROR");
                          }
                        } catch (e) {
                          lunchInfo = LunchInfo(type: "ERROR");
                        }
                        loading = false;
                        runnerRtDataProvider.waitForFetchData = true;
                        runnerRtDataProvider.fetchDataNow();
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.g40,
                      ),
                      child: Text(
                        languageProvider.getMessage(
                            lunchWidgetData?.buttonText ?? "",
                            "Start your break"),
                      ),
                    )
                  : lunchWidgetData?.buttonType == AppStrings.contactSupport
                      ? OutlinedButton(
                          onPressed: () {
                            lunchInfo =
                                LunchInfo(type: AppStrings.contactSupport);
                            setState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.n40),
                            foregroundColor: AppColors.n90,
                            padding: EdgeInsets.symmetric(
                              vertical: 14.h,
                              horizontal: 16.w,
                            ),
                          ),
                          child: Text(
                            languageProvider.getMessage(
                                lunchWidgetData?.buttonText ?? "",
                                "Contact support"),
                          ),
                        )
                      : const SizedBox(),
            ),
          ),
        ],
      );
    } else if (lunchInfo?.type == "NOW") {
      return Column(
        children: [
          SizedBox(height: 32.h),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.g40,
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(10.r),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.n0,
              size: 40.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            languageProvider.getMessage(
              "break_start_now",
              "Your break is starting now",
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 32.h),
        ],
      );
    } else if (lunchInfo?.type == "LATER") {
      return Column(
        children: [
          SizedBox(height: 32.h),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.g40,
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(10.r),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.n0,
              size: 40.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            "${languageProvider.getMessage(
              "break_start_later",
              "Your break is starting at",
            )} ${DateFormat('hh:mm a').format(lunchInfo?.start ?? DateTime.now())}",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 32.h),
        ],
      );
    } else if (lunchInfo?.type == "ERROR") {
      return Column(
        children: [
          SizedBox(height: 32.h),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.r40,
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(10.r),
            child: Icon(
              Icons.close_rounded,
              color: AppColors.n0,
              size: 40.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            languageProvider.getMessage(
              "break_na",
              "You are not eligible for the break",
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 32.h),
        ],
      );
    } else if (lunchInfo?.type == AppStrings.contactSupport) {
      return const SupportPopup();
    }
    return SizedBox(
      height: 0.2.sh,
      child: const Center(
        child: Text("Click outside to close this popup."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? SizedBox(
            height: 0.25.sh,
            child: const Center(child: CupertinoActivityIndicator()),
          )
        : error != null
            ? SizedBox(
                height: 0.25.sh,
                child: Center(child: Text("$error")),
              )
            : lunchWidgetData == null
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: const Text(
                        "[LunchWidgetData] is null. Something went wrong."),
                  )
                : mainBreakWidget();
  }
}
