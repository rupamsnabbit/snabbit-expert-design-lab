import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/gamification/cta_override.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
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
import 'package:snabbit_runner/widgets/job_start_flow/request_to_reject_job_v1.dart';
import 'package:snabbit_runner/widgets/job_start_flow/risk_reward_popup_v1.dart';
import 'package:snabbit_runner/widgets/job_start_flow/warning_below_timer.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';
import 'package:snabbit_runner/widgets/miscellaneous/dashed_vertical_line.dart';

import '../../constants/assets_constants.dart';
import '../../main.dart';
import '../../providers/runner_rt_data.dart';

import '../../services/file_ops.dart';
import '../../services/notification_service.dart';
import '../../utils/colors.dart';

import '../attendance_flow/attendance_confirmed.dart';
import 'package:snabbit_runner/models/payout/payout_info.dart';
import '../common_widgets/job_payout_card.dart';

class NewJobAssignedV1 extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const NewJobAssignedV1({
    super.key,
    this.widgetData,
  });

  @override
  State<NewJobAssignedV1> createState() => _NewJobAssignedV1State();
}

class _NewJobAssignedV1State extends State<NewJobAssignedV1>
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
              child: _showButtonsVertically ? acceptDenyJob : acceptJob,
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
    super.dispose();
  }

  bool get lastHourJob =>
      runnerRtDataProvider.widgetInfo?.data?["is_last_hour_job"] == true;

  bool get _showDeallocationWarning =>
      runnerRtDataProvider.widgetInfo?.data?["show_deallocation_warning"] ==
          true &&
      !lastHourJob;

  bool get _showButtonsVertically => _showDeallocationWarning || lastHourJob;

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
          if (runnerRtDataProvider.widgetInfo?.data?["is_deniable"] == true &&
              !_showButtonsVertically)
            Expanded(
              child: Container(
                padding: EdgeInsets.only(right: 16.w),
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _showDenialConfirmation,
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
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              color: acceptButtonBg,
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: 1.0 - _animation.value,
                            heightFactor: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.r),
                                color: acceptButtonFg,
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: lastHourJob
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsets.only(right: 6.w),
                                            child: Image.asset(
                                              AssetConstants.joiningBonusCoin,
                                              width: 34.r,
                                            ),
                                          ),
                                          Text(
                                            languageProvider.getMessage(
                                              acceptButtonTextKey,
                                              "Accept Job",
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: acceptButtonTextColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          Container(
                                              margin: EdgeInsets.symmetric(
                                                  horizontal: 6.w),
                                              child: CustomPaint(
                                                  size: const Size(1, 17),
                                                  painter:
                                                      DashedLineVerticalPainter(
                                                    color:
                                                        const Color(0xFFD6D6D6),
                                                    dashHeight: 2.5,
                                                    dashSpace: 3,
                                                  ))),
                                          Text(
                                            "${formatIndianCurrency(anyValueToInt(runnerRtDataProvider.widgetInfo?.data?['accept_rate']) ?? 0)} ",
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayMedium
                                                ?.copyWith(
                                                  color: acceptButtonTextColor,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          Text(
                                            languageProvider
                                                .getMessage(
                                                  "extra",
                                                  "EXTRA",
                                                )
                                                .toUpperCase(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: acceptButtonTextColor,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ],
                                      )
                                    : _acceptJobLabelWithOptionalCtaBadge(
                                        context,
                                        acceptCta: runnerRtDataProvider
                                            .ctaOverrideMap['accept_job'],
                                        acceptButtonTextKey:
                                            acceptButtonTextKey,
                                        acceptButtonTextColor:
                                            acceptButtonTextColor,
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

  Widget get acceptDenyJob {
    if (runnerRtDataProvider.waitForFetchData == false) {
      return Column(
        children: [
          acceptJob,
          if (lastHourJob)
            Container(
              margin: EdgeInsets.only(
                top: 16.h,
              ),
              width: 1.sw,
              child: OutlinedButton(
                onPressed: () async {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) {
                      return CommonBottomSheetSetup(
                        child: RiskRewardConfirmationV1(
                          animationController: _animationController,
                          animation: _animation,
                        ),
                      );
                    },
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.r40,
                  side: const BorderSide(color: AppColors.r40),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      languageProvider.getMessage(
                        "deny",
                        "Deny",
                      ),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.r50,
                          ),
                    ),
                    Container(
                        margin: EdgeInsets.symmetric(horizontal: 6.w),
                        child: CustomPaint(
                            size: const Size(1, 17),
                            painter: DashedLineVerticalPainter(
                              color: const Color(0xFFD6D6D6),
                              dashHeight: 2.5,
                              dashSpace: 3,
                            ))),
                    Text(
                      "${languageProvider.getMessage(
                        "lose",
                        "Lose",
                      )} ${formatIndianCurrency(anyValueToInt(runnerRtDataProvider.widgetInfo?.data?['deny_rate']))}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.r50,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else if (_showDeallocationWarning)
            RequestToRejectV1(
              onAcceptJobTap: _acceptJob,
              onRejectJobTap: _denyJob,
            ),
        ],
      );
    } else {
      return const SizedBox();
    }
  }

  void _acceptJob() async {
    runnerRtDataProvider.setWaitForFetchData(true);

    Response? response = await JobHttp.acceptJob(data: {
      "job_id": runnerRtDataProvider.jobId ?? -1,
    });
    if (response != null && response.statusCode == 200) {
      _stopAudio();
      await PostActionOverlayController.instance
          .showFromResponse(response.data, LifecycleActionType.longDistance);
    } else {
      if (context.mounted) {
        showSnackbar(
          context,
          "${response?.data ?? "Something went wrong. Please try again!"}",
        );
      }
    }
    await runnerRtDataProvider.fetchDataNow();

    await ClevertapSetup.logEvent(TrackingEvents.acceptJobButtonClicked, {
      "action": "accept job button click",
    });
  }

  void _denyJob() async {
    runnerRtDataProvider.setWaitForFetchData(true);
    Response? response = await JobHttp.denyJob(data: {
      "job_id": runnerRtDataProvider.jobId ?? -1,
    });
    if (response != null && response.statusCode == 200) {
      _stopAudio();
      await PostActionOverlayController.instance
          .showFromResponse(response.data, LifecycleActionType.deallocation);
    } else {
      if (context.mounted) {
        showSnackbar(
          context,
          "${response?.data ?? "Something went wrong. Please try again!"}",
        );
      }
    }
    ClevertapSetup.logEvent(TrackingEvents.denyJobButtonClicked, {
      "action": "deny job button click",
    });
    runnerRtDataProvider.fetchDataNow();
  }

  void _showDenialConfirmation() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return const CommonBottomSheetSetup(
          backgroundImageUrl: kNudgesBottomSheetBackgroundUrl,
          child: DenialConfirmationV1(),
        );
      },
    );
  }

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
      if (diff < 0) diff += 24 * 60;
      return diff;
    } catch (e) {
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
                  AlertNotificationV1(
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
                        double targetValue = remainingSeconds <= 0
                            ? 0.0
                            : remainingSeconds / timerDuration;

                        if (remainingSeconds <= 0) {
                          _animationController.value = 1.0;
                        } else {
                          _animationController.animateTo(
                            1.0 - targetValue,
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
                ],
              );
  }
}

