// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/job_in_progress/next_job_ready_warning.dart';
import 'package:vibration/vibration.dart';

import '../../utils/constants.dart';
import 'address_details.dart';
import 'auto_checkout_warning.dart';
import 'cod_payment.dart';
import 'cooking_preference_details.dart';
import 'customer_details.dart';

enum OnTheJobState {
  onTheJob,
  checkoutOtp,
  qrOrCash,
  qrSuccessful,
  qrFailed,
}

class OnTheJobStateProvider with ChangeNotifier {
  OnTheJobState _currentState = OnTheJobState.onTheJob;
  int _pollingCounter = qrPaymentMaxPollCount;
  String? _qrImageData;
  int? checkoutForRunnerJobId;

  void reset() {
    _pollingCounter = qrPaymentMaxPollCount;
    _currentState = OnTheJobState.onTheJob;
    _qrImageData = null;
  }

  OnTheJobState get currentState => _currentState;

  set currentState(OnTheJobState? val) {
    _currentState = val ?? OnTheJobState.onTheJob;
    if (currentState != OnTheJobState.onTheJob) {
      try {
        GlobalState().audioPlayer.stop();
        Vibration.cancel();
      } catch (e) {
        // DO NOTHING
      }
    }
    notifyListeners();
  }

  int get pollingCounter => _pollingCounter;

  set pollingCounter(int? val) {
    _pollingCounter = val ?? -1;
    notifyListeners();
  }

  void resetPollingCounter() {
    _pollingCounter = qrPaymentMaxPollCount;
    notifyListeners();
  }

  String? get qrImageData => _qrImageData;

  set qrImageData(String? val) {
    _qrImageData = val;
    notifyListeners();
  }
}

class OnTheJob extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const OnTheJob({super.key, required this.widgetData});

  @override
  State<OnTheJob> createState() => _OnTheJobState();
}

class _OnTheJobState extends State<OnTheJob> {
  late Duration localJobDurationRemaining;
  int? currentDuration;
  Timer? _timer;
  int? jobExtendedBy;
  int jobExtendedByChecker = 0;
  String? error;
  bool init = true;
  bool loading = true;
  bool isQRBottomSheetOpen = false;
  late SharedPreferences prefs;
  late String currentJobDurationSpKey;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late OnTheJobStateProvider onTheJobStateProvider;
  Color? timerFg;
  Color? timerBg;
  bool isError = false;

  Future<void> initProcess() async {
    currentJobDurationSpKey =
        "current_job_duration_${widget.widgetData?["job_id"]}";
    localJobDurationRemaining = DateTime.parse(widget.widgetData?['end_time'])
        .difference(DateTime.now());
    prefs = await SharedPreferences.getInstance();
    for (String key in prefs.getKeys()) {
      if (key.startsWith("current_job_duration") &&
          key != currentJobDurationSpKey) {
        await prefs.remove(key);
      }
    }
    if (prefs.getInt(currentJobDurationSpKey) == null ||
        prefs.getInt(currentJobDurationSpKey) == 0) {
      await prefs.setInt(
          currentJobDurationSpKey, widget.widgetData?['duration'] ?? 0);
    }
    currentDuration = widget.widgetData?['duration'];
    timerPeriodicProcess();
    _timer = Timer.periodic(1.seconds, (_) {
      timerPeriodicProcess();
    });
  }

  int get jobRemainingSeconds => localJobDurationRemaining.inSeconds;

  int? get autoCheckoutTotalSeconds =>
      anyValueToInt(widget.widgetData?['auto_checkout_seconds']);
  bool get showAutoCheckoutTimer =>
      autoCheckoutTotalSeconds != null &&
      autoCheckoutTotalSeconds! > 0 &&
      jobRemainingSeconds <= 0;

