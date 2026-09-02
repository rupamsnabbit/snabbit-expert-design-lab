import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:format/format.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/gamification/cta_override.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/analytics/job_lifecycle_analytics.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/gamification/cta_badge.dart';
import 'package:snabbit_runner/widgets/gamification/nudge_banner.dart';
import 'package:snabbit_runner/widgets/attendance_flow/custom_timer.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/common_widgets/job_duration_pill.dart';
import 'package:snabbit_runner/widgets/job_start_flow/warning_below_timer.dart';
import 'package:snabbit_runner/widgets/map_job_location.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';
import 'package:vibration/vibration.dart';

import '../../constants/assets_constants.dart';
import '../../main.dart';
import '../../providers/runner_rt_data.dart';

import '../../services/file_ops.dart';
import '../../services/notification_service.dart';
import '../../services/remote_config/remote_config_assets.dart';
import '../../utils/colors.dart';

import '../attendance_flow/attendance_confirmed.dart';
import 'package:snabbit_runner/models/payout/payout_info.dart';
import '../common_widgets/job_payout_card.dart';
import '../elevated_button_with_loader.dart';

class NewJobAssigned extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const NewJobAssigned({
    super.key,
    this.widgetData,
  });

  @override
  State<NewJobAssigned> createState() => _NewJobAssignedState();
}

