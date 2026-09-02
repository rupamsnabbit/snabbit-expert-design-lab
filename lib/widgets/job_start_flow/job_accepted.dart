import 'dart:async';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snabbit_runner/modules/snabbit_shield/snabbit_shield_permission_handler.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/alarm_silencer.dart';
import 'package:snabbit_runner/services/analytics/job_lifecycle_analytics.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/attendance_flow/attendance_confirmed.dart';
import 'package:snabbit_runner/widgets/check_in_without_otp/views/check_in_without_otp_button.dart';
import 'package:snabbit_runner/widgets/check_in_without_otp/views/check_in_without_otp_bottom_sheet.dart';
import 'package:snabbit_runner/widgets/job_in_progress/address_details.dart';
import 'package:snabbit_runner/widgets/job_login/selfie_login.dart';
import 'package:snabbit_runner/widgets/gamification/cta_badge.dart';
import 'package:snabbit_runner/widgets/gamification/nudge_banner.dart';
import 'package:snabbit_runner/widgets/low_battery_warning.dart';
import 'package:snabbit_runner/providers/overlay_provider.dart';
import 'package:snabbit_runner/widgets/awol/awol_job_warning_card.dart';
import 'package:snabbit_runner/widgets/map_job_location.dart';
import 'package:snabbit_runner/models/gamification/pre_action_nudge.dart';
import 'package:snabbit_runner/services/tracking/delayed_checkin_tracking.dart';
import 'package:snabbit_runner/widgets/delayed_checkin/delayed_checkin_penalty_widget.dart';
import 'package:snabbit_runner/widgets/delayed_checkin/job_support_bottom_sheet.dart';
import '../../constants/assets_constants.dart';
import '../../providers/runner_rt_data.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';
import '../../services/clevertap.dart';
import '../../utils/common_methods.dart';
import '../attendance_flow/custom_timer.dart';
import '../job_in_progress/customer_details.dart';
import 'package:snabbit_runner/models/payout/payout_info.dart';
import '../common_widgets/job_payout_summary_bar.dart';
import '../common_widgets/sweeping_shine.dart';
import 'checkin_confirmed.dart';

class JobAccepted extends StatefulWidget {
  final Map<String, dynamic>? widgetData;
  final String? widgetName;

  const JobAccepted({super.key, this.widgetData, this.widgetName});

  @override
  State<JobAccepted> createState() => _JobAcceptedState();
}

class _JobAcceptedState extends State<JobAccepted> {
  // bool init = true;
  // late RunnerRtDataProvider runnerRtDataProvider;

  // bool _fiveMinuteWarningCalled = false;
  bool init = true;
  bool loading = true;
  String? _trackedDelayedCheckinEventId;

  // late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;

  Future<void> initProcess() async {}

  /// Builds map + address + customer details, optionally wrapped
  /// in an AWOL warning card if AWOL data is present.
  Widget _buildJobDetailsSection(RunnerRtDataProvider runnerRtDataProvider) {
    final jobDetails = Column(
      children: [
        SizedBox(
          height: 100.h,
          child: MapJobLocation(
            markerPosition:
                LatLng(widget.widgetData!["lat"], widget.widgetData!["lng"]),
            adm: widget.widgetData?['adm'],
            onDirectionsTap: _trackArrivalShowDirectionsClick,
          ),
        ),
        SizedBox(height: 24.h),
        AddressDetails(widgetData: widget.widgetData),
        SizedBox(height: 16.h),
        CustomerDetails(
          onCallTap: _trackArrivalCallCustomerClick,
          onChatTap: _trackArrivalChatCustomerClick,
        ),
      ],
    );

    final awolData = runnerRtDataProvider.awolData;
    final overlayProvider =
        Provider.of<OverlayProvider>(context, listen: false);
    if (awolData == null || !awolData.isJob || !overlayProvider.isAwolV2Enabled)
      return jobDetails;

    // Determine warning state from timer progress
    // countdown may be absent for JOB state — default to yellow
    final countdown = awolData.countdown;
    final warningState = countdown == null
        ? AwolWarningState.yellow
        : ((countdown.totalSeconds ?? 0) > 0 &&
                (countdown.remainingSeconds ?? 0) <
                    (countdown.totalSeconds ?? 0) / 3)
            ? AwolWarningState.red
            : AwolWarningState.yellow;

    return AwolJobWarningCard(
      awolData: awolData,
      languageProvider: languageProvider,
      warningState: warningState,
      child: jobDetails,
    );
  }

