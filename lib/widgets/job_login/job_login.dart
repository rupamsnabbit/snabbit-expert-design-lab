import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:format/format.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/selfie_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';
import 'package:snabbit_runner/widgets/attendance_flow/attendance_change_sheet.dart';
import 'package:snabbit_runner/widgets/attendance_flow/attendance_confirmed.dart';
import 'package:snabbit_runner/widgets/attendance_flow/take_care_sheet.dart';

import 'package:snabbit_runner/widgets/gamification/nudge_banner.dart';
import 'package:snabbit_runner/widgets/gamification/sheet_warning_attendance.dart';
import 'package:snabbit_runner/widgets/attendance_flow/support_team_list.dart';
import 'package:snabbit_runner/widgets/job_login/selfie_login.dart';
import 'package:snabbit_runner/widgets/map_job_location.dart';
import 'package:snabbit_runner/widgets/sos.dart';

import '../../constants/assets_constants.dart';
import '../../services/job_http.dart';
import '../../utils/app_strings.dart';
import '../../utils/common_methods.dart';
import '../attendance_flow/custom_timer.dart';
import '../common_bottomsheet_setup.dart';

class JobLogin extends StatefulWidget {
  final Map<String, dynamic>? widgetData;
  final String? widgetName;

  const JobLogin({
    super.key,
    this.widgetData,
    this.widgetName,
  });

  @override
  State<JobLogin> createState() => _JobLoginState();
}

class _JobLoginState extends State<JobLogin> {
  bool init = true;
  bool loading = true;

  late LoginSelfieProvider loginSelfieProvider;
  late LoginSelfie loginSelfie;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late PeriodLeaveProvider periodLeaveProvider;

  final FlutterTts flutterTts = FlutterTts();

  Future<void> initProcess() async {}