  void timerPeriodicProcess() async {
    currentDuration = widget.widgetData?['duration'];
    // localJobDurationRemaining -= 1.seconds;
    localJobDurationRemaining = DateTime.parse(widget.widgetData?['end_time'])
        .difference(DateTime.now());

    if (showAutoCheckoutTimer) {
      timerFg = AppColors.r40;
      timerBg = AppColors.r60;

      if (onTheJobStateProvider.currentState == OnTheJobState.onTheJob) {
        runnerRtDataProvider.updateBgColor(timerBg ?? AppColors.r60);

        // Keep manual "Check out" available during auto-checkout window.
        runnerRtDataProvider.updateBottomButtonJobProgress(
          workInProgressBottomButton(),
        );
      }
      return;
    }

    if (localJobDurationRemaining.inSeconds <= (1 * 60)) {
      if (localJobDurationRemaining.inSeconds < 0) {
        timerFg = AppColors.r40;
        timerBg = AppColors.r60;
      } else {
        timerFg = AppColors.r20;
        timerBg = AppColors.r40;
      }
      String msg = languageProvider.getMessage("time_up", "Time is up!");
      if (onTheJobStateProvider.currentState == OnTheJobState.onTheJob) {
        runnerRtDataProvider.updateBgColor(AppColors.r50);
        runnerRtDataProvider.updateMainMessage(msg);
        if (onTheJobStateProvider.currentState == OnTheJobState.onTheJob ||
            onTheJobStateProvider.currentState == OnTheJobState.qrSuccessful) {
          runnerRtDataProvider
              .updateBottomButtonJobProgress(workInProgressBottomButton());
        }
      }
    } else if (localJobDurationRemaining.inSeconds <=
        ((widget.widgetData?['checkout_before_mins'] ?? 5) * 60)) {
      timerFg = AppColors.y20;
      timerBg = AppColors.y40;
      String msg = languageProvider.getMessage(
          "please_finish_job_now", "Please finish the job now.");
      if (onTheJobStateProvider.currentState == OnTheJobState.onTheJob) {
        runnerRtDataProvider.updateBgColor(AppColors.y40);
        runnerRtDataProvider.updateMainMessage(msg);
        if (onTheJobStateProvider.currentState == OnTheJobState.onTheJob ||
            onTheJobStateProvider.currentState == OnTheJobState.qrSuccessful) {
          runnerRtDataProvider
              .updateBottomButtonJobProgress(workInProgressBottomButton());
        }
      }
    } else {
      timerFg = AppColors.g20;
      timerBg = AppColors.g50;
      if (onTheJobStateProvider.currentState == OnTheJobState.onTheJob) {
        runnerRtDataProvider.updateBgColor(AppColors.g50);
        runnerRtDataProvider.updateMainMessage("You are on the job!");
        if (onTheJobStateProvider.currentState == OnTheJobState.onTheJob ||
            onTheJobStateProvider.currentState == OnTheJobState.qrSuccessful) {
          runnerRtDataProvider.updateBottomButtonJobProgress(null);
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onTheJobStateProvider =
          Provider.of<OnTheJobStateProvider>(context, listen: true);
      onTheJobStateProvider.reset();
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  String _formatTime(int seconds) {
    bool isNegative = seconds < 0;
    seconds = seconds.abs();

    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;

    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = remainingSeconds.toString().padLeft(2, '0');

    String formattedTime = '$minutesStr:$secondsStr';

    return isNegative ? '-$formattedTime' : formattedTime;
  }

  DateTime _parseUtcDateTime(String? isoDate) {
    if (isoDate == null) {
      return DateTime.now().toUtc();
    }
    DateTime dateTime = DateTime.parse(isoDate);
    // Backend sends IST time - convert to UTC first
    // IST is UTC+5:30
    if (!isoDate.toUpperCase().endsWith('Z') &&
        !isoDate.contains('+') &&
        !isoDate.contains('-', 10)) {
      // Treat as IST and convert to UTC by subtracting 5 hours 30 minutes
      dateTime = dateTime.subtract(const Duration(hours: 5, minutes: 30));
    } else {
      // If timezone is specified, parse and convert to UTC
      dateTime = dateTime.toUtc();
    }
    return dateTime;
  }

  String _formatTimeFromIso(String? isoDate) {
    if (isoDate == null) {
      return "";
    }
    DateTime dateTime = DateTime.parse(isoDate);
    DateFormat timeFormat = DateFormat.jm();
    return timeFormat.format(dateTime.toLocal());
  }

  /// Computes remaining auto-checkout seconds after job end_time.
  /// - If jobRemainingSeconds is 0 or negative, we are already past end_time.
  /// - overflowSeconds = how long past end_time we are.
  /// - autoRemaining = totalAutoCheckoutSeconds - overflowSeconds.
  int _computeAutoCheckoutRemainingSeconds({
    required int jobRemainingSeconds,
    required int totalAutoCheckoutSeconds,
  }) {
    if (jobRemainingSeconds > 0) return totalAutoCheckoutSeconds;

    final overflowSeconds =
        jobRemainingSeconds.abs(); // jobRemainingSeconds is <= 0
    final remaining = totalAutoCheckoutSeconds - overflowSeconds;
    return remaining.clamp(0, totalAutoCheckoutSeconds);
  }

  Widget get mainWidget {
    switch (onTheJobStateProvider.currentState) {
      case OnTheJobState.qrOrCash:
      case OnTheJobState.qrSuccessful:
      case OnTheJobState.qrFailed:
        return const CODPayment();
      default:
        final int displaySeconds = showAutoCheckoutTimer
            ? _computeAutoCheckoutRemainingSeconds(
                jobRemainingSeconds: jobRemainingSeconds,
                totalAutoCheckoutSeconds: autoCheckoutTotalSeconds ?? 0,
              )
            : jobRemainingSeconds;

        final int totalSecondsForRing = showAutoCheckoutTimer
            ? (autoCheckoutTotalSeconds)
            : ((currentDuration ?? widget.widgetData?['duration'] ?? 0) * 60);

        final int remainingSecondsForRing = showAutoCheckoutTimer
            ? displaySeconds
            : (jobRemainingSeconds < 0 ? 0 : jobRemainingSeconds);

        final double ringValue = totalSecondsForRing > 0
            ? (remainingSecondsForRing / totalSecondsForRing).clamp(0.0, 1.0)
            : 0.0;

        final String timerPrefix = showAutoCheckoutTimer
            ? languageProvider.getMessage(
                "auto_checkout_in", "AUTO CHECKOUT IN")
            : (jobRemainingSeconds < 0
                ? languageProvider.getMessage("time_exceeded", "Time exceeded")
                : languageProvider.getMessage(
                    "time_remaining", "Time remaining"));
        return Column(
          children: [
            // Text('${runnerRtDataProvider.jobId}'),
            Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom_rounded,
                ),
                // SvgPicture.asset(
                //   'assets/svgs/drawer/training.svg',
                //   width: 24.r,
                //   height: 24.r,
                //   color: AppColors.n70,
                // ),
                SizedBox(width: 12.w),
                Text(
                  languageProvider.getMessage(
                    'duration',
                    'Duration',
                  ),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.n90,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${widget.widgetData?['duration']} Minutes",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.n80,
                      ),
                    ),
                    if (jobExtendedBy != null && jobExtendedBy! > 0)
                      Container(
                        margin: EdgeInsets.only(top: 4.h),
                        decoration: BoxDecoration(
                          color: AppColors.y20,
                          borderRadius: BorderRadius.circular(1000.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.5.w,
                          vertical: 4.5.h,
                        ),
                        child: Text(
                          "+ $jobExtendedBy mins",
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    // fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.y60,
                                  ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Divider(color: AppColors.n20, height: 1.h),
            SizedBox(height: 16.h),
            Row(
              children: [
                const Icon(
                  Icons.timelapse_rounded,
                ),
                // SvgPicture.asset(
                //   'assets/svgs/drawer/training.svg',
                //   width: 24.r,
                //   height: 24.r,
                //   color: AppColors.n70,
                // ),
                SizedBox(width: 12.w),
                Text(
                  languageProvider.getMessage(
                    'start_time',
                    'Start time',
                  ),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.n90,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimeFromIso(widget.widgetData?['start_time']),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.n80,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                const Icon(
                  Icons.timelapse_rounded,
                ),
                // SvgPicture.asset(
                //   'assets/svgs/drawer/training.svg',
                //   width: 24.r,
                //   height: 24.r,
                //   color: AppColors.n70,
                // ),
                SizedBox(width: 12.w),
                Text(
                  languageProvider.getMessage(
                    'end_time',
                    'End time',
                  ),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.n90,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimeFromIso(widget.widgetData?['end_time']),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.n80,
                  ),
                ),
              ],
            ),
            SizedBox(height: 36.h),
            Stack(
              alignment: Alignment.center,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(displaySeconds < 0 ? 0 : 3.14),
                  child: SizedBox(
                    width: 124.r,
                    height: 124.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 16.r,
                      value: ringValue,
                      backgroundColor: timerBg,
                      color: timerFg,
                    ),
                  ),
                ),
                Container(
                  width: 124.r,
                  height: 124.r,
                  padding: EdgeInsets.all(20.r),
                  child: FittedBox(
                    child: Column(
                      children: [
                        Text(
                          timerPrefix.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: timerBg,
                                  ),
                        ),
                        Text(
                          _formatTime(displaySeconds),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                                fontSize: 26.sp,
                                color: timerBg,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            if (showAutoCheckoutTimer)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: const AutoCheckoutWarning(),
              ),
            if (widget.widgetData?["next_job_ready"] == true)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: const NextJobReadyWarning(),
              ),
            const Divider(
              color: AppColors.n30,
            ),
            SizedBox(height: 12.h),
            AddressDetails(widgetData: widget.widgetData),
            SizedBox(height: 16.h),
            const CustomerDetails(),
            SizedBox(height: 16.h),
            CookingPreferenceDetails(widgetData: widget.widgetData),
            // SizedBox(height: 8.h),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Text(
            //       languageProvider.getMessage("payment", "Payment"),
            //       style: TextStyle(
            //         fontSize: 15.sp,
            //         fontWeight: FontWeight.w600,
            //         color: AppColors.n90,
            //       ),
            //     ),
            //     Text(
            //       widget.widgetData?['payment_method'] ?? "",
            //       style: TextStyle(
            //         fontSize: 13.sp,
            //         fontWeight: FontWeight.w600,
            //         color: AppColors.n80,
            //       ),
            //     ),
            //   ],
            // ),
            // SizedBox(height: 24.h),
            // SizedBox(height: 12.h),
          ],
        );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (currentDuration != null &&
          currentDuration != widget.widgetData?['duration']) {
        localJobDurationRemaining =
            DateTime.parse(widget.widgetData?['end_time'])
                .difference(DateTime.now());
      }

      jobExtendedBy = widget.widgetData?['duration'] -
          prefs.getInt(currentJobDurationSpKey);
      if (jobExtendedBy != null && jobExtendedBy! > jobExtendedByChecker) {
        // Logger().i("Job extended by: $jobExtendedBy");
        jobExtendedByChecker = jobExtendedBy!;
      } else if (jobExtendedBy != null && jobExtendedBy! <= 0) {
        jobExtendedBy = null;
      }
    } catch (e) {
      // Logger().i(e);
    }
    try {
      Future(() {
        if (onTheJobStateProvider.currentState == OnTheJobState.qrSuccessful) {
          runnerRtDataProvider
              .updateBottomButtonJobProgress(workInProgressBottomButton());
        }
      });
    } catch (e) {
      // DO NOTHING
    }
    return widget.widgetData?['job_id'] == null
        ? const Center(
            child: Text("Invalid Job"),
          )
        : loading || runnerRtDataProvider.waitForFetchData
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                child: mainWidget,
              );
  }

  Widget workInProgressBottomButton() {
    return Container(
      color: AppColors.n0,
      padding: EdgeInsets.symmetric(
        vertical: 16.h,
        horizontal: 36.w,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.g40,
          ),
          onPressed: () async {
            await Vibration.cancel();
            runnerRtDataProvider.updateBgColor(AppColors.brand);
            runnerRtDataProvider.updateBottomButtonJobProgress(null);
            onTheJobStateProvider.reset();
            collectPayment();
            await ClevertapSetup.logEvent(
                TrackingEvents.checkOutSubmitAfterCashCollection, {
              "action": "check out button click",
            });
          },
          child: Text(languageProvider.getMessage("check_out", "Check out")),
        ),
      ),
    );
  }

  Future<void> collectPayment() async {
    if (widget.widgetData?['cash_to_be_collected'] == true) {
      onTheJobStateProvider.currentState = OnTheJobState.qrOrCash;
    } else if (widget.widgetData?['show_checkout_otp']) {
      onTheJobStateProvider.checkoutForRunnerJobId =
          widget.widgetData?[AppStrings.jobId];
      otpDialog(context);
    } else {
      await checkOutApi(
          jobId: widget.widgetData?['job_id'] ?? -1,
          onSuccess: () {
            error = null;
            setState(() {});
            runnerRtDataProvider.fetchDataNow();
          },
          onError: () {
            error = 'Something went wrong';
            setState(() {});
          });
    }
  }

  void showUPIQRcode(dynamic data, Map<String, dynamic> requestBody) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter bottomSheetSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 1.0,
                minChildSize: 1.0,
                maxChildSize: 1.0,
                expand: false,
                builder: (context, scrollController) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          SizedBox(height: 12.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(24.r),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.n50),
                              borderRadius: BorderRadius.circular(24.r),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "${widget.widgetData?['customer_name']}",
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.n90,
                                  ),
                                ),
                                Text(
                                  languageProvider.getMessage(
                                      "collect_amount", "Collect amount"),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.n70,
                                  ),
                                ),
                                Text(
                                  "₹ ${widget.widgetData?['cash_amount']}",
                                  style: TextStyle(
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.n90,
                                  ),
                                ),
                                Image.memory(
                                  base64Decode(data["payment_data"]["body"]
                                      ["data"]["instrumentResponse"]["qrData"]),
                                  width: 240.w,
                                  height: 240.h,
                                  fit: BoxFit.contain,
                                ),
                                Text(
                                  languageProvider.getMessage(
                                      "request_customer_scan_qr",
                                      "Request customer to scan and pay"),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.n70,
                                  ),
                                ),
                                // SizedBox(
                                //   width: double.infinity,
                                //   child: ElevatedButton(
                                //     style: ElevatedButton.styleFrom(
                                //       backgroundColor: AppColors.g40,
                                //     ),
                                //     onPressed: () async {
                                //       await pollPaymentConfirmation(
                                //           requestBody);
                                //
                                //       await ClevertapSetup.logEvent(
                                //           TrackingEvents
                                //               .checkPaymentStatusButtonUsed,
                                //           {
                                //             'action':
                                //                 "check payment status used (for qr mode)",
                                //           });
                                //     },
                                //     child: Text(languageProvider.getMessage(
                                //         "check_status", "Check status")),
                                //   ),
                                // ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          });
        });
  }
}