class _NewJobAssignedState extends State<NewJobAssigned>
    with SingleTickerProviderStateMixin {
  bool init = true;
  bool loading = true;
  bool _acceptButtonViewedTracked = false;

  final FlutterTts flutterTts = FlutterTts();
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late AnimationController _animationController;
  late Animation<double> _animation;
  Color acceptButtonFg = AppColors.g50;
  Color acceptButtonBg = AppColors.g30;
  Color acceptButtonTextColor = AppColors.n0;
  String acceptButtonTextKey = 'accept_job';
  DateTime startTimeUtc = DateTime.now().toUtc();
  int timerDuration = 120;
  WarningState _state = WarningState.green;

  Future<void> initProcess() async {}

  Future<void> _speakAddress() async {
    final address =
        "${widget.widgetData!["address"] ?? ""}\n${widget.widgetData!["geo_address"] ?? ""}";
    await flutterTts.speak(address);

    await ClevertapSetup.logEvent(TrackingEvents.speakAddressButtonClicked, {
      "action": "speak address button click",
    });
  }

  Future<void> setLanguage() async {
    await flutterTts.setLanguage("hi-IN");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      try {
        startTimeUtc = (DateTime.tryParse(
                    runnerRtDataProvider.widgetInfo?.data?['notified_at'] ??
                        "") ??
                DateTime.now())
            .toUtc();
        timerDuration =
            runnerRtDataProvider.widgetInfo?.data?['timer_duration'] ?? 120;
      } catch (e) {
        // DO NOTHING
      }
      _trackNewJobAssignedLoad();
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }

    if (runnerRtDataProvider.widgetUtil?.bottomButton == null &&
        runnerRtDataProvider.waitForFetchData == false) {
      Future(() {
        if (mounted && runnerRtDataProvider.waitForFetchData == false) {
          runnerRtDataProvider.updateBottomButtonJobProgress(
            Container(
              decoration: const BoxDecoration(
                color: AppColors.n0,
              ),
              padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 24.h),
              child: acceptJob,
            ),
          );
        }
      });
    }
  }

  int get _jobDurationInMins {
    try {
      final data = runnerRtDataProvider.widgetInfo?.data;
      final startTime = data?['start_time']?.toString();
      final endTime = data?['end_time']?.toString();
      final durationMins =
          jobDurationMinutesFromStartEnd(startTime, endTime) ?? 0;
      return durationMins;
    } catch (e) {
      return 0;
    }
  }

  bool get _showJobDuration =>
      _jobDurationInMins == 30 || _jobDurationInMins == 45;

  Future<void> _stopAudio() async {
    await FileStorage.writeState('stopped');
    await NotificationService.instance.cancelAll();
    await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.stop);
    await GlobalState().audioPlayer.stop();
  }

  Future<void> playSound() async {
    try {
      if (runnerRtDataProvider.widgetInfo?.data?['play_sound_fg'] == true &&
          GlobalState().audioPlayer.state != PlayerState.playing) {
        setMaxVolume();
        await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.loop);
        await GlobalState()
            .audioPlayer
            .play(AssetSource('custom_sound.wav'), volume: desiredVolume);
      }
    } catch (e) {
      // DO NOTHING
    }
  }

  @override
  void initState() {
    super.initState();
    setLanguage();

    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _animation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    // _stopAudio();
    // try {
    //   GlobalState().audioPlayer.setReleaseMode(ReleaseMode.stop);
    //   GlobalState().audioPlayer.stop();
    // } catch (e) {
    //   // DO NOTHING
    // }
    super.dispose();
  }

  /// Logout + Accept in deny sheet when widget `is_last_hour_job` is true.
  bool get lastHourJob =>
      runnerRtDataProvider.widgetInfo?.data?['is_last_hour_job'] == true;

  bool get _showDeallocationWarning =>
      runnerRtDataProvider.widgetInfo?.data?["show_deallocation_warning"] ==
          true &&
      !lastHourJob;

  Widget get acceptJob {
    if (runnerRtDataProvider.waitForFetchData == false) {
      if (!_acceptButtonViewedTracked) {
        _acceptButtonViewedTracked = true;
        MixpanelSetup.logEvent(TrackingEvents.acceptJobButtonViewed, {
          'job_id':
              widget.widgetData?['runner_job_id'] ?? runnerRtDataProvider.jobId,
        });
      }
      return Row(
        children: [
          if (runnerRtDataProvider.widgetInfo?.data?["is_deniable"] == true)
            Expanded(
              child: Container(
                padding: EdgeInsets.only(right: 16.w),
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showDenialConfirmation(
                      lastHourJob ? DenyVariant.lastHour : DenyVariant.generic),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.r40,
                    side: const BorderSide(color: AppColors.r40),
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      "deny",
                      "Deny",
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: _acceptJob,
              child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return SizedBox(
                      height: 46.h,
                      child: Stack(
                        children: [
                          // Red background (will be revealed as green overlay shrinks)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              color: acceptButtonBg,
                            ),
                          ),
                          // Green overlay that shrinks from right to left
                          FractionallySizedBox(
                            widthFactor: 1.0 -
                                _animation
                                    .value, // Shrinks as animation progresses
                            heightFactor: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.r),
                                color: acceptButtonFg,
                              ),
                            ),
                          ),
                          // Text (centered)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _acceptJobLabelWithOptionalCtaBadge(
                                  context,
                                  acceptCta: runnerRtDataProvider
                                      .ctaOverrideMap['accept_job'],
                                  acceptButtonTextKey: acceptButtonTextKey,
                                  acceptButtonTextColor: acceptButtonTextColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox();
    }
  }

  void _acceptJob() async {
    _trackAcceptJobCtaClick();
    runnerRtDataProvider.setWaitForFetchData(true);
    try { MonitoringServiceHelper.logInfo('expert_job_action', {'step': 'accept_start', 'job_id': runnerRtDataProvider.jobId}); } catch (_) {}

    final response = await JobHttp.acceptJob(data: {
      "job_id": runnerRtDataProvider.jobId ?? -1,
    });
    if (!mounted) return;
    try { MonitoringServiceHelper.logInfo('expert_job_action', {'step': 'accept_response', 'status_code': response?.statusCode, 'job_id': runnerRtDataProvider.jobId}); } catch (_) {}
    if (response != null && response.statusCode == 200) {
      _stopAudio();
      try {
        await PostActionOverlayController.instance
            .showFromResponse(response.data, LifecycleActionType.longDistance);
      } catch (_) {}
    } else {
      if (response?.statusCode == 409) {
        _stopAudio();
        try { MonitoringServiceHelper.logWarning('expert_job_action', {'step': 'accept_409_deallocated', 'job_id': runnerRtDataProvider.jobId}); } catch (_) {}
        showSnackbar(
            context, languageProvider.getMessage('job_reassigned', 'This job has been reassigned to another expert.'));
      } else {
        showSnackbar(
          context,
          "${response?.data ?? "Something went wrong. Please try again!"}",
        );
      }
    }
    if (!mounted) return;
    try { MonitoringServiceHelper.logInfo('expert_job_action', {'step': 'accept_fetch_data_now', 'job_id': runnerRtDataProvider.jobId}); } catch (_) {}
    await runnerRtDataProvider.fetchDataNow();
    if (!mounted) return;
    await ClevertapSetup.logEvent(TrackingEvents.acceptJobButtonClicked, {
      "action": "accept job button click",
    });
  }

  void _trackNewJobAssignedLoad() {
    final data = runnerRtDataProvider.widgetInfo?.data ?? const {};
    final payout =
        (data['payout_info'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Mark the active job so subsequent lifecycle events automatically
    // pick up job_id / customer_id without each call site repeating it.
    JobLifecycleAnalytics.setActiveJob(
      jobId: widget.widgetData?['runner_job_id'] ?? runnerRtDataProvider.jobId,
      customerId: data['customer_id'],
    );
    JobLifecycleAnalytics.logEvent(TrackingEvents.newJobAssignedLoad, {
      'accept_timer_duration_sec': timerDuration,
      'is_last_hour_job': data['is_last_hour_job'] == true,
      'is_long_distance': data['is_long_distance'] == true,
      'is_ot_job': data['is_ot'] == true,
      'deniable': data['is_deniable'] == true,
      'total_earning': payout['total_earning'],
      'work_earning': payout['work_amount'],
      'work_duration_mins': payout['work_duration_mins'],
      'ot_earning': payout['ot_amount'],
      'ot_duration_mins': payout['ot_duration_mins'],
      'long_distance_earning': payout['long_distance_amount'],
      'long_distance_km': payout['long_distance_km'],
      'checkin_earning': payout['check_in_amount'],
      'checkin_time_shown': payout['check_in_time'],
    });
  }

  void _trackAcceptJobCtaClick() {
    final now = DateTime.now().toUtc();
    final timeToAccept = now.difference(startTimeUtc).inSeconds;
    final timeRemaining =
        (timerDuration - timeToAccept).clamp(0, timerDuration);
    JobLifecycleAnalytics.logEvent(TrackingEvents.acceptJobCtaClick, {
      'time_to_accept_sec': timeToAccept,
      'time_remaining_sec': timeRemaining,
    });
  }

  void _showDenialConfirmation(DenyVariant variant) {
    if (!mounted) return;
    final data = runnerRtDataProvider.widgetInfo?.data ?? const {};
    final denyType = _denyTypeFor(variant, data);
    final now = DateTime.now().toUtc();
    final timeRemaining =
        (timerDuration - now.difference(startTimeUtc).inSeconds)
            .clamp(0, timerDuration);
    final payout =
        (data['payout_info'] as Map?)?.cast<String, dynamic>() ?? const {};
    JobLifecycleAnalytics.logEvent(TrackingEvents.denyJobCtaClick, {
      'time_remaining_sec': timeRemaining,
      'total_earning': payout['total_earning'],
      'deny_type': denyType,
    });
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return CommonBottomSheetSetup(
          backgroundImageUrl: kNudgesBottomSheetBackgroundUrl,
          child: DenialConfirmation(variant: variant, denyType: denyType),
        );
      },
    );
  }

  /// CSV expects `last_hour | long_distance | ot`. Code only has
  /// `lastHour` vs `generic`, so we derive the generic case from the
  /// data flags. Priority: last_hour → long_distance → ot → other.
  String _denyTypeFor(DenyVariant variant, Map<String, dynamic> data) {
    if (variant == DenyVariant.lastHour || data['is_last_hour_job'] == true) {
      return 'last_hour';
    }
    if (data['is_long_distance'] == true) return 'long_distance';
    if (data['is_ot'] == true) return 'ot';
    return 'other';
  }

  /// Parses 12-hour time strings like "05:45 pm" and returns duration in minutes.
  /// Returns [null] if parsing fails or inputs are null/empty; caller can use fallback (e.g. 0).
  /// Accept Job label + optional gamification pill from [ctaOverrideMap] (`accept_job`).
  Widget _acceptJobLabelWithOptionalCtaBadge(
    BuildContext context, {
    required CtaOverride? acceptCta,
    required String acceptButtonTextKey,
    required Color acceptButtonTextColor,
  }) {
    final cta = acceptCta;
    final showBadge = cta != null && (cta.hasCoinBadge || cta.hasRedCardBadge);
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: acceptButtonTextColor,
          fontWeight: FontWeight.w600,
        );
    if (!showBadge) {
      return Text(
        languageProvider.getMessage(
          acceptButtonTextKey,
          "Accept Job",
        ),
        style: textStyle,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          languageProvider.getMessage(
            acceptButtonTextKey,
            "Accept Job",
          ),
          style: textStyle,
        ),
        SizedBox(width: 8.w),
        CtaBadgeChip(cta: cta),
      ],
    );
  }

  int? jobDurationMinutesFromStartEnd(String? startTime, String? endTime) {
    if (startTime == null ||
        endTime == null ||
        startTime.trim().isEmpty ||
        endTime.trim().isEmpty) {
      return null;
    }
    final format = DateFormat("h:mm a");
    try {
      final start = format.parse(startTime.trim().toUpperCase());
      final end = format.parse(endTime.trim().toUpperCase());
      var startDt = DateTime(2000, 1, 1, start.hour, start.minute);
      var endDt = DateTime(2000, 1, 1, end.hour, end.minute);
      var diff = endDt.difference(startDt).inMinutes;
      // Same-day: if end < start, assume next day (e.g. 11 pm -> 1 am)
      if (diff < 0) diff += 24 * 60;
      return diff;
    } catch (e) {
      //add coralogix log through MonitoringServiceHelper
      MonitoringServiceHelper.logError(
        'ERROR_PARSING_JOB_DURATION',
        {
          'job_id': runnerRtDataProvider.jobId,
          'start_time': startTime,
          'end_time': endTime,
          'error': e.toString(),
        },
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.widgetData == null
        ? Container()
        : runnerRtDataProvider.waitForFetchData
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                  if (runnerRtDataProvider.widgetInfo?.data?["is_ot"] == true &&
                      (runnerRtDataProvider.widgetInfo?.data?["ot_amount"] ??
                              0) >
                          0)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: AmountBanner(
                        // bottomPrefix: runnerRtDataProvider
                        //             .widgetInfo?.data?["ot_mins"] !=
                        //         null
                        //     ? '${minsToHours(runnerRtDataProvider.widgetInfo?.data?["ot_mins"])} ${languageProvider.getMessage(
                        //         'hours',
                        //         'Hours',
                        //       )}'
                        //     : null,
                        prefixIconSize: 80.w,
                        valueBoxSize: 110.w,
                        image: AssetConstants.otBanner,
                        amount: anyValueToInt(runnerRtDataProvider
                                .widgetInfo?.data?["ot_amount"]) ??
                            0,
                        title: Text(
                          languageProvider.getMessage(
                            "bonus_capital",
                            "BONUS",
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
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
                  if (runnerRtDataProvider
                              .widgetInfo?.data?["is_long_distance"] ==
                          true &&
                      (runnerRtDataProvider
                                  .widgetInfo?.data?["long_distance_amount"] ??
                              0) >
                          0)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: AmountBanner(
                        prefixIconSize: 80.w,
                        valueBoxSize: 110.w,
                        image: AssetConstants.longDistanceBanner,
                        amount: anyValueToInt(runnerRtDataProvider
                                .widgetInfo?.data?["long_distance_amount"]) ??
                            0,
                        title: Text(
                          languageProvider.getMessage(
                            "long_distance_capital",
                            "LONG\nDISTANCE\nBONUS",
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
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
                  if (runnerRtDataProvider.widgetInfo?.data?["is_time_pe"] ==
                          true &&
                      (runnerRtDataProvider
                                  .widgetInfo?.data?["time_pe_amount"] ??
                              0) >
                          0)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: AmountBanner(
                        prefixIconSize: 80.w,
                        valueBoxSize: 110.w,
                        amount: anyValueToInt(runnerRtDataProvider
                                .widgetInfo?.data?["time_pe_amount"]) ??
                            0,
                        title: Text(
                          languageProvider.getMessage(
                            "bonus_capital",
                            "BONUS",
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
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
                  if (runnerRtDataProvider.widgetInfo?.data?["is_time_pe"] ==
                          true &&
                      (runnerRtDataProvider
                                  .widgetInfo?.data?["time_pe_amount"] ??
                              0) >
                          0)
                    SizedBox(height: 28.h),
                  AlertNotification(
                    text: languageProvider.getMessage(
                      "new_job_assigned",
                      "New job assigned",
                    ),
                  ),
                  if (_showJobDuration)
                    Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: JobDurationPill(duration: _jobDurationInMins),
                    ),
                  SizedBox(height: 22.h),
                  CircularTimerWidget(
                    persistDuration: true,
                    showLateBlinking: true,
                    width: 124,
                    height: 124,
                    sharedPrefsKeyPrefix:
                        'job_accept_${widget.widgetData?['runner_job_id'] ?? runnerRtDataProvider.jobId}',
                    utcTimeString: DateFormat('HH:mm:ss').format(
                      startTimeUtc.add(Duration(seconds: timerDuration)),
                    ),
                    backgroundColor: acceptButtonBg,
                    lateBackgroundColor: AppColors.r20,
                    labelTextColor: acceptButtonFg,
                    lateTextColor: AppColors.r50,
                    labelText: languageProvider.getMessage(
                      'accept_job_cap',
                      'ACCEPT JOB',
                    ),
                    lateText: languageProvider.getMessage(
                      'accept_now_cap',
                      'ACCEPT NOW',
                    ),
                    tickCallback: (int remainingSeconds) {
                      playSound();
                      setState(() {
                        if (remainingSeconds < timerDuration / 3) {
                          acceptButtonFg = AppColors.r40;
                          acceptButtonBg = AppColors.r30;
                          acceptButtonTextColor = AppColors.n0;
                          acceptButtonTextKey = 'accept_now_cap';
                          _state = WarningState.red;
                        } else if (remainingSeconds < 2 * timerDuration / 3) {
                          acceptButtonFg = AppColors.y40;
                          acceptButtonBg = AppColors.y10;
                          acceptButtonTextColor = AppColors.y60;
                          _state = WarningState.yellow;
                        }
                        // Calculate the new target value (0.0 to 1.0)
                        double targetValue = remainingSeconds <= 0
                            ? 0.0
                            : remainingSeconds / timerDuration;

                        // If the timer is done, ensure we show full red
                        if (remainingSeconds <= 0) {
                          _animationController.value =
                              1.0; // Full animation (red)
                        } else {
                          // Animate from current value to the new target
                          _animationController.animateTo(
                            1.0 - targetValue,
                            // Invert because animation goes from 1.0 to 0.0
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    },
                  ),
                  SizedBox(height: 24.h),
                  if (_showDeallocationWarning)
                    WarningBelowTimer(
                      warningState: _state,
                    ),
                  if (runnerRtDataProvider.widgetInfo?.data?['payout_info'] !=
                      null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: JobPayoutCard(
                        payoutInfo: PayoutInfo.fromDynamic(runnerRtDataProvider
                            .widgetInfo?.data?['payout_info']),
                        headerText: languageProvider.getMessage(
                            'you_will_earn', 'You Will Earn'),
                      ),
                    ),
                  if (runnerRtDataProvider.preActionNudges.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: NudgeBannerList(
                        nudges: runnerRtDataProvider.preActionNudges,
                      ),
                    ),
                  SizedBox(
                    width: 1.sw,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_pin,
                          color: AppColors.n80,
                        ),
                        SizedBox(width: 5.w),
                        Flexible(
                          child: Text(
                            "${widget.widgetData?["address"] ?? ""} ${runnerRtDataProvider.widgetInfo?.data?["is_long_distance"] == true ? (widget.widgetData?["geo_address"] ?? "") : ""}",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (runnerRtDataProvider.widgetInfo?.data?["is_ot"] == true)
                    Container(
                      width: 1.sw,
                      padding: EdgeInsets.only(top: 13.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: AppColors.n80,
                          ),
                          SizedBox(width: 5.w),
                          Flexible(
                            child: Text(
                              "${languageProvider.getMessage('job_end_time', 'Job end time - ')} ${widget.widgetData?["job_end_time"] ?? ""}",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // SizedBox(height: 30.h),
                ],
              );
  }
}

class AlertNotification extends StatelessWidget {
  final String text;

  const AlertNotification({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.notifications_rounded,
          color: AppColors.n90,
        ),
        SizedBox(width: 11.w),
        Text(
          text,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }
}

/// [lastHour]: `is_last_hour_job` — Logout (left) + Accept.
/// [longDistance]: not last hour — Deny (left) + Accept.
enum DenyVariant {
  lastHour,
  generic,
}

class DenialConfirmation extends StatefulWidget {
  const DenialConfirmation({
    super.key,
    required this.variant,
    required this.denyType,
  });

  final DenyVariant variant;
  final String denyType;

  @override
  State<DenialConfirmation> createState() => _DenialConfirmationState();
}

class _DenialConfirmationState extends State<DenialConfirmation> {
  @override
  void initState() {
    super.initState();
    // Fire screen_load once when the bottom sheet first renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rt = context.read<RunnerRtDataProvider>();
      final data = rt.widgetInfo?.data ?? const {};
      final payout =
          (data['payout_info'] as Map?)?.cast<String, dynamic>() ?? const {};
      JobLifecycleAnalytics.logEvent(TrackingEvents.denyConfirmScreenLoad, {
        'is_last_hour_job': data['is_last_hour_job'] == true,
        'is_long_distance': data['is_long_distance'] == true,
        'deny_type': widget.denyType,
        'miss_earnings_amount': anyValueToInt(data['loss_amount']),
        'total_earning': payout['total_earning'],
        'work_earning': payout['work_amount'],
        'ot_earning': payout['ot_amount'],
        'long_distance_earning': payout['long_distance_amount'],
        'checkin_earning': payout['check_in_amount'],
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, languageProvider, _) {
      return Consumer<RunnerRtDataProvider>(
          builder: (context, runnerRtDataProvider, child) {
        final lossAmount = anyValueToInt(
            runnerRtDataProvider.widgetInfo?.data?['loss_amount']);
        return Column(
          children: [
            SizedBox(height: 24.h),
            SvgPicture.asset(
              AssetConstants.lossEarningCircleIcon,
              height: 100.h,
            ),
            SizedBox(height: 16.h),
            Text(
              languageProvider.getFormattedMessage(
                'denial_loss_earnings',
                'You will miss earnings of ₹{{loss_amount}}',
                {'loss_amount': lossAmount ?? 0},
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 24.sp,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 47.h,
                    child: _denyButton(
                      context,
                      languageProvider,
                      runnerRtDataProvider,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: SizedBox(
                    height: 47.h,
                    child: ElevatedButton(
                      onPressed: () async {
                        final data =
                            runnerRtDataProvider.widgetInfo?.data ?? const {};
                        final payout = (data['payout_info'] as Map?)
                                ?.cast<String, dynamic>() ??
                            const {};
                        JobLifecycleAnalytics.logEvent(
                            TrackingEvents.denyAcceptJobCtaClick, {
                          'total_earning': payout['total_earning'],
                          'miss_earnings_amount':
                              anyValueToInt(data['loss_amount']),
                          'deny_type': widget.denyType,
                        });
                        runnerRtDataProvider.setWaitForFetchData(true);
                        try { MonitoringServiceHelper.logInfo('expert_job_action', {'step': 'accept_start', 'job_id': runnerRtDataProvider.jobId, 'source': 'denial_accept'}); } catch (_) {}
                        final response = await JobHttp.acceptJob(data: {
                          "job_id": runnerRtDataProvider.jobId ?? -1,
                        });
                        if (!context.mounted) return;
                        try { MonitoringServiceHelper.logInfo('expert_job_action', {'step': 'accept_response', 'status_code': response?.statusCode, 'job_id': runnerRtDataProvider.jobId, 'source': 'denial_accept'}); } catch (_) {}
                        if (response != null && response.statusCode == 200) {
                          _stopAudio();
                          try {
                            await PostActionOverlayController.instance
                                .showFromResponse(response.data,
                                    LifecycleActionType.longDistance);
                          } catch (_) {}
                          if (!context.mounted) return;
                        } else {
                          if (response?.statusCode == 409) {
                            _stopAudio();
                            try { MonitoringServiceHelper.logWarning('expert_job_action', {'step': 'accept_409_deallocated', 'job_id': runnerRtDataProvider.jobId, 'source': 'denial_accept'}); } catch (_) {}
                            showSnackbar(context,
                                languageProvider.getMessage('job_reassigned', 'This job has been reassigned to another expert.'));
                          } else {
                            showSnackbar(
                              context,
                              "${response?.data ?? "Something went wrong. Please try again!"}",
                            );
                          }
                        }
                        await runnerRtDataProvider.fetchDataNow();
                        if (!context.mounted) return;
                        await ClevertapSetup.logEvent(
                            TrackingEvents.acceptJobButtonClicked, {
                          "action": "accept job button click",
                        });
                        if (!context.mounted) return;
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.g40,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        languageProvider.getMessage('accept_job', 'Accept Job'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
          ],
        );
      });
    });
  }

  Widget _denyButton(
    BuildContext context,
    LanguageProvider languageProvider,
    RunnerRtDataProvider runnerRtDataProvider,
  ) {
    final isLastHour = widget.variant == DenyVariant.lastHour;
    final label = isLastHour
        ? languageProvider.getMessage('logout', 'Logout')
        : languageProvider.getMessage('deny_job', 'Deny Job');

    Future<void> onTap() async {
      runnerRtDataProvider.setWaitForFetchData(true);
      try { MonitoringServiceHelper.logInfo('expert_job_action', {'step': 'deny_start', 'job_id': runnerRtDataProvider.jobId}); } catch (_) {}
      final response = await JobHttp.denyJob(data: {
        "job_id": runnerRtDataProvider.jobId ?? -1,
      });
      if (!context.mounted) return;
      try { MonitoringServiceHelper.logInfo('expert_job_action', {'step': 'deny_response', 'status_code': response?.statusCode, 'job_id': runnerRtDataProvider.jobId}); } catch (_) {}
      if (response != null && response.statusCode == 200) {
        _stopAudio();
        try {
          await PostActionOverlayController.instance
              .showFromResponse(response.data, LifecycleActionType.deallocation);
        } catch (_) {}
        if (!context.mounted) return;
      } else {
        if (response?.statusCode == 409) {
          _stopAudio();
          try { MonitoringServiceHelper.logWarning('expert_job_action', {'step': 'deny_409_deallocated', 'job_id': runnerRtDataProvider.jobId}); } catch (_) {}
          showSnackbar(
              context, languageProvider.getMessage('job_reassigned', 'This job has been reassigned to another expert.'));
        } else {
          showSnackbar(
            context,
            "${response?.data ?? "Something went wrong. Please try again!"}",
          );
        }
      }
      await ClevertapSetup.logEvent(TrackingEvents.denyJobButtonClicked, {
        "action": "deny job button click",
        "variant": widget.variant.name,
      });
      if (!context.mounted) return;
      await runnerRtDataProvider.fetchDataNow();
      if (!context.mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    if (isLastHour) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.r40,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.r40,
        side: const BorderSide(color: AppColors.r40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.r40,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _stopAudio() async {
    await FileStorage.writeState('stopped');
    await NotificationService.instance.cancelAll();
    await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.stop);
    await GlobalState().audioPlayer.stop();
  }
}