class AlertNotificationV1 extends StatelessWidget {
  final String text;

  const AlertNotificationV1({
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

class DenialConfirmationV1 extends StatelessWidget {
  const DenialConfirmationV1({super.key});

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
                {'loss_amount': lossAmount},
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
                    child: ElevatedButton(
                      onPressed: () async {
                        runnerRtDataProvider.setWaitForFetchData(true);
                        Response? response = await JobHttp.denyJob(data: {
                          "job_id": runnerRtDataProvider.jobId ?? -1,
                        });
                        if (response != null && response.statusCode == 200) {
                          _stopAudio();
                          await PostActionOverlayController.instance
                              .showFromResponse(
                                  response.data, LifecycleActionType.deallocation);
                        } else {
                          if (context.mounted) {
                            showSnackbar(
                              context,
                              "${response?.data ?? "Something went wrong. Please try again!"}",
                            );
                          }
                        }
                        ClevertapSetup.logEvent(
                            TrackingEvents.denyJobButtonClicked, {
                          "action": "deny job button click",
                        });
                        runnerRtDataProvider.fetchDataNow();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.r40,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        languageProvider.getMessage('logout', 'Logout'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: SizedBox(
                    height: 47.h,
                    child: ElevatedButton(
                      onPressed: () async {
                        runnerRtDataProvider.setWaitForFetchData(true);
                        Response? response = await JobHttp.acceptJob(data: {
                          "job_id": runnerRtDataProvider.jobId ?? -1,
                        });
                        if (response != null && response.statusCode == 200) {
                          _stopAudio();
                          await PostActionOverlayController.instance
                              .showFromResponse(
                                  response.data, LifecycleActionType.longDistance);
                        } else {
                          if (context.mounted) {
                            showSnackbar(
                              context,
                              "${response?.data ?? "Something went wrong. Please try again!"}",
                            );
                          }
                        }
                        await runnerRtDataProvider.fetchDataNow();
                        ClevertapSetup.logEvent(
                            TrackingEvents.acceptJobButtonClicked, {
                          "action": "accept job button click",
                        });
                        if (context.mounted) {
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
                        languageProvider.getMessage(
                            'accept_job', 'Accept Job'),
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

  Future<void> _stopAudio() async {
    await FileStorage.writeState('stopped');
    await NotificationService.instance.cancelAll();
    await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.stop);
    await GlobalState().audioPlayer.stop();
  }
}
