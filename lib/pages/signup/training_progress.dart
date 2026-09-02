import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/referrals/widgets/referral_header.dart';
import 'package:snabbit_runner/services/server_requests/training_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/pinput_field.dart';

import '../../models/training_center.dart';
import '../../providers/current_picture_provider.dart';
import '../../widgets/map_job_location.dart';
import '../selfie_capture_page.dart';
import 'training_slots.dart';

enum TrainingDayStatus {
  done,
  missed,
  current,
  loggedIn,
}

TrainingDayStatus? getTrainingDayStatusFromString(String? status) {
  if (status == null) return null;

  switch (status) {
    case 'COMPLETED':
      return TrainingDayStatus.done;
    case 'ABSENT':
      return TrainingDayStatus.missed;
    case 'LOGIN_PENDING':
      return TrainingDayStatus.current;
    case 'LOGGED_IN':
      return TrainingDayStatus.loggedIn;
    default:
      return null;
  }
}

enum TrainingStatus {
  ongoing,
  completed,
  failed,
}

TrainingStatus? getTrainingStatusFromString(String? status) {
  if (status == null) return null;

  switch (status) {
    case 'ONGOING':
      return TrainingStatus.ongoing;
    case 'COMPLETED':
      return TrainingStatus.completed;
    case 'FAILED':
      return TrainingStatus.failed;
    default:
      return null;
  }
}

class TrainingDayProvider with ChangeNotifier {
  List<TrainingDay>? trainingDays;
  TrainingSlot? slot;
  TrainingStatus? status;
  bool? registrationMandatory;
  bool loading = false;

  TrainingDayProvider();

  void setTrainingDays(List<TrainingDay>? val) {
    if (val != null) {
      trainingDays = [...val];
    } else {
      trainingDays = null;
    }
    notifyListeners();
  }

  void setTrainingSlot(TrainingSlot? val) {
    slot = val;
    notifyListeners();
  }

  void setStatus(TrainingStatus? val) {
    status = val;
    notifyListeners();
  }

  void setRegistrationMandatory(bool? val) {
    registrationMandatory = val;
    notifyListeners();
  }

  void updateTD(int? tdId, TrainingDayStatus? tdStatus) {
    try {
      TrainingDay? td = trainingDays?.firstWhere((e) => e.id == tdId);
      td?.status = tdStatus;
      notifyListeners();
    } catch (e) {
      // DO NOTHING
    }
  }

  Future<void> getTrainingDays({required Function(String) onError}) async {
    try {
      loading = true;
      notifyListeners();
      Response? response = await TrainingHttp.getRunnerTrainingDays();
      loading = false;
      if (response != null) {
        setTrainingDays(response.data['attendance_records']
            ?.map<TrainingDay>((e) => TrainingDay.fromMap(e))
            .toList());
        trainingDays?.sort((a, b) {
          try {
            return a.date!.compareTo(b.date!);
          } catch (e) {
            return a.id.compareTo(b.id);
          }
        });
        if (response.data['batch'] != null) {
          setTrainingSlot(TrainingSlot.fromMap(response.data['batch']));
        }
        setStatus(
            getTrainingStatusFromString(response.data['training_status']));
        setRegistrationMandatory(response.data['registration_mandatory']);
      } else {
        onError('Something went wrong!');
      }
      notifyListeners();
    } catch (e) {
      loading = false;
      notifyListeners();
      onError('Something went wrong - $e');
    }
  }
}

class TrainingDay {
  int id;
  TrainingDayStatus? status;
  DateTime? date;
  TrainingSlot? slot;

  TrainingDay({
    required this.id,
    this.status,
    this.date,
    this.slot,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status?.name,
    };
  }

  factory TrainingDay.fromMap(Map<String, dynamic> map) {
    return TrainingDay(
      id: map['id'],
      status: getTrainingDayStatusFromString(map['status']),
      date: DateTime.tryParse(map['attendance_date'].toString()),
      slot: map['training_batch'] != null
          ? TrainingSlot.fromMap(map['training_batch'])
          : null,
    );
  }
}

class VibrationWrapper extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const VibrationWrapper({
    super.key,
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(animation.value, 0),
          child: child,
        );
      },
      child: child,
    );
  }
}