  Future<void> getCameraPermission() async {
    final isGranted = await Permission.camera.isGranted;

    MonitoringServiceHelper.logInfo(
      'Camera Permission Check',
      {
        'component': 'JobLogin',
        'isGranted': isGranted,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (!isGranted) {
      final status = await Permission.camera.request();

      MonitoringServiceHelper.logInfo(
        'Camera Permission Request',
        {
          'component': 'JobLogin',
          'status': status.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

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
      loginSelfieProvider =
          Provider.of<LoginSelfieProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      periodLeaveProvider =
          Provider.of<PeriodLeaveProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
      _trackHomeLoginCountdownNudge();
    }
  }

  void _trackHomeLoginCountdownNudge() {
    if (widget.widgetData?['login_pending_warning'] != true) return;
    final props = <String, dynamic>{
      'login_by_time_utc': widget.widgetData?['login_by_time_utc'],
      'login_by_time': widget.widgetData?['login_by_time'],
    };
    MixpanelSetup.logEvent(TrackingEvents.homeLoginCountdownNudgeLoad, props);
  }

  @override
  void initState() {
    super.initState();
    getCameraPermission();
    setLanguage();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Consumer<RunnerRtDataProvider>(
          builder: (context, runnerRt, _) {
            if (runnerRt.preActionNudges.isNotEmpty) {
              return NudgeBannerList(nudges: runnerRt.preActionNudges);
            }
            return const LoginEarlyBonusBanner();
          },
        ),
        if (widget.widgetData?['login_pending_warning'] == true)
          Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: AmountBanner(
              prefixIconSize: 90.w,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    languageProvider.getMessage(
                      'login_now',
                      'Login Now',
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xff623D09), fontSize: 16.sp),
                  ),
                  Text(
                    languageProvider.getMessage(
                      'do_good_shift',
                      'Do GOOD SHIFT',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: const Color(0xff623D09),
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              image: AssetConstants.attendancePendingAmber,
              valueBoxSize: 0,
            ),
          ),
        if (widget.widgetData?['login_pending_lost_ming'] == true)
          Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: AmountBanner(
              prefixIconSize: 90.w,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    languageProvider.getMessage(
                      'dont_miss_out',
                      "Don't Miss Out",
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppColors.n0, fontSize: 16.sp),
                  ),
                  Text(
                    languageProvider.getMessage(
                      'login_now_earn',
                      'Login now & earn',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.n0, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              image: AssetConstants.attendancePendingRed,
              valueBoxSize: 0,
            ),
          ),
        if (widget.widgetData?['login_pending_warning'] == true)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: CircularTimerWidget(
              labelText: languageProvider.getMessage(
                'login_now',
                'LOGIN NOW',
              ),
              lateText: languageProvider.getMessage(
                'login_now',
                'LOGIN NOW',
              ),
              labelTextColor: AppColors.r50,
              lateTextColor: AppColors.r60,
              sharedPrefsKeyPrefix: TimerPrefixStrings.attendanceTime,
              utcTimeString: widget.widgetData?["login_by_time_utc"],
              backgroundColor: AppColors.r30,
              strokeWidth: 18,
              width: 124,
              height: 124,
              onTimerComplete: () {
                runnerRtDataProvider.fetchDataNow();
              },
            ),
          ),
        Text(widget.widgetData?['date'],
            style: Theme.of(context).textTheme.bodyLarge),
        SizedBox(height: 8.h),

        Text(widget.widgetData?["shift_time"],
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: const Color.fromARGB(255, 63, 63, 63),
            )),

        SizedBox(height: 8.h),

        Padding(
          padding: EdgeInsets.symmetric(vertical: 5.h),
          child: const Divider(
            color: AppColors.n30,
          ),
        ),
        if (widget.widgetData?['change_atn'] == true)
          Row(
            children: [
              Expanded(
                flex: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.g40,
                        size: 36.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        languageProvider.getMessage(
                          'present',
                          'Present',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: AppColors.g40),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                flex: 6,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.r50,
                    side: const BorderSide(color: AppColors.n30),
                  ),
                  child: FittedBox(
                    child: Text(
                      languageProvider.getMessage(
                        "change_attendance",
                        "Change attendance",
                      ),
                    ),
                  ),
                  onPressed: () {
                    final sheetNudges = filterSheetWarnings(
                      runnerRtDataProvider.sheetWarnings,
                      AttendanceSheetLifecycle.falseAttendance,
                    );
                    final ctaMap = ctaOverridesForSheet(sheetNudges);
                    debugPrint('ctaMap: $ctaMap sheetNudges: $sheetNudges');
                    final redCards =
                        ctaMap[AttendanceSheetCtaIds.markAbsent]?.redCards ?? 3;

                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (modalContext) {
                        return AttendanceChangeSheet(
                          entrySource: 'job_login',
                          sheetWarningLifecycle:
                              AttendanceSheetLifecycle.falseAttendance,
                          redCardCount: redCards,
                          periodLeaveAvailable:
                              periodLeaveProvider.periodLeaveAvailable,
                          onMarkAbsent: () async {
                            Navigator.pop(modalContext);
                            runnerRtDataProvider.setWaitForFetchData(true);
                            await ClevertapSetup.logEvent(
                              TrackingEvents.attendanceChanged,
                              {
                                "runner_attendance_confirmed":
                                    "attendance change",
                                "from": "confirmed"
                              },
                            );
                            Response? response =
                                await JobHttp.changeAttendance(data: {
                              "mark": false,
                              "shift_date":
                                  widget.widgetData?["start_date_ist"],
                            });
                            if (response != null &&
                                response.statusCode == 200) {
                              await PostActionOverlayController.instance
                                  .showFromResponse(response.data,
                                      LifecycleActionType.falseAttendance);
                            } else if (context.mounted) {
                              showSnackbar(
                                context,
                                "${response?.data ?? "Something went wrong. Please try again!"}",
                              );
                            }
                            runnerRtDataProvider.fetchDataNow();
                          },
                          onMarkPresent: () {
                            Navigator.pop(modalContext);
                          },
                          onMarkAbsentWithPeriodLeave: () async {
                            Navigator.pop(modalContext);
                            runnerRtDataProvider.setWaitForFetchData(true);
                            bool shouldRefreshLifecycleAvailability = false;
                            Response? response =
                                await JobHttp.changeAttendance(data: {
                              "mark": false,
                              "shift_date":
                                  widget.widgetData?["start_date_ist"],
                              "period_leave": true,
                            });
                            if (response != null &&
                                response.statusCode == 200) {
                              shouldRefreshLifecycleAvailability = true;
                              if (context.mounted) {
                                await TakeCareSheet.show(context,
                                    source: 'false_attendance');
                              }
                              await PostActionOverlayController.instance
                                  .showFromResponse(response.data,
                                      LifecycleActionType.falseAttendance);
                            } else if (context.mounted) {
                              showSnackbar(
                                context,
                                "${response?.data ?? "Something went wrong. Please try again!"}",
                              );
                            }
                            if (shouldRefreshLifecycleAvailability) {
                              await runnerRtDataProvider
                                  .refreshPeriodLeaveAvailability();
                            }
                            runnerRtDataProvider.fetchDataNow();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          )
        else
          Text(
            languageProvider.getMessage(
              'today_attendance_present',
              'Today\'s attendance marked as PRESENT',
            ),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 5.h),
          child: const Divider(
            color: AppColors.n30,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          languageProvider.getMessage(
            'reach_hotspot',
            'Reach Hotspot',
          ),
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 24.h),
        SizedBox(
          height: 100.h,
          child: MapJobLocation(
            markerPosition:
                LatLng(widget.widgetData?['lat'], widget.widgetData?['lng']),
            adm: widget.widgetData?['adm'],
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          "${widget.widgetData?['geo_address']} ${widget.widgetData?['address']}",
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.n80),
        ),
        SizedBox(height: 16.h),
        // Only show login button if auto-login is not active
        // if (widget.widgetData?['auto_login_mins'] == null)
        //   SizedBox(
        //     width: double.infinity,
        //     child: ElevatedButton(
        //       onPressed: widget.widgetData?['enable_login']
        //           ? () async {
        //               final position = await fetchCurrentLocation();
        //
        //               loginSelfie = LoginSelfie.fromMap(
        //                 {
        //                   'lat': position?.latitude,
        //                   'lng': position?.longitude,
        //                 },
        //               );
        //               loginSelfieProvider.selfie = loginSelfie;
        //
        //               Navigator.of(context).pushNamed(SelfieForLogin.routeName);
        //               await ClevertapSetup.logEvent(
        //                   TrackingEvents.jobLoginLoginButtonClicked, {
        //                 "action": "job login button clicked",
        //               });
        //             }
        //           : null,
        //       style: ElevatedButton.styleFrom(
        //         backgroundColor: AppColors.g40,
        //       ),
        //       child: Text(
        //         languageProvider.getMessage("login", 'Login'),
        //         style: TextStyle(
        //             color: widget.widgetData?['enable_login']
        //                 ? Colors.white
        //                 : AppColors.n60),
        //       ),
        //     ),
        //   ),

        SizedBox(height: 8.h),
        if (widget.widgetData?['enable_login'] != true)
          DistanceFromLocation(
            lat: widget.widgetData?['lat'],
            lng: widget.widgetData?['lng'],
          ),
        // Text(
        //   "${languag
        //   eProvider.getMessage("login_after_start_time_minus_15", "You can login after ${widget.widgetData?['login_start_time']} once you reach the above mentioned address").format({
        //         #start_time: "${widget.widgetData?['login_start_time']}"
        //       })} ${distanceInMeters != null ? "(${distanceInMeters!.toInt()}m away)" : ""}",
        //   textAlign: TextAlign.center,
        //   style: TextStyle(
        //     fontSize: 11.sp,
        //     color: AppColors.n80,
        //   ),
        // ),
      ],
    );
  }
}

class ChangeAttendanceFP extends StatefulWidget {
  final Function() onPositiveAction;
  final Function()? onNegativeAction;

  const ChangeAttendanceFP({
    super.key,
    required this.onPositiveAction,
    this.onNegativeAction,
  });

  @override
  State<ChangeAttendanceFP> createState() => _ChangeAttendanceFPState();
}

class _ChangeAttendanceFPState extends State<ChangeAttendanceFP> {
  bool init = true;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetNudges = filterSheetWarnings(
      runnerRtDataProvider.sheetWarnings,
      AttendanceSheetLifecycle.falseAttendance,
    );
    final ctaMap = ctaOverridesForSheet(sheetNudges);
    final primaryCta = ctaMap[AttendanceSheetCtaIds.markAbsent];
    final secondaryCta = ctaMap[AttendanceSheetCtaIds.goBack];

    return runnerRtDataProvider.waitForFetchData == true
        ? SizedBox(
            height: 0.2.sh,
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          )
        : Column(
            children: [
              SizedBox(height: 16.h),
              Image.asset(
                AssetConstants.fpWarningPng,
                height: 105.h,
              ),
              SizedBox(height: 20.h),
              Text(
                languageProvider.getMessage(
                  "false_attendance",
                  "False Attendance",
                ),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.r40,
                    ),
              ),
              SizedBox(height: 28.h),
              Padding(
                padding: EdgeInsets.only(left: 24.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.close,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        languageProvider.getFormattedMessage(
                          'fp_penalty_warning',
                          'Penalty of -₹{{fp_penalty_amount}}',
                          {
                            'fp_penalty_amount': anyValueToInt(
                                    runnerRtDataProvider
                                        .widgetInfo?.data?['fp_penalty_amount'])
                                ?.abs(),
                          },
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 16.sp,
                              color: AppColors.n80,
                            ),
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.only(left: 24.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.close,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        languageProvider.getMessage(
                          'lose_ming',
                          'Lose MinG',
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 16.sp,
                              color: AppColors.n80,
                            ),
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 28.h),
              Text(
                languageProvider.getMessage(
                    'still_want_to_be_absent', 'Still want to be absent?'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: () async {
                    widget.onPositiveAction();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.g40,
                  ),
                  child: attendanceSheetCtaButtonChild(
                    context,
                    cta: primaryCta,
                    languageProvider: languageProvider,
                    fallbackKey: 'yes',
                    fallbackEnglish: 'Yes',
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.onNegativeAction != null) {
                      widget.onNegativeAction!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.r40,
                  ),
                  child: attendanceSheetCtaButtonChild(
                    context,
                    cta: secondaryCta,
                    languageProvider: languageProvider,
                    fallbackKey: 'no',
                    fallbackEnglish: 'No',
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          );
  }
}

class DistanceFromLocation extends StatefulWidget {
  final double? lat;
  final double? lng;

  const DistanceFromLocation({
    super.key,
    this.lat,
    this.lng,
  });

  @override
  State<DistanceFromLocation> createState() => _DistanceFromLocationState();
}

enum _LocationFetchState { loading, success, failed }

class _DistanceFromLocationState extends State<DistanceFromLocation> {
  bool init = true;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationTimeout;
  Position? currentPosition;
  double? distanceInMeters;
  _LocationFetchState _locationState = _LocationFetchState.loading;
  late LanguageProvider languageProvider;

  @override
  void initState() {
    super.initState();
    _getLocationUpdates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
  }

  void _getLocationUpdates() {
    if (!mounted) return;
    setState(() { _locationState = _LocationFetchState.loading; });
    _locationTimeout?.cancel();
    _positionStreamSubscription?.cancel();

    const defaultLocationStreamTimeout = 15;
    final locationStreamTimeoutRaw = RemoteConfigService.instance.getInt('location_stream_timeout_seconds', defaultValue: defaultLocationStreamTimeout);
    final effectiveLocationStreamTimeout = locationStreamTimeoutRaw > 0 ? locationStreamTimeoutRaw : defaultLocationStreamTimeout;
    _locationTimeout = Timer(Duration(seconds: effectiveLocationStreamTimeout), () {
      if (mounted && _locationState == _LocationFetchState.loading) {
        setState(() { _locationState = _LocationFetchState.failed; });
      }
    });

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    ).listen(
      (Position position) {
        _locationTimeout?.cancel();
        if (!mounted) return;
        setState(() {
          _locationState = _LocationFetchState.success;
          currentPosition = position;
          if (widget.lat != null && widget.lng != null) {
            distanceInMeters = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              widget.lat!,
              widget.lng!,
            );
          }
        });
      },
      onError: (error) {
        _locationTimeout?.cancel();
        if (!mounted) return;
        setState(() { _locationState = _LocationFetchState.failed; });
      },
    );
  }

  void _retryLocation() {
    _getLocationUpdates();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _locationTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_locationState == _LocationFetchState.loading) {
      return Text(
        languageProvider.getMessage('fetching_location', 'Fetching your location...'),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.r40),
      );
    }

    if (_locationState == _LocationFetchState.failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            languageProvider.getMessage('location_unavailable', 'Location unavailable'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.n70),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 32.h,
            child: OutlinedButton.icon(
              onPressed: _retryLocation,
              icon: Icon(Icons.refresh, size: 16.r),
              label: Text(languageProvider.getMessage('retry', 'Retry')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: BorderSide(color: AppColors.brand),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                textStyle: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26.r,
          height: 26.r,
          decoration: BoxDecoration(
            color: AppColors.r40,
            borderRadius: BorderRadius.circular(4.r),
          ),
          padding: EdgeInsets.all(2.r),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Icon(
              Icons.double_arrow_rounded,
              color: AppColors.n0,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          languageProvider.getFormattedMessage(
            'you_are_away_move_closer',
            'You are {{distance_away}}m away. Move closer',
            {'distance_away': "${distanceInMeters?.toInt() ?? '?'}"},
          ),
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: AppColors.r40),
        ),
      ],
    );
  }
}