  DateTime? _parseTime(String timeStr) {
    try {
      DateFormat format = DateFormat("h:mm a");
      DateTime parsedTime = format.parse(timeStr.toUpperCase());
      DateTime nowUtc = DateTime.now().toUtc();
      // Backend sends time in IST. Convert to UTC: IST = UTC+5:30, so subtract 5h 30m.
      // E.g. 09:30 IST → 04:00 UTC.
      int totalMinutes = parsedTime.hour * 60 +
          parsedTime.minute -
          (5 * 60 + 30); // showing break up for simplicity
      // If result is negative, time in UTC falls on same calendar day (wrap within 24h).
      if (totalMinutes < 0) totalMinutes += 24 * 60;
      int utcHour = totalMinutes ~/ 60;
      int utcMinute = totalMinutes % 60;
      DateTime dateTimeWithDate = DateTime.utc(
          nowUtc.year, nowUtc.month, nowUtc.day, utcHour, utcMinute);
      return dateTimeWithDate;
    } catch (e) {
      return null;
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

  List<PreActionNudge> get _nonPenaltyNudges => runnerRtDataProvider
      .preActionNudges
      .where((n) =>
          n.lifecycleActionType != LifecycleActionType.delayedCheckinPenalty)
      .toList();

  int get _otAmount =>
      anyValueToInt(runnerRtDataProvider.widgetInfo?.data?['ot_amount']) ?? 0;

  bool get _isLongDistance =>
      runnerRtDataProvider.widgetInfo?.data?['is_long_distance'] ?? false;

  int get _longDistanceAmount =>
      anyValueToInt(
          runnerRtDataProvider.widgetInfo?.data?['long_distance_amount']) ??
      0;

  bool get _isTimePe =>
      runnerRtDataProvider.widgetInfo?.data?['is_time_pe'] ?? false;

  int get _timePeAmount =>
      anyValueToInt(runnerRtDataProvider.widgetInfo?.data?['time_pe_amount']) ??
      0;

  void _checkDelayedCheckinTracking(RunnerRtDataProvider rt) {
    final dcData = rt.delayedCheckinData;
    final dcEventKey =
        dcData?.countdown?.triggerAt?.millisecondsSinceEpoch.toString();
    if (dcData != null && dcEventKey != _trackedDelayedCheckinEventId) {
      _trackedDelayedCheckinEventId = dcEventKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) DelayedCheckinTracking.trackPopupViewed(data: dcData);
      });
    } else if (dcData == null) {
      _trackedDelayedCheckinEventId = null;
    }
  }

  void _onRtChange() {
    _checkDelayedCheckinTracking(runnerRtDataProvider);
  }

  @override
  void dispose() {
    runnerRtDataProvider.removeListener(_onRtChange);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    runnerRtDataProvider =
        Provider.of<RunnerRtDataProvider>(context, listen: false);

    if (init) {
      init = false;
      runnerRtDataProvider.addListener(_onRtChange);
      _checkDelayedCheckinTracking(runnerRtDataProvider);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      Logger().f(
          "I was called i am did change dependencies in on the job dart file yoi");

      _trackArrivalScreenLoad();
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _trackArrivalScreenLoad() {
    final rt = Provider.of<RunnerRtDataProvider>(context, listen: false);
    final data = rt.widgetInfo?.data ?? const {};
    final payout =
        (data['payout_info'] as Map?)?.cast<String, dynamic>() ?? const {};
    JobLifecycleAnalytics.logEvent(TrackingEvents.arrivalScreenLoad, {
      'is_long_distance': data['is_long_distance'] == true,
      'scheduled_check_in_time': widget.widgetData?['checkin_promise'],
      'start_time': widget.widgetData?['start_time'],
      'check_in_bonus_amount': payout['check_in_amount'],
      'earnings_shown': payout['total_earning'],
    });
  }

  void _trackArrivalShowDirectionsClick() {
    JobLifecycleAnalytics.logEvent(
        TrackingEvents.arrivalShowDirectionsCtaClick, const {});
  }

  void _trackArrivalCallCustomerClick() {
    JobLifecycleAnalytics.logEvent(
        TrackingEvents.arrivalCallCustomerCtaClick, const {});
  }

  void _trackArrivalChatCustomerClick() {
    JobLifecycleAnalytics.logEvent(
        TrackingEvents.arrivalChatCustomerCtaClick, const {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RunnerRtDataProvider>(
      builder: (context, runnerRtDataProvider, child) {
        if (widget.widgetData == null) return Container();
        if (runnerRtDataProvider.waitForFetchData) {
          return const CupertinoActivityIndicator();
        }
        final dcData = runnerRtDataProvider.delayedCheckinData;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dcData != null)
              DelayedCheckinPenaltyWidget(
                data: dcData,
                languageProvider: languageProvider,
                penaltyNudge: runnerRtDataProvider.preActionNudges
                    .firstOfType(LifecycleActionType.delayedCheckinPenalty),
              ),
            if (_nonPenaltyNudges.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: NudgeBannerList(nudges: _nonPenaltyNudges),
              ),
            if (runnerRtDataProvider.widgetInfo?.data?["is_ot"] == true &&
                _otAmount > 0)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: AmountBanner(
                  prefixIconSize: 80.w,
                  valueBoxSize: 110.w,
                  image: AssetConstants.otBanner,
                  amount: _otAmount,
                  title: Text(
                    languageProvider.getMessage(
                      "bonus_capital",
                      "BONUS",
                    ),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff03445F),
                        ),
                  ),
                  subtitle: languageProvider.getMessage(
                    "extra_capital",
                    "EXTRA",
                  ),
                ),
              ),
            if (_isLongDistance && _longDistanceAmount > 0)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: AmountBanner(
                  prefixIconSize: 80.w,
                  valueBoxSize: 110.w,
                  image: AssetConstants.longDistanceBanner,
                  amount: _longDistanceAmount,
                  title: Text(
                    languageProvider.getMessage(
                      "long_distance_capital",
                      "LONG\nDISTANCE\nBONUS",
                    ),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff1F0B6E),
                        ),
                  ),
                  subtitle: languageProvider.getMessage(
                    "extra_capital",
                    "EXTRA",
                  ),
                ),
              ),
            if (_isTimePe && _timePeAmount > 0)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: AmountBanner(
                  prefixIconSize: 80.w,
                  valueBoxSize: 110.w,
                  amount: _timePeAmount,
                  title: Text(
                    languageProvider.getMessage(
                      "bonus_capital",
                      "BONUS",
                    ),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff276209),
                        ),
                  ),
                  image: AssetConstants.timePeBanner,
                  subtitle: languageProvider.getMessage(
                    "extra_capital",
                    "EXTRA",
                  ),
                ),
              ),
            if (widget.widgetData!["show_avoid_penalty_banner"] == true)
              Padding(
                padding: EdgeInsets.only(bottom: 24.h),
                child: AmountBanner(
                  valueBoxSize: 0,
                  prefixIconSize: 90.w,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        languageProvider.getMessage(
                          'avoid_penalty',
                          'Avoid penalty',
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xff623D09), fontSize: 16.sp),
                      ),
                      Text(
                        languageProvider.getMessage(
                          'reach_on_time',
                          'Please reach on time',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                color: const Color(0xff623D09),
                                fontWeight: FontWeight.w900),
                      ),
                      if (widget.widgetData?['show_timer'] == true &&
                          _parseTime(widget.widgetData?["start_time"]) != null)
                        Container(
                          padding: EdgeInsets.only(top: 16.h, bottom: 28.h),
                          alignment: Alignment.center,
                          child: CircularTimerWidget(
                            persistDuration: false,
                            width: 124,
                            height: 124,
                            sharedPrefsKeyPrefix:
                                'mark_arrival_${runnerRtDataProvider.jobId}',
                            utcTimeString: DateFormat('HH:mm:ss').format(
                                _parseTime(widget.widgetData?["start_time"])!),
                            backgroundColor: AppColors.y30,
                            labelTextColor: const Color(0xffFFA600),
                            lateTextColor: AppColors.r50,
                            lateBackgroundColor: AppColors.r20,
                            labelText:
                                widget.widgetName == "RUNNER_JOB_CHECK_IN"
                                    ? languageProvider.getMessage(
                                        "check_in_by_caps", "CHECK IN BY")
                                    : "",
                            lateText: languageProvider.getMessage(
                              'getting_late_capital',
                              'GETTING LATE',
                            ),
                          ),
                        ),
                      if (widget.widgetData?['checkin_promise'] != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 24.h),
                          child: TimerFromUtc(
                            utcTimestamp: widget.widgetData?['checkin_promise'],
                          ),
                        ),
                      _buildJobDetailsSection(runnerRtDataProvider),
                      if (runnerRtDataProvider
                              .widgetInfo?.data?['payout_info'] !=
                          null)
                        Padding(
                          padding: EdgeInsets.only(top: 12.h),
                          child: JobPayoutSummaryBar(
                            payoutInfo: PayoutInfo.fromDynamic(
                                runnerRtDataProvider
                                    .widgetInfo?.data?['payout_info']),
                          ),
                        )
                    ],
                  ),
                  image: AssetConstants.attendancePendingAmber,
                ),
              ),
            LowBatteryWarning(
              margin: EdgeInsets.fromLTRB(
                0,
                24.h,
                0,
                14.h,
              ),
            ),
            if (widget.widgetData?['show_timer'] == true &&
                _parseTime(widget.widgetData?["start_time"]) != null &&
                dcData == null)
              Container(
                padding: EdgeInsets.only(top: 16.h, bottom: 28.h),
                alignment: Alignment.center,
                child: CircularTimerWidget(
                  persistDuration: false,
                  width: 124,
                  height: 124,
                  sharedPrefsKeyPrefix:
                      'mark_arrival_${runnerRtDataProvider.jobId}',
                  utcTimeString: DateFormat('HH:mm:ss')
                      .format(_parseTime(widget.widgetData?["start_time"])!),
                  backgroundColor: AppColors.y30,
                  labelTextColor: const Color(0xffFFA600),
                  lateTextColor: AppColors.r50,
                  lateBackgroundColor: AppColors.r20,
                  labelText: "",
                  lateText: languageProvider.getMessage(
                    'getting_late_capital',
                    'GETTING LATE',
                  ),
                ),
              ),
            if (widget.widgetData?['checkin_promise'] != null && dcData == null)
              Padding(
                padding: EdgeInsets.only(bottom: 24.h),
                child: TimerFromUtc(
                  utcTimestamp: widget.widgetData?['checkin_promise'],
                ),
              ),
            _buildJobDetailsSection(runnerRtDataProvider),
            if (runnerRtDataProvider.widgetInfo?.data?['payout_info'] != null)
              Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: JobPayoutSummaryBar(
                  payoutInfo: PayoutInfo.fromDynamic(
                      runnerRtDataProvider.widgetInfo?.data?['payout_info']),
                ),
              ),
          ],
        );
      },
    );
  }
}