class TrainingProgress extends StatefulWidget {
  static const String routeName = "/training_progress";

  const TrainingProgress({super.key});

  @override
  State<TrainingProgress> createState() => _TrainingProgressState();
}

class _TrainingProgressState extends State<TrainingProgress>
    with SingleTickerProviderStateMixin {
  bool init = true;
  double? trainingDaysHeight;
  double? trainingDaysWidth;
  ValueNotifier<bool> layoutNotifier = ValueNotifier<bool>(true);
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late TrainingDayProvider trainingDayProvider;

  // Animation controller for vibration effect
  late AnimationController _vibrationController;
  late Animation<double> _vibrationAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize vibration animation controller
    _vibrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );

    // Create vibration animation
    _vibrationAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _vibrationController,
        curve: Curves.easeInOut,
      ),
    );

    // Add listener to auto-reverse the animation
    _vibrationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _vibrationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _vibrationController.forward();
      }
    });
  }

  void startVibration() {
    // Reset animation to beginning
    _vibrationController.reset();
    // Start animation and repeat for a short time
    _vibrationController.repeat(reverse: true);
    // Stop after a short duration
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _vibrationController.stop();
      }
    });
  }

  @override
  void dispose() {
    _vibrationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(
        context,
        listen: true,
      );
      userProfileProvider = Provider.of<UserProfileProvider>(
        context,
        listen: true,
      );
      trainingDayProvider = Provider.of<TrainingDayProvider>(
        context,
        listen: true,
      );
      Future(() {
        initProcess();
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    await trainingDayProvider.getTrainingDays(onError: (msg) {
      if (mounted) {
        showSnackbar(context, msg);
      }
    });
  }

  int? trainingDayNumber() {
    try {
      // Count the number of days with status = done (completed)
      int completedDays = trainingDayProvider.trainingDays
              ?.where((day) => day.status == TrainingDayStatus.done)
              .length ??
          0;

      // Return the count of completed days + 1 for the current/next day
      return completedDays + 1;
    } catch (e) {
      return null;
    }
  }

  Widget trainingDayList() {
    return Column(
      children: trainingDayProvider.trainingDays!.map(
        (e) {
          late Widget tdIndex;
          late Widget tdStatus;
          Widget? tdSubtitle;
          switch (e.status) {
            case TrainingDayStatus.current:
              tdSubtitle = Text(
                languageProvider.getMessage(
                  'day',
                  'DAY',
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.n60,
                    ),
              );
              tdIndex = Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.n60,
                    width: 2.35.r,
                  ),
                  borderRadius: BorderRadius.circular(4.7.r),
                ),
                child: FittedBox(
                  child: Text(
                    "${trainingDayNumber() ?? "-"}",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.n60,
                        ),
                  ),
                ),
              );
              tdStatus = CurrentTrainingDay(
                languageProvider: languageProvider,
                trainingDay: e,
                onClick: trainingDayProvider.registrationMandatory == true
                    ? () {
                        startVibration();
                        showSnackbar(
                          context,
                          languageProvider.getMessage(
                            'registration_mandatory_message',
                            'Complete registration first',
                          ),
                        );
                      }
                    : null,
              );
            case TrainingDayStatus.loggedIn:
              tdSubtitle = Text(
                languageProvider.getMessage(
                  'day',
                  'DAY',
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.n60,
                    ),
              );
              tdIndex = Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.n60,
                    width: 2.35.r,
                  ),
                  borderRadius: BorderRadius.circular(4.7.r),
                ),
                child: FittedBox(
                  child: Text(
                    "${trainingDayNumber() ?? "-"}",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.n60,
                        ),
                  ),
                ),
              );
              tdStatus = LoggedInTrainingDay(
                languageProvider: languageProvider,
                trainingDay: e,
                onLogout: () async {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => const CommonBottomSheetSetup(
                      horizontalPadding: 37,
                      child: TrainingLogoutOtp(),
                    ),
                  );
                },
              );
            case TrainingDayStatus.done:
              tdIndex = Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.g40,
                  borderRadius: BorderRadius.circular(4.7.r),
                ),
                child: const FittedBox(
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.n0,
                  ),
                ),
              );
              tdStatus = DoneTrainingDay(
                languageProvider: languageProvider,
                trainingDay: e,
              );
            case TrainingDayStatus.missed:
              tdIndex = Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.r40,
                  borderRadius: BorderRadius.circular(4.7.r),
                ),
                child: const FittedBox(
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.n0,
                  ),
                ),
              );
              tdStatus = MissedTrainingDay(
                languageProvider: languageProvider,
                trainingDay: e,
              );
            default:
              tdIndex = const SizedBox();
              tdStatus = const SizedBox();
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 29 / 25,
                      child: tdIndex,
                    ),
                    if (tdSubtitle != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4.r),
                        child: tdSubtitle,
                      ),
                  ],
                ),
              ),
              const Expanded(
                flex: 1,
                child: SizedBox.shrink(),
              ),
              Expanded(
                flex: 8,
                child: tdStatus,
              ),
            ],
          );
        },
      ).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xffF5F6F8),
        appBar: AppBar(
          centerTitle: true,
          leading: InkWell(
            onTap: () {
              final userProfileProvider =
                  Provider.of<UserProfileProvider>(context, listen: false);
              userProfileProvider.checkStatusAndNavigate(context);
            },
            child: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppColors.n80,
            ),
          ),
          title: Text(
            languageProvider.getMessage(
              'in_training',
              'In Training',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          automaticallyImplyLeading: false,
        ),
        body: trainingDayProvider.loading
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await initProcess();
                },
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      if (trainingDayProvider.status !=
                          TrainingStatus.completed)
                        Container(
                          width: 1.sw,
                          padding: EdgeInsets.symmetric(
                            vertical: 16.h,
                            horizontal: 24.w,
                          ),
                          color: AppColors.y10,
                          child: Row(
                            children: [
                              Container(
                                width: 54.r,
                                height: 54.r,
                                padding: EdgeInsets.all(10.r),
                                decoration: const BoxDecoration(
                                  color: AppColors.y20,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(AssetConstants.warningPng),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Text(
                                  languageProvider.getMessage(
                                    'registration_completion_warning',
                                    'Complete both Registration and Training sessions to Go live',
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(color: AppColors.y60),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(16.r),
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(bottom: 16.h),
                                child: const ReferralHeaderView(
                                  showViewMyReferrals: true,
                                  source: 'training_progress_page',
                                ),
                              ),
                              Container(
                                width: 1.sw,
                                decoration: BoxDecoration(
                                  color: AppColors.n0,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: 24.h,
                                  horizontal: 18.w,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    trainingDayProvider.status ==
                                            TrainingStatus.failed
                                        ? StatusTile(
                                            text: languageProvider.getMessage(
                                              'failed',
                                              'FAILED',
                                            ),
                                            bgColor: AppColors.r10,
                                            textColor: AppColors.r50,
                                          )
                                        : trainingDayProvider.status ==
                                                TrainingStatus.completed
                                            ? StatusTile(
                                                text:
                                                    languageProvider.getMessage(
                                                  'completed',
                                                  'COMPLETED',
                                                ),
                                                bgColor: AppColors.g10,
                                                textColor: AppColors.g50,
                                              )
                                            : StatusTile(
                                                text:
                                                    languageProvider.getMessage(
                                                  'training_in_progress',
                                                  'IN PROGRESS',
                                                ),
                                                bgColor: AppColors.y20,
                                                textColor: AppColors.y60,
                                              ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      trainingDayProvider.status ==
                                              TrainingStatus.completed
                                          ? languageProvider.getMessage(
                                              'training_sessions_completed',
                                              'Training Sessions completed ',
                                            )
                                          : languageProvider.getMessage(
                                              'complete_training_sessions',
                                              'Complete Training Sessions',
                                            ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        if (trainingDayProvider.slot?.tc !=
                                            null) {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            constraints: BoxConstraints(
                                              maxHeight: 0.7.sh,
                                            ),
                                            builder: (_) {
                                              return CommonBottomSheetSetup(
                                                horizontalPadding: 37,
                                                child: TrainingCenterLocation(
                                                  tc: trainingDayProvider
                                                      .slot!.tc!,
                                                ),
                                              );
                                            },
                                          );
                                        } else {
                                          showSnackbar(
                                              context, 'TC not assigned');
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 9.h, horizontal: 0),
                                      ),
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: languageProvider.getMessage(
                                                'training_center',
                                                'Training Center - ',
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium,
                                            ),
                                            TextSpan(
                                              text: trainingDayProvider
                                                  .slot?.tc?.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium,
                                            ),
                                            WidgetSpan(
                                              alignment:
                                                  PlaceholderAlignment.middle,
                                              child: Padding(
                                                padding:
                                                    EdgeInsets.only(left: 4.w),
                                                child: Icon(
                                                  Icons.directions,
                                                  size: 18.sp,
                                                  color: AppColors.brand,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 35.h),
                                    if (trainingDayProvider
                                            .trainingDays?.isNotEmpty ??
                                        false)
                                      LayoutBuilder(
                                          builder: (context, constraints) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          final RenderBox box = context
                                              .findRenderObject() as RenderBox;
                                          trainingDaysHeight = box.size.height;
                                          trainingDaysWidth = box.size.width;
                                          layoutNotifier.value =
                                              !layoutNotifier.value;
                                        });

                                        return ValueListenableBuilder(
                                          valueListenable: layoutNotifier,
                                          builder: (context, _, __) {
                                            return Stack(
                                              children: [
                                                if (trainingDaysHeight !=
                                                        null &&
                                                    trainingDaysWidth != null)
                                                  Positioned(
                                                    left: (trainingDaysWidth! *
                                                            0.15) -
                                                        5.5.w,
                                                    child: SizedBox(
                                                      height:
                                                          trainingDaysHeight,
                                                      width: 11.w,
                                                      child: RotatedBox(
                                                        quarterTurns: 1,
                                                        child:
                                                            LinearProgressIndicator(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      16.r),
                                                          value: trainingDayProvider
                                                                      .status ==
                                                                  TrainingStatus
                                                                      .completed
                                                              ? 1.0
                                                              : min(
                                                                  trainingDayProvider
                                                                          .trainingDays!
                                                                          .length *
                                                                      0.25,
                                                                  1),
                                                          backgroundColor:
                                                              AppColors.n30,
                                                          valueColor:
                                                              const AlwaysStoppedAnimation<
                                                                  Color>(
                                                            AppColors.g40,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                trainingDayList(),
                                              ],
                                            );
                                          },
                                        );
                                      }),
                                  ],
                                ),
                              ),
                              // SizedBox(height: 16.h),
                              // VibrationWrapper(
                              //   animation: _vibrationAnimation,
                              //   child: BehaviouralAssessment(
                              //     userProfileProvider: userProfileProvider,
                              //     languageProvider: languageProvider,
                              //     bgColor: trainingDayProvider
                              //                 .registrationMandatory ==
                              //             true
                              //         ? AppColors.r10
                              //         : null,
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class CurrentTrainingDay extends StatefulWidget {
  final LanguageProvider languageProvider;
  final TrainingDay trainingDay;
  final VoidCallback? onClick;

  const CurrentTrainingDay({
    super.key,
    required this.languageProvider,
    required this.trainingDay,
    this.onClick,
  });

  @override
  State<CurrentTrainingDay> createState() => _CurrentTrainingDayState();
}

class _CurrentTrainingDayState extends State<CurrentTrainingDay> {
  @override
  Widget build(BuildContext context) {
    // Create a combined date-time for display purposes
    DateTime? combinedDateTime;
    if (widget.trainingDay.date != null &&
        widget.trainingDay.slot?.start != null) {
      combinedDateTime = DateTime(
        widget.trainingDay.date!.year,
        widget.trainingDay.date!.month,
        widget.trainingDay.date!.day,
        widget.trainingDay.slot!.start!.hour,
        widget.trainingDay.slot!.start!.minute,
        widget.trainingDay.slot!.start!.second,
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 12.h,
        horizontal: 16.w,
      ),
      decoration: BoxDecoration(
        color: AppColors.r0,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: widget.languageProvider.getMessage(
                    'tc_login_message',
                    'Please login at the training centre on ',
                  ),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.r50, fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: trainingDayDateTimeRep(combinedDateTime),
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(color: AppColors.r50),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              onPressed: widget.onClick ??
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SelfieCapturePage(
                          onSubmit: (File image) async {
                            showModalBottomSheet(
                                context: context,
                                builder: (_) {
                                  return const CommonBottomSheetSetup(
                                    child: TrainingLoginOtp(),
                                  );
                                });
                          },
                          onCancel: () {},
                        ),
                      ),
                    );
                  },
              child: Text(
                widget.languageProvider.getMessage(
                  'login_to_start_training',
                  'Login to start training',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoggedInTrainingDay extends StatefulWidget {
  final LanguageProvider languageProvider;
  final TrainingDay trainingDay;
  final Function() onLogout;

  const LoggedInTrainingDay({
    super.key,
    required this.languageProvider,
    required this.trainingDay,
    required this.onLogout,
  });

  @override
  State<LoggedInTrainingDay> createState() => _LoggedInTrainingDayState();
}

class _LoggedInTrainingDayState extends State<LoggedInTrainingDay> {
  Timer? _timer;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkButtonState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkButtonState() {
    // First check current status
    _isButtonEnabled = _isLogoutTimeValid();

    if (widget.trainingDay.date != null &&
        widget.trainingDay.slot?.end != null) {
      final DateTime currentTime = DateTime.now();
      final DateTime slotEndTime = widget.trainingDay.slot!.end!;

      final DateTime trainingDayWithEndTime = DateTime(
        widget.trainingDay.date!.year,
        widget.trainingDay.date!.month,
        widget.trainingDay.date!.day,
        slotEndTime.hour,
        slotEndTime.minute,
        slotEndTime.second,
      );

      final DateTime startWindow =
          trainingDayWithEndTime.subtract(const Duration(hours: 1));
      final DateTime endWindow =
          trainingDayWithEndTime.add(const Duration(hours: 1));

      if (_isButtonEnabled) {
        // Button is already enabled, we need to set up a timer to disable it at the end window
        if (currentTime.isBefore(endWindow)) {
          final int millisUntilInactive =
              endWindow.difference(currentTime).inMilliseconds;
          _timer = Timer(Duration(milliseconds: millisUntilInactive), () {
            if (mounted) {
              setState(() {
                _isButtonEnabled = false;
              });
            }
          });
        }
      } else {
        // Button is currently disabled, check if we need to enable it in the future
        if (currentTime.isBefore(startWindow) &&
            currentTime.isBefore(endWindow)) {
          // Calculate how many milliseconds until the button should be enabled
          final int millisUntilActive =
              startWindow.difference(currentTime).inMilliseconds;

          // Set a timer to enable the button at the right time
          _timer = Timer(Duration(milliseconds: millisUntilActive), () {
            if (mounted) {
              setState(() {
                _isButtonEnabled = true;
              });

              // Set another timer to disable the button after the end window
              final int millisUntilInactive =
                  endWindow.difference(startWindow).inMilliseconds;
              _timer = Timer(Duration(milliseconds: millisUntilInactive), () {
                if (mounted) {
                  setState(() {
                    _isButtonEnabled = false;
                  });
                }
              });
            }
          });
        }
      }
    }
  }

  bool _isLogoutTimeValid() {
    // If no slot, end time, or training date is available, button should be disabled
    if (widget.trainingDay.slot?.end == null ||
        widget.trainingDay.date == null) {
      return false;
    }

    final DateTime currentTime = DateTime.now();
    final DateTime slotEndTime = widget.trainingDay.slot!.end!;

    // Create a datetime with training day's date but the slot's end time
    final DateTime trainingDayWithEndTime = DateTime(
      widget.trainingDay.date!.year,
      widget.trainingDay.date!.month,
      widget.trainingDay.date!.day,
      slotEndTime.hour,
      slotEndTime.minute,
      slotEndTime.second,
    );

    // Button is active from 1 hour before to 1 hour after the end time on training day
    final DateTime startWindow =
        trainingDayWithEndTime.subtract(const Duration(hours: 1));
    final DateTime endWindow =
        trainingDayWithEndTime.add(const Duration(hours: 1));

    return currentTime.isAfter(startWindow) && currentTime.isBefore(endWindow);
  }

  @override
  Widget build(BuildContext context) {
    // Create a combined date-time for display purposes
    DateTime? combinedDateTime;
    if (widget.trainingDay.date != null &&
        widget.trainingDay.slot?.end != null) {
      combinedDateTime = DateTime(
        widget.trainingDay.date!.year,
        widget.trainingDay.date!.month,
        widget.trainingDay.date!.day,
        widget.trainingDay.slot!.end!.hour,
        widget.trainingDay.slot!.end!.minute,
        widget.trainingDay.slot!.end!.second,
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 12.h,
        horizontal: 16.w,
      ),
      decoration: BoxDecoration(
        color: AppColors.r0,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: widget.languageProvider.getMessage(
                    'tc_logout_message',
                    'Please logout at the training centre on ',
                  ),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.r50, fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: trainingDayDateTimeRep(combinedDateTime),
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(color: AppColors.r50),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              onPressed: _isButtonEnabled
                  ? () {
                      widget.onLogout();
                    }
                  : null,
              child: Text(
                widget.languageProvider.getMessage(
                  'logout_to_finish_training',
                  'Logout to finish training',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DoneTrainingDay extends StatelessWidget {
  final LanguageProvider languageProvider;
  final TrainingDay trainingDay;

  const DoneTrainingDay({
    super.key,
    required this.languageProvider,
    required this.trainingDay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 29.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getMessage(
              'training_completion_message',
              'Training completed successfully',
            ),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.g40),
          ),
          if (trainingDay.date != null)
            Text(
              formatTrainingDate(trainingDay.date!),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.n60),
            ),
        ],
      ),
    );
  }
}

class MissedTrainingDay extends StatelessWidget {
  final LanguageProvider languageProvider;
  final TrainingDay trainingDay;

  const MissedTrainingDay({
    super.key,
    required this.languageProvider,
    required this.trainingDay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 29.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getMessage(
              'training_missed_message',
              'Training missed',
            ),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.r40),
          ),
          if (trainingDay.date != null)
            Text(
              formatTrainingDate(trainingDay.date!),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.n60),
            ),
        ],
      ),
    );
  }
}

class TrainingLoginOtp extends StatefulWidget {
  const TrainingLoginOtp({super.key});

  @override
  State<TrainingLoginOtp> createState() => _TrainingLoginOtpState();
}

class _TrainingLoginOtpState extends State<TrainingLoginOtp> {
  late LanguageProvider languageProvider;
  late CurrentPictureProvider pictureProvider;
  bool init = true;
  bool loading = false;
  bool isSuccessful = false;
  String? error;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      pictureProvider =
          Provider.of<CurrentPictureProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: isSuccessful
          ? Column(
              children: [
                SizedBox(height: 20.h),
                Container(
                  height: 48.r,
                  width: 48.r,
                  decoration: const BoxDecoration(
                    color: AppColors.g40,
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(8.r),
                  child: const FittedBox(
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.n0,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  languageProvider.getMessage(
                    'login_successful',
                    'Login Successful',
                  ),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 24.h),
              ],
            )
          : loading
              ? SizedBox(
                  height: 0.2.sh,
                  child: const Center(
                    child: CupertinoActivityIndicator(),
                  ))
              : Column(
                  children: [
                    SizedBox(height: 20.h),
                    Text(
                      languageProvider.getMessage(
                        'enter_otp_to_login',
                        'Enter OTP to login',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 24.h),
                    if (error != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Text(
                          error!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.r40),
                        ),
                      ),
                    PinputField(
                      loading: false,
                      isError: error != null,
                      subtitleKey: 'ask_trainer_otp_message',
                      subtitleDefault:
                          'Please ask your trainer to share the OTP with you',
                      onSubmit: (otp) async {
                        setState(() {
                          loading = true;
                        });
                        final File? selfieImage =
                            pictureProvider.currentPicture;
                        try {
                          // Call the trainingLogin method from TrainingHttp
                          final response = await TrainingHttp.trainingLogin(
                              selfieImage, otp);
                          setState(() {
                            loading = false;
                          });

                          if (response?.statusCode == 200) {
                            error = null;
                            isSuccessful = true;
                            setState(() {});
                            try {
                              if (context.mounted) {
                                final trainingDayProvider =
                                    Provider.of<TrainingDayProvider>(context,
                                        listen: false);
                                trainingDayProvider.updateTD(
                                  response?.data?['id'],
                                  getTrainingDayStatusFromString(
                                      response?.data?['status']),
                                );
                              }
                            } catch (e) {
                              // DO NOTHING
                            }
                            // Handle successful login
                            Future.delayed(const Duration(seconds: 1))
                                .then((_) {
                              if (context.mounted) {
                                Navigator.of(context)
                                    .pop(); // Close the bottom sheet
                                Navigator.of(context)
                                    .pop(); // Exit the selfie page
                              }
                            });
                            // You might want to show a success message or navigate somewhere
                          } else {
                            // Handle error
                            error = 'Incorrect OTP';
                            setState(() {});
                          }
                        } catch (e) {
                          // Handle exception
                          error = 'Something went wrong';
                          setState(() {
                            loading = false;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
    );
  }
}

class TrainingLogoutOtp extends StatefulWidget {
  const TrainingLogoutOtp({super.key});

  @override
  State<TrainingLogoutOtp> createState() => TrainingLogoutOtpState();
}

class TrainingLogoutOtpState extends State<TrainingLogoutOtp> {
  late LanguageProvider languageProvider;
  late TrainingDayProvider trainingDayProvider;
  bool init = true;
  bool loading = false;
  bool isSuccessful = false;
  String? error;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      trainingDayProvider =
          Provider.of<TrainingDayProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: isSuccessful
          ? Column(
              children: [
                SizedBox(height: 20.h),
                Container(
                  height: 48.r,
                  width: 48.r,
                  decoration: const BoxDecoration(
                    color: AppColors.g40,
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(8.r),
                  child: const FittedBox(
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.n0,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  languageProvider.getMessage(
                    'logout_successful',
                    'Logout Successful',
                  ),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 24.h),
              ],
            )
          : loading
              ? SizedBox(
                  height: 0.2.sh,
                  child: const Center(
                    child: CupertinoActivityIndicator(),
                  ))
              : Column(
                  children: [
                    SizedBox(height: 20.h),
                    Text(
                      languageProvider.getMessage(
                        'enter_otp_to_logout',
                        'Enter OTP to logout',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 24.h),
                    if (error != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Text(
                          error!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.r40),
                        ),
                      ),
                    PinputField(
                      loading: false,
                      isError: error != null,
                      subtitleKey: 'ask_trainer_logout_otp_message',
                      subtitleDefault:
                          'Please ask your trainer to share the OTP with you',
                      onSubmit: (otp) async {
                        setState(() {
                          loading = true;
                        });
                        Response? response = await TrainingHttp.trainingLogout(
                          data: {
                            'otp': otp,
                          },
                        );
                        setState(() {
                          loading = false;
                        });
                        if (response != null && response.statusCode == 200) {
                          error = null;
                          setState(() {
                            isSuccessful = true;
                          });
                          trainingDayProvider.getTrainingDays(onError: (msg) {
                            if (mounted) {
                              showSnackbar(context, msg);
                            }
                          });
                          Future.delayed(const Duration(seconds: 1)).then((_) {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          });
                        } else {
                          error = 'Incorrect otp';
                        }
                      },
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
    );
  }
}

class TrainingCenterLocation extends StatefulWidget {
  final TrainingCenter tc;

  const TrainingCenterLocation({
    super.key,
    required this.tc,
  });

  @override
  State<TrainingCenterLocation> createState() => _TrainingCenterLocationState();
}

class _TrainingCenterLocationState extends State<TrainingCenterLocation> {
  bool init = true;
  late LanguageProvider languageProvider;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  Future<void> _speakAddress() async {
    await flutterTts.speak(widget.tc.address ?? "");
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 18.h),
        Align(
          alignment: Alignment.center,
          child: Text(
            languageProvider.getMessage(
              'training_location',
              'Training location',
            ),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          widget.tc.name ?? "",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        SizedBox(height: 12.h),
        Text(
          widget.tc.address ?? "",
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.n80),
        ),
        SizedBox(height: 12.h),
        OutlinedButton(
          onPressed: _speakAddress,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.n90,
            side: const BorderSide(color: AppColors.n40),
            padding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 10.h,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.volume_up),
              SizedBox(width: 8.w),
              Text(
                languageProvider.getMessage(
                  "speak_address",
                  "Speak address",
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: SizedBox(
            height: 170.h,
            width: double.infinity,
            child: MapJobLocation(
              markerPosition: LatLng(
                widget.tc.lat ?? 0,
                widget.tc.lng ?? 0,
              ),
            ),
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}
