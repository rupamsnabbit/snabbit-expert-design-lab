import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';

// import 'package:logger/logger.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/rate_card_utils.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/checkout_outside_job_location.dart';
import 'package:snabbit_runner/widgets/job_in_progress/work_ended_warning.dart';
import 'package:snabbit_runner/widgets/low_battery_warning.dart';
import 'package:snabbit_runner/widgets/map_job_location.dart';
import 'package:snabbit_runner/widgets/loan/loan_banner.dart';
import 'package:snabbit_runner/services/loan_service.dart';
import 'package:snabbit_runner/providers/loan_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';

import '../attendance_flow/attendance_confirmed.dart';

class WaitForJob extends StatefulWidget {
  final Map<String, dynamic>? widgetData;
  final String? widgetName;

  const WaitForJob({
    super.key,
    this.widgetData,
    this.widgetName,
  });

  @override
  State<WaitForJob> createState() => _WaitForJobState();
}

class _WaitForJobState extends State<WaitForJob> with WidgetsBindingObserver {
  bool init = true;
  bool loading = true;
  bool isAppForeground = true;

  bool get _isLoanEligible {
    final userProfileProvider = context.read<UserProfileProvider>();
    return userProfileProvider.user?.isLoanEligible == true;
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _trackHotspotScreenLoad();
    initProcess().then((_) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    });
  }

  void _trackHotspotScreenLoad() {
    final data = widget.widgetData;
    final props = <String, dynamic>{
      'hotspot_name': data?['hotspot_name'],
      'hotspot_lat': data?['lat'],
      'hotspot_lng': data?['lng'],
    };
    // Fire-and-forget — analytics must not block screen build.
    MixpanelSetup.logEvent(TrackingEvents.hotspotScreenLoad, props);
  }

  void _trackHotspotShowDirectionsClick() {
    final data = widget.widgetData;
    final props = <String, dynamic>{
      'hotspot_name': data?['hotspot_name'],
      'hotspot_lat': data?['lat'],
      'hotspot_lng': data?['lng'],
    };
    MixpanelSetup.logEvent(TrackingEvents.hotspotShowDirectionsCtaClick, props);
  }

  Future<void> initProcess() async {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    isAppForeground = state == AppLifecycleState.resumed;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final runnerRtDataProvider = context.watch<RunnerRtDataProvider>();
    final userProfileProvider = context.watch<UserProfileProvider>();
    final loanProvider = context.watch<LoanProvider>();

    // Handle loan data fetching
    if (userProfileProvider.user?.isLoanEligible == true &&
        loanProvider.loanDetails == null &&
        !loanProvider.isLoading &&
        loanProvider.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loanProvider.fetchLoanDetails();
      });
    }

    if (isAppForeground == true) {
      Future(() {
        if (context.mounted) {
          showCheckoutWarning(
            context,
            widget.widgetData,
          );
        }
      });
      Future(() {
        if (context.mounted) {
          showWorkEndedWarning(
            context,
            widget.widgetData,
          );
        }
      });
    }

    return runnerRtDataProvider.waitForFetchData == true
        ? const Center(
            child: CupertinoActivityIndicator(),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.widgetData?['is_early_login_bonus'] == true)
                AmountBanner(
                  prefixIconSize: 100.w,
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getMessage(
                          'bonus_capital',
                          'BONUS',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(color: const Color(0xff205406)),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        languageProvider.getMessage(
                          'logged_in_before_time',
                          'logged in Before Time',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xff205406),
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  amount:
                      anyValueToInt(widget.widgetData?['early_login_bonus']) ??
                          0,
                  subtitle: languageProvider.getMessage(
                    'extra_capital',
                    'EXTRA',
                  ),
                  image: AssetConstants.earlyLoginBonusEarned,
                ),
              widget.widgetName == "RUNNER_JOB_CANCELLED"
                  ? Column(
                      children: [
                        SizedBox(height: 16.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.r, vertical: 12.r),
                            decoration: BoxDecoration(
                                color: AppColors.y10,
                                borderRadius: BorderRadius.circular(24.r)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const Icon(
                                  Icons.notifications_rounded,
                                  size: 22,
                                  color: AppColors.y60,
                                ),
                                Text(
                                  languageProvider.getMessage(
                                      "job_cancelled_by_customer",
                                      "Job cancelled by customer"),
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(),
              LowBatteryWarning(
                margin: EdgeInsets.only(bottom: 10.h),
              ),
              SizedBox(height: 8.h),
              Image.asset(
                'assets/search.png',
                height: 130.r,
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: Text(
                    languageProvider.getMessage("wait_near_hotspot",
                        "Please wait near the hotspot while we find you a job"),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: const Divider(
                  color: AppColors.n30,
                ),
              ),
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
              SizedBox(height: 25.h),
              SizedBox(
                height: 100.h,
                child: MapJobLocation(
                  markerPosition: LatLng(
                      widget.widgetData?['lat'], widget.widgetData?['lng']),
                  adm: widget.widgetData?['adm'],
                  onDirectionsTap: _trackHotspotShowDirectionsClick,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                "${widget.widgetData?['hotspot_name'] ?? ''} ${widget.widgetData?['address'] ?? ''}",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.n80),
              ),
              if (widget.widgetData?['show_logout_warning_widgets'] == true)
                Column(
                  children: [
                    if (!userProfileProvider.optedForNewRateCard) ...[
                      // only for rate card 1 users
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: 16.h,
                          top: 12.h,
                        ),
                        child: AmountBanner(
                          prefixIconSize: 90.w,
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                languageProvider.getFormattedMessage(
                                    'logout_at',
                                    'Logout at {{shift_end_time}}', {
                                  'shift_end_time':
                                      widget.widgetData?["shift_end_time"],
                                }),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: const Color(0xff623D09),
                                        fontSize: 16.sp),
                              ),
                              Text(
                                languageProvider.getMessage(
                                  'dont_lose_ming',
                                  'Don\'t Lose MinG',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                        color: const Color(0xff623D09),
                                        fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          image: AssetConstants.attendancePendingAmber,
                          valueBoxSize: 0,
                        ),
                      ),
                      Text(
                        "${widget.widgetData?["date"] ?? ""}",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      SizedBox(
                        height: 4.h,
                      ),
                    ],
                    Text(
                      languageProvider.getMessage(
                        'shift_end_time',
                        'Shift end time',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                              fontSize: 28.sp, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      "${widget.widgetData?["shift_end_time"] ?? ""}",
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                              fontSize: 28.sp, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 20.h),
                    SizedBox(
                      width: 1.sw,
                      child: ElevatedButton(
                        onPressed: null,
                        child: Text(
                          languageProvider.getMessage(
                            'logout',
                            'Logout',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_isLoanEligible)
                LoanBanner(
                  source: "runner_wait_hotspot",
                  onTap: () {
                    LoanService.handleLoanAction(
                        context, loanProvider, "runner_wait_hotspot");
                  },
                ),
              if (widget.widgetData?['show_ming_guarantee_card'] == true)
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: const Divider(
                        color: AppColors.n30,
                      ),
                    ),
                    const GuaranteedMinimumCard(),
                  ],
                ),
            ],
          );
  }
}

// class InfoColumn extends StatelessWidget {
//   final String title;
//   final String subtitle;

//   const InfoColumn({
//     super.key,
//     required this.title,
//     required this.subtitle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: Theme.of(context).textTheme.bodyLarge,
//         ),
//         Text(
//           subtitle,
//           style: Theme.of(context)
//               .textTheme
//               .bodyMedium
//               ?.copyWith(color: AppColors.n80),
//         ),
//       ],
//     );
//   }
// }

class GuaranteedMinimumCard extends StatelessWidget {
  const GuaranteedMinimumCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, languageProvider, _) {
      return Stack(
        children: [
          Container(
            width: 1.sw,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFFFF9E8)],
              ),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: const Color(0xffFEC171)),
            ),
            padding: EdgeInsets.only(
              left: 24.w,
              top: 39.h,
              right: 24.w,
              bottom: 17.h,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Guaranteed MinG" title
                  Text(
                    languageProvider.getMessage(
                        "guaranteed_ming", "Guaranteed MinG"),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),

                  // "When you:" label
                  Text(
                    languageProvider.getMessage("when_you", "When you:"),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.n90,
                        ),
                  ),
                  SizedBox(height: 16.h),

                  // Checkmark items
                  _buildCheckmarkItem(
                    context,
                    languageProvider.getMessage(
                        "login_on_time", "Login on time"),
                  ),
                  SizedBox(height: 12.h),

                  _buildCheckmarkItem(
                    context,
                    languageProvider.getMessage(
                        "logout_on_time", "Logout on time"),
                  ),
                  SizedBox(height: 12.h),

                  _buildCheckmarkItem(
                    context,
                    languageProvider.getMessage(
                        "attend_regular_shift", "Attend on a regular shift"),
                  ),
                  SizedBox(height: 12.h),

                  _buildCheckmarkItem(
                    context,
                    languageProvider.getMessage(
                        "zero_jobs_denied", "0 Jobs denied"),
                  ),
                  SizedBox(height: 12.h),

                  _buildCheckmarkItem(
                    context,
                    languageProvider.getMessage(
                        "maintain_good_behavior", "Maintain good behaviour"),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16.r,
            right: 6.r,
            child: Image.asset(
              AssetConstants.mingGuarantee,
              height: 80.h,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCheckmarkItem(BuildContext context, String text) {
    return Row(
      children: [
        Icon(
          Icons.check,
          size: 20.sp,
          color: const Color(0xff48351E),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.n80,
                ),
          ),
        ),
      ],
    );
  }
}