class InfoColumn extends StatelessWidget {
  final String title;
  final String subtitle;

  const InfoColumn({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.n80),
        ),
      ],
    );
  }
}

class JobAcceptedBottomActionButton extends StatefulWidget {
  final Color bgColor;
  final String? widgetName;
  final Map<String, dynamic>? widgetData;
  final bool? disableMarkArrival;
  final bool? shouldPopFirst;

  const JobAcceptedBottomActionButton({
    super.key,
    this.bgColor = AppColors.brand,
    required this.widgetName,
    required this.widgetData,
    this.disableMarkArrival,
    this.shouldPopFirst,
  });

  @override
  State<JobAcceptedBottomActionButton> createState() =>
      _JobAcceptedBottomActionButtonState();
}

class _JobAcceptedBottomActionButtonState
    extends State<JobAcceptedBottomActionButton> {
  final TextEditingController otpTextController = TextEditingController();
  bool isError = false;
  bool loading = false;

  bool init = true;

  double? distanceInMeters;
  bool markArrivalBtnEnabled = false;
  Position? currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _locationErrorLogged = false;

  late RunnerRtDataProvider runnerRtDataProvider;

  /// True only on the new mark-arrival-disabled check-in screen: the backend
  /// sends RUNNER_JOB_CHECK_IN with show_timer:true ONLY when the cluster config
  /// is on. Gates the redesign (Check In white label, No-OTP moved into the OTP
  /// sheet) so legacy POST_ACCEPT / arrived-CHECK_IN screens stay unchanged.
  bool get _isMarkArrivalDisabledFlow =>
      widget.widgetName == "RUNNER_JOB_CHECK_IN" &&
      widget.widgetData?['show_timer'] == true;

  /// The in-sheet "No OTP" affordance shows only on the mark-arrival-disabled
  /// flow AND when the backend allows no-OTP check-in for this job — mirroring
  /// the gate the standalone [CheckInWithoutOtpButton] had before it moved into
  /// the OTP sheet. Without the second check, a mark-arrival-disabled job that
  /// still requires OTP (allow_check_in_without_otp:false) would wrongly show it.
  bool get _showInSheetNoOtp =>
      _isMarkArrivalDisabledFlow &&
      widget.widgetData?['allow_check_in_without_otp'] == true;

  @override
  void initState() {
    super.initState();
    _getLocationUpdates();
  }

  void _getLocationUpdates() {
    MonitoringServiceHelper.logInfo(
      "Location Updates Started",
      {
        'component': 'JobAccepted',
        'action': 'startLocationUpdates',
        'targetLat': widget.widgetData?['lat'],
        'targetLng': widget.widgetData?['lng']
      },
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
    )).listen(
      (Position position) {
        if (!mounted) return;
        setState(() {
          currentPosition = position;
          if (currentPosition != null) {
            distanceInMeters = Geolocator.distanceBetween(
              currentPosition!.latitude,
              currentPosition!.longitude,
              widget.widgetData?['lat'],
              widget.widgetData?['lng'],
            );
          }
        });
      },
      onError: (error, stackTrace) {
        if (!_locationErrorLogged) {
          _locationErrorLogged = true;
          FirebaseCrashlytics.instance.recordError(error, stackTrace,
              reason: 'JobAccepted location stream error', fatal: false);
        }
      },
    );
  }

  late LanguageProvider languageProvider;

  Future<void> initProcess() async {
    if (widget.disableMarkArrival != true) {
      markArrivalBtnEnabled = widget.widgetData?['enable_arrival'] ?? false;
    } else {
      markArrivalBtnEnabled = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  Widget otpDialog(BuildContext context, StateSetter bottomSheetSetState,
      RunnerRtDataProvider runnerRtDataProvider) {
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
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          children: [
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.center,
              child: Container(
                height: 4.h,
                width: 36.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.r),
                  color: AppColors.dragHandle,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              languageProvider.getMessage(
                  "enter_otp_to_check_in", "Enter OTP to Check in"),
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
              submittedPinTheme: isError ? errorPinTheme : submittedPinTheme,
              errorPinTheme: errorPinTheme,
              length: 3,
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              onChanged: (_) {
                bottomSheetSetState(() {});
              },
            ),
            SizedBox(height: 18.h),
            isError
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
                        bottomSheetSetState(() {
                          loading = true;
                        });
                        Response? response = await JobHttp.startJob(data: {
                          "job_id": runnerRtDataProvider.jobId ?? -1,
                          "otp": otpTextController.text,
                        });
                        // await Future.delayed(Duration(seconds: 15));
                        if (response != null && response.statusCode == 200) {
                          await PostActionOverlayController.instance
                              .showFromResponse(response.data,
                                  LifecycleActionType.earlyCheckin);
                          runnerRtDataProvider.waitForFetchData = true;
                          if (mounted) {
                            bottomSheetSetState(() {
                              // loading = false;
                            });
                          }

                          /// this delay is required to show confirmation
                          await Future.delayed(const Duration(seconds: 5));
                          runnerRtDataProvider.fetchDataNow();
                          if (mounted) {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          }
                        } else {
                          isError = true;
                        }
                        if (mounted) {
                          bottomSheetSetState(() {
                            loading = false;
                          });
                        }
                      },
                child: Text(languageProvider.getMessage("submit", 'Submit')),
              ),
            ),
            if (_showInSheetNoOtp)
              Container(
                width: double.infinity,
                height: 47.h,
                margin: EdgeInsets.only(top: 12.h),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xff111827)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: loading
                      ? null
                      : () {
                          JobLifecycleAnalytics.logEvent(
                              TrackingEvents.checkInWithoutOtpBtnClicked, {});
                          // Pop with a signal; the OTP sheet's .then opens the
                          // No-OTP sheet after this one finishes closing, so the
                          // two sheets never overlap mid-animation.
                          Navigator.of(context).pop(true);
                        },
                  child: Text(
                    languageProvider.getMessage("no_otp", "No OTP"),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                  ),
                ),
              ),
            // SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  /// Check-in label + optional gamification pill from [ctaOverrideMap] (`check_in`).
  Widget _checkInPrimaryLabel(BuildContext context,
      {String? label, Color? color}) {
    final checkInCta = runnerRtDataProvider.ctaOverrideMap['check_in'];
    final showBadge = checkInCta != null &&
        (checkInCta.hasCoinBadge || checkInCta.hasRedCardBadge);
    final text = Text(
      label ??
          languageProvider.getMessage(
            "check_in_with_otp",
            "Check in with OTP",
          ),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
    );
    if (!showBadge) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        SizedBox(width: 8.w),
        CtaBadgeChip(cta: checkInCta),
      ],
    );
  }

  /// Gate 2: when shield consent + auto-recording are both active, mic must be
  /// granted before the OTP modal opens. Shows a non-dismissible dialog if not.
  Future<bool> _checkShieldMicBeforeCheckIn() async {
    final consentEnabled =
        widget.widgetData?['snabbit_shield_consent_enabled'] == true;
    final autoEnabled =
        widget.widgetData?['snabbit_shield_auto_enabled'] == true;
    if (!consentEnabled || !autoEnabled) return true;

    final micStatus = await Permission.microphone.status;
    if (micStatus.isGranted) return true;

    if (!mounted) return false;
    return ShieldPermissionHandler.showPermissionDialog(
      context,
      isPermanentlyDenied: micStatus.isPermanentlyDenied,
      permissionContext: ShieldPermissionContext.micOnly,
      hardGate: true,
    );
  }

  void _openOtpModal(BuildContext context) {
    // The runner acted on the check-in prompt — stop the delayed-check-in alarm
    // now instead of letting it run out its repeat count. Fire-and-forget so
    // the sheet still opens immediately if the audio plugin is slow.
    unawaited(AlarmSilencer.silence());
    final payout =
        (runnerRtDataProvider.widgetInfo?.data?['payout_info'] as Map?)
                ?.cast<String, dynamic>() ??
            const {};
    JobLifecycleAnalytics.logEvent(TrackingEvents.checkInCtaClick, {
      'minutes_early_or_late': payout['check_in_mins'],
      'is_past_checkin': payout['is_past_checkin'] == true,
      'check_in_earning_amount': payout['check_in_amount'],
    });
    if (widget.shouldPopFirst == true) {
      Navigator.pop(context);
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) {
        return Consumer<RunnerRtDataProvider>(
            builder: (context, runnerRtDataProvider, child) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter bottomSheetSetState) {
            return SafeArea(
              bottom: true,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: DraggableScrollableSheet(
                  initialChildSize: 0.3.h,
                  minChildSize: 0.3.h,
                  maxChildSize: 0.3.h,
                  expand: false,
                  builder: (ctx, scrollController) {
                    return !runnerRtDataProvider.waitForFetchData
                        ? otpDialog(
                            ctx, bottomSheetSetState, runnerRtDataProvider)
                        : Column(
                            children: [
                              Expanded(
                                  child: SingleChildScrollView(
                                      child: CheckInConfirmed())),
                              LowBatteryWarning(
                                margin:
                                    EdgeInsets.fromLTRB(36.w, 22.h, 36.w, 20.h),
                              ),
                            ],
                          );
                  },
                ),
              ),
            );
          });
        });
      },
    ).then((val) {
      otpTextController.clear();
      isError = false;
    });
  }

  Widget _delayedCheckinButtonBar(BuildContext context) {
    return Container(
      color: AppColors.n0,
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 36.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.g40),
              onPressed: () async {
                if (!await _checkShieldMicBeforeCheckIn()) return;
                if (!mounted) return;
                _openOtpModal(this.context);
                await ClevertapSetup.logEvent(
                  TrackingEvents.runnerCheckedIn,
                  {"action": "runner check in button clicked"},
                );
              },
              child: Text(languageProvider.getMessage('check_in', 'Check In')),
            ),
          ),
          SizedBox(height: 12.h),
          SweepingShine(
            // ClipRRect inside SweepingShine rounds the fill to this radius,
            // so the Container itself doesn't repeat it.
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: AppColors.n90),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.n90),
                  // White foreground so the press ripple is visible on the
                  // navy fill (icon/text set their own colour below).
                  foregroundColor: AppColors.n0,
                ),
                onPressed: () => JobSupportBottomSheet.show(
                  this.context,
                  languageProvider: languageProvider,
                  widgetData: widget.widgetData,
                  widgetName: widget.widgetName,
                  runnerId: Provider.of<UserProfileProvider>(
                        this.context,
                        listen: false,
                      ).user?.id ??
                      -1,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call, size: 20.r, color: AppColors.n0),
                    SizedBox(width: 8.w),
                    Text(
                      languageProvider.getMessage('help', 'Help'),
                      style: TextStyle(color: AppColors.n0),
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

  @override
  Widget build(BuildContext context) {
    final dcData = runnerRtDataProvider.delayedCheckinData;
    if (dcData != null) {
      return _delayedCheckinButtonBar(context);
    }
    return Container(
      color: AppColors.n0,
      padding: EdgeInsets.symmetric(
        vertical: 16.h,
        horizontal: 36.w,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.widgetName == "RUNNER_JOB_POST_ACCEPT" &&
                              !markArrivalBtnEnabled
                          ? Colors.grey
                          : widget.bgColor,
                ),
                onPressed: widget.widgetName == "RUNNER_JOB_POST_ACCEPT"
                    ? markArrivalBtnEnabled
                        ? () async {
                            JobLifecycleAnalytics.logEvent(
                                TrackingEvents.markArrivalCtaClick, {
                              'gps_accuracy_m': currentPosition?.accuracy,
                              'start_time': widget.widgetData?['start_time'],
                              'checkin_promise':
                                  widget.widgetData?['checkin_promise'],
                            });
                            Response? response =
                                await JobHttp.checkArrival(data: {
                              "job_id": runnerRtDataProvider.jobId ?? -1,
                            });
                            if (response?.statusCode == 200) {
                              runnerRtDataProvider.fetchDataNow();
                            } else {
                              if (mounted) {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (BuildContext context) =>
                                        const SelfieForLogin(
                                            isForMarkArrival: true)));
                              }
                            }

                            JobLifecycleAnalytics.logEvent(
                                TrackingEvents.markArrivalButtonClicked, {
                              "action": "mark arrival button clicked",
                            });
                          }
                        : null
                    : () async {
                        final payout = (runnerRtDataProvider
                                    .widgetInfo?.data?['payout_info'] as Map?)
                                ?.cast<String, dynamic>() ??
                            const {};
                        JobLifecycleAnalytics.logEvent(
                            TrackingEvents.checkInCtaClick, {
                          'minutes_early_or_late': payout['check_in_mins'],
                          'is_past_checkin': payout['is_past_checkin'] == true,
                          'check_in_earning_amount': payout['check_in_amount'],
                        });
                        if (widget.shouldPopFirst == true) {
                          Navigator.pop(context);
                        }
                        // The No-OTP affordance now lives inside this sheet, so
                        // log its display here (the inline button can't use
                        // initState like the standalone CheckInWithoutOtpButton).
                        if (_showInSheetNoOtp) {
                          JobLifecycleAnalytics.logEvent(
                              TrackingEvents.checkInWithoutOtpBtnDisplayed, {});
                        }
                        if (!await _checkShieldMicBeforeCheckIn()) return;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          enableDrag: false,
                          builder: (context) {
                            return Consumer<RunnerRtDataProvider>(builder:
                                (context, runnerRtDataProvider, child) {
                              return StatefulBuilder(builder:
                                  (BuildContext context,
                                      StateSetter bottomSheetSetState) {
                                return SafeArea(
                                  bottom: true,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      bottom: MediaQuery.of(context)
                                          .viewInsets
                                          .bottom,
                                    ),
                                    child: DraggableScrollableSheet(
                                      initialChildSize:
                                          _isMarkArrivalDisabledFlow
                                              ? 0.42
                                              : 0.3,
                                      minChildSize: _isMarkArrivalDisabledFlow
                                          ? 0.42
                                          : 0.3,
                                      maxChildSize: _isMarkArrivalDisabledFlow
                                          ? 0.42
                                          : 0.3,
                                      expand: false,
                                      builder: (ctx, scrollController) {
                                        return !runnerRtDataProvider
                                                .waitForFetchData
                                            ? otpDialog(
                                                ctx,
                                                bottomSheetSetState,
                                                runnerRtDataProvider)
                                            : Column(
                                                children: [
                                                  Expanded(
                                                      child: SingleChildScrollView(
                                                          child:
                                                              CheckInConfirmed())),
                                                  LowBatteryWarning(
                                                    margin: EdgeInsets.fromLTRB(
                                                        36.w, 22.h, 36.w, 20.h),
                                                  ),
                                                ],
                                              );
                                      },
                                    ),
                                  ),
                                );
                              });
                            });
                          },
                        ).then((openNoOtp) {
                          otpTextController.clear();
                          isError = false;
                          JobLifecycleAnalytics.logEvent(
                              TrackingEvents.checkInOtpModalDismissed,
                              const {});
                          // The No-OTP button (inside the sheet) pops with
                          // `true`; open its sheet only once the OTP sheet has
                          // fully closed.
                          if (openNoOtp == true && mounted) {
                            showCheckInWithoutOtpBottomSheet(this.context);
                          }
                        });

                        JobLifecycleAnalytics.logEvent(
                            TrackingEvents.runnerCheckedIn, {
                          "action": "runner check in button clicked",
                        });
                      },
                child: FittedBox(
                  child: widget.widgetName == "RUNNER_JOB_POST_ACCEPT"
                      ? Text(
                          languageProvider.getMessage(
                              "mark_arrival", "Mark arrival"),
                        )
                      : _isMarkArrivalDisabledFlow
                          ? _checkInPrimaryLabel(
                              context,
                              label: languageProvider.getMessage(
                                  "check_in", "Check In"),
                              color: AppColors.n0,
                            )
                          : _checkInPrimaryLabel(context),
                ),
              ),
            ),
          ),
          if (widget.widgetData?['allow_check_in_without_otp'] == true &&
              !_isMarkArrivalDisabledFlow)
            Flexible(child: CheckInWithoutOtpButton())
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}