Future<void> checkOutApi({
  required int? jobId,
  String? otp,
  VoidCallback? onSuccess,
  VoidCallback? onError,
}) async {
  Response? response = await JobHttp.checkout(jobId: jobId ?? -1, data: {
    "cash_collected": true,
    "checkout_otp": otp,
  });

  if (response?.statusCode == 200) {
    try {
      Provider.of<OnTheJobStateProvider>(
              GlobalState().navigatorKey.currentContext!,
              listen: false)
          .currentState = OnTheJobState.onTheJob;
    } catch (e) {
      // DO NOTHING
    }
    if (onSuccess != null) {
      onSuccess();
    }
  } else {
    if (onError != null) {
      onError();
    }
  }
}

void otpDialog(BuildContext context) {
  try {
    GlobalState().audioPlayer.stop();
    Vibration.cancel();
  } catch (e) {
    // DO NOTHING
  }
  final onTheJobStateProvider =
      Provider.of<OnTheJobStateProvider>(context, listen: false);
  onTheJobStateProvider.currentState = OnTheJobState.checkoutOtp;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context)
              .viewInsets
              .bottom,),
          child: const CommonBottomSheetSetup(child: CheckoutOTPPopup()),
        ),
      );
    },
  ).then((_) {
    // TODO test this scenario
    onTheJobStateProvider.currentState = OnTheJobState.onTheJob;
    onTheJobStateProvider.checkoutForRunnerJobId = null;
  });
}