class TimerFromUtc extends StatefulWidget {
  final String? utcTimestamp;
  final TextStyle? textStyle;
  final TextStyle? zeroTextStyle;

  const TimerFromUtc({
    super.key,
    this.utcTimestamp,
    this.textStyle,
    this.zeroTextStyle,
  });

  @override
  State<TimerFromUtc> createState() => _TimerFromUtcState();
}

class _TimerFromUtcState extends State<TimerFromUtc> {
  bool init = true;
  late Timer _timer;
  late DateTime _targetTime;
  int _secondsRemaining = 0;
  bool _isTimerFinished = false;
  late LanguageProvider languageProvider;

  @override
  void initState() {
    super.initState();
    try {
      _targetTime = DateTime.parse(widget.utcTimestamp!);
      _updateRemainingTime();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateRemainingTime();
      });
    } catch (e) {
      _isTimerFinished = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
  }

  void _updateRemainingTime() {
    final now = DateTime.now().toUtc();
    _secondsRemaining = _targetTime.difference(now).inSeconds;

    if (_secondsRemaining <= 0 && !_isTimerFinished) {
      setState(() {
        _isTimerFinished = true;
      });
    } else {
      setState(() {});
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

  @override
  Widget build(BuildContext context) {
    if (_isTimerFinished) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timelapse_rounded),
          SizedBox(width: 6.w),
          Text(
            languageProvider.getMessage('checkin_now', 'Check-in now!'),
            style: widget.textStyle ??
                Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 16.sp),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timelapse_rounded),
            SizedBox(width: 6.w),
            Text(
              languageProvider.getMessage('checkin_within', 'Check-in within'),
              style: widget.textStyle ??
                  Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontSize: 16.sp),
            ),
          ],
        ),
        Text(
          _formatTime(_secondsRemaining),
          style: Theme.of(context)
              .textTheme
              .displayLarge
              ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.n90),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