class CheckoutOTPPopup extends StatefulWidget {
  const CheckoutOTPPopup({super.key});

  @override
  State<CheckoutOTPPopup> createState() => _CheckoutOTPPopupState();
}

class _CheckoutOTPPopupState extends State<CheckoutOTPPopup> {
  bool init = true;
  bool loading = false;
  String? error;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late OnTheJobStateProvider onTheJobStateProvider;
  TextEditingController otpTextController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onTheJobStateProvider =
          Provider.of<OnTheJobStateProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50.r,
      height: 50.r,
      textStyle:
          Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.n50),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.n40),
        borderRadius: BorderRadius.circular(10.r),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.g40),
      borderRadius: BorderRadius.circular(10.r),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: AppColors.n80,
      ),
    );
    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: AppColors.r50),
      ),
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: AppColors.n80,
      ),
    );
    return Column(
      children: [
        SizedBox(height: 20.h),
        Text(
          languageProvider.getMessage(
              "enter_otp_to_check_out", "Enter OTP to check out"),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 24.h),
        Pinput(
          isCursorAnimationEnabled: false,
          enabled: !loading,
          cursor: Text(
            "0",
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.n50),
          ),
          controller: otpTextController,
          preFilledWidget: Text(
            "0",
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.n50),
          ),
          errorBuilder: (String? errorText, String pin) {
            return Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Center(
                child: Text(errorText ?? "",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.r50)),
              ),
            );
          },
          mainAxisAlignment: MainAxisAlignment.center,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          submittedPinTheme: error != null ? errorPinTheme : submittedPinTheme,
          errorPinTheme: errorPinTheme,
          length: 3,
          pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
          showCursor: true,
          onChanged: (_) {
            setState(() {});
          },
        ),
        SizedBox(height: 18.h),
        error != null
            ? Text(
                languageProvider.getMessage("otp_incorrect_try_again",
                    "Incorrect OTP entered. Please enter again"),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.r50),
              )
            : Text(
                languageProvider.getMessage("ask_customer_for_otp",
                    "Please ask the customer to share the OTP with you"),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.n80),
              ),
        SizedBox(height: 28.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.g40,
            ),
            onPressed: loading || otpTextController.length < 3
                ? null
                : () async {
                    setState(() {
                      loading = true;
                    });
                    await checkOutApi(
                      jobId: runnerRtDataProvider.widgetInfo?.data?['job_id'] ??
                          -1,
                      otp: otpTextController.text,
                      onSuccess: () {
                        error = null;
                        setState(() {});
                        runnerRtDataProvider.fetchDataNow();
                        Navigator.of(context).pop();
                      },
                      onError: () {
                        error = 'Something went wrong';
                        setState(() {});
                      },
                    );
                    setState(() {
                      loading = false;
                    });
                    // await ClevertapSetup.logEvent(
                    //     TrackingEvents.checkOutSubmitAfterCashCollection, {
                    //   'action': "qr code payment mode selected at check out",
                    // });
                  },
            child: Text(
              languageProvider.getMessage("submit", 'Submit'),
            ),
          ),
        ),
        SizedBox(height: 12.h),
      ],
    );
  }
}
