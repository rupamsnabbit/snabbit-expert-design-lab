import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/models/go_live/earning_model.dart';
import 'package:snabbit_runner/models/go_live/shift_change_request.dart';
import 'package:snabbit_runner/models/potential_earnings.dart';
import 'package:snabbit_runner/pages/go_live/confirm_shift_timings.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/providers/potential_earnings_provider.dart';
import 'package:snabbit_runner/services/server_requests/go_live_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/date_time_extension.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/go_live/animated_flex_bar.dart';
import 'package:snabbit_runner/widgets/go_live/capsule_list.dart';
import 'package:snabbit_runner/widgets/go_live/shift_overview.dart';
import 'package:snabbit_runner/widgets/go_live/slots_unavailable.dart';
import 'package:snabbit_runner/widgets/go_live/total_earnings.dart';

class WeekendEarnings extends StatefulWidget {
  static const String routeName = '/weekend-earnings';

  const WeekendEarnings({super.key});

  @override
  State<WeekendEarnings> createState() => _WeekendEarningsState();
}

class _WeekendEarningsState extends State<WeekendEarnings> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late PotentialEarningsProvider earningsProvider;
  bool init = true;
  bool loading = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      earningsProvider =
          Provider.of<PotentialEarningsProvider>(context, listen: true);
      Future(() {
        final runnerId = userProfileProvider.user?.id;
        if (runnerId != null && !earningsProvider.loading) {
          earningsProvider.runnerId = runnerId;
          earningsProvider.fetchWeekendShiftData();
        }
      });
    }
    super.didChangeDependencies();
  }

  void _confirmAction() async {
    try {
      setState(() => loading = true);
      final response = await GoLiveHttp.postConfirmShiftTimings(
          data: ShiftChangeRequestData(
        duration:
            earningsProvider.selectedWeekendShiftDuration?.durationHours ?? 0,
        startTime: earningsProvider.selectedWeekendStartTime?.toHhMmSs(),
        clusterId: earningsProvider.selectedCluster?.id,
        hoodId: earningsProvider.selectedLocality?.hoodId,
        adm: earningsProvider.selectedTransport,
        weekend: true,
        weekdayEarning: earningsProvider.weekendRegularEarnings,
        weekendEarning: earningsProvider.weekendEarnings,
      ));
      setState(() => loading = false);
      if (response != null && response.statusCode == 200) {
        // Success: navigate or show success
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ConfirmShiftTimings(),
            ));
      } else {
        try {
          final responseError = ResponseError.fromMap(response?.data);
          final firstError = responseError.getFirstError();
          if (firstError != null) {
            showSlotsUnavailable(
              context,
              firstError,
              () {
                Navigator.pop(context);
                earningsProvider.fetchWeekendShiftData();
              },
            );
          }
        } catch (e) {
          showSnackbar(
              context,
              languageProvider.getMessage('error_confirming_shift',
                  'Error confirming weekend shift timings.'));
        }
      }
    } catch (_) {
      showSnackbar(
          context,
          languageProvider.getMessage('error_confirming_shift',
              'Error confirming weekend shift timings.'));
    }
  }

  List<Shift> get shiftDurations => earningsProvider.weekendShifts ?? [];

  List<DateTime> get startTimes =>
      earningsProvider.selectedWeekendShiftDuration?.startTimes ?? [];

  int get maxEarnings {

    try{
      return earningsProvider.weekendEarningsData?[earningsProvider.selectedTransport]  ?? 0;
    } catch(_){
      return 0;
    }
  }

  int get minEarnings => 0;

  int get regularEarnings => earningsProvider.weekendRegularEarnings;

  int get weekendEarnings => regularEarnings + earningsProvider.weekendEarnings;

  bool _canContinue() {
    return earningsProvider.selectedWeekendShiftDuration != null &&
        earningsProvider.selectedWeekendStartTime != null;
  }

  GoLiveAssets? get goLiveAssets => earningsProvider.topSectionData?.assets;


  int get regularEarningsProgress => regularEarnings;
  int get weeklyEarningsProgress => weekendEarnings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        elevation: 5.r,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage(
            "in_training",
            "In Training",
          ),
          style: textTheme.bodyLarge,
        ),
      ),
      persistentFooterButtons: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: !loading &&
                        !earningsProvider.weekendShiftsLoading &&
                        _canContinue()
                    ? _confirmAction
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  languageProvider.getMessage(
                    "proceed",
                    "Proceed",
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      body: init || loading || earningsProvider.weekendShiftsLoading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.h),
              child: Container(
                // padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                    color: AppColors.n0,
                    borderRadius: BorderRadius.circular(12.r)),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 15),
                      Center(
                        child: Text(
                          languageProvider.getMessage(
                              'potential_warnings', 'Potential Earnings'),
                          style: textTheme.displaySmall?.copyWith(
                            color: Color(0xFF1D2129),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Slider bar and labels
                      SizedBox(
                        width: 297,
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: TotalEarnings(
                                amount: weekendEarnings,
                                emojiUrl: weekendEarnings < regularEarnings
                                    ? goLiveAssets?.regularEarnings
                                    : goLiveAssets?.weekendEarnings,
                                gradientColors:
                                    weekendEarnings < regularEarnings
                                        ? const [
                                            Color(0xFF009534),
                                            Color(0xFF66F33F),
                                          ]
                                        : const [
                                            Color(0xFFFCE347),
                                            Color(0xFFF5C25B),
                                          ],
                              ),
                            ),
                            // Slider bar
                            SizedBox(
                              height: 13.6,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 297,
                                    decoration: BoxDecoration(
                                        color: AppColors.g10,
                                        borderRadius:
                                            BorderRadius.circular(4.64.r),
                                        border: Border.all(
                                          color: Color(0xFF3F3F3F),
                                          width: 1.16.r,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0xFF3F3F3F),
                                            // CSS: #3F3F3F
                                            offset: Offset(0, 0.58),
                                            // CSS: 0px (x-offset), 0.58px (y-offset)
                                            blurRadius: 0,
                                            // CSS: 0px (blur-radius)
                                            spreadRadius:
                                                0, // CSS: 0px (spread-radius)
                                          )
                                        ]),
                                  ),
                                  if (weeklyEarningsProgress>regularEarningsProgress)
                                    AnimatedFlexBar(
                                      totalEarnings: weeklyEarningsProgress,
                                      maxEarnings: maxEarnings,
                                      isWeekday: false,
                                      showIndicator: weeklyEarningsProgress>regularEarningsProgress,
                                    ),
                                  if (regularEarningsProgress > 0)
                                    AnimatedFlexBar(
                                      totalEarnings: regularEarningsProgress,
                                      maxEarnings: maxEarnings,
                                      isWeekday: true,
                                      showIndicator: weeklyEarningsProgress<regularEarningsProgress,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatIndianCurrency(minEarnings),
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.6.sp,
                                    color: Color(0xFFBC1C08),
                                    letterSpacing: 0.10,
                                  ),
                                ),
                                Text(
                                  formatIndianCurrency(maxEarnings),
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.6.sp,
                                    color: Color(0xFF107C41),
                                    letterSpacing: 0.10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Select Shift hours
                      CapsuleList<Shift>(
                        label: languageProvider.getMessage(
                            'select_shift_hours', 'Select Shift hours'),
                        description: languageProvider.getMessage(
                            'for_saturday_n_sunday', 'For Saturday & Sunday'),
                        items: shiftDurations,
                        titleBuilder: (item) =>
                            '${item.durationHours ?? 0} hours',
                        onSelectionChanged: (item) {
                          earningsProvider.selectedWeekendShiftDuration = item;
                        },
                        initialSelectedItem:
                            earningsProvider.selectedWeekendShiftDuration,
                        selectedItemBackgroundColor: AppColors.brand,
                        selectedItemTextColor: AppColors.n0,
                        unselectedItemTextColor: AppColors.n90,
                        unselectedItemBorderColor: AppColors.n40,
                        isCircle: false,
                        itemPadding: EdgeInsets.symmetric(
                            vertical: 16.h, horizontal: 8.w),
                      ),
                      if (earningsProvider.selectedWeekendShiftDuration !=
                          null) ...[
                        const SizedBox(height: 24),
                        // Select Start Time
                        CapsuleList<DateTime>(
                          label: languageProvider.getMessage(
                              'select_start_time', 'Select Start Time'),
                          description: languageProvider.getMessage(
                              'for_saturday_n_sunday', 'For Saturday & Sunday'),
                          items: startTimes,
                          titleBuilder: (item) => item.to12HoursMinutes(),
                          onSelectionChanged: (item) {
                            earningsProvider.selectedWeekendStartTime = item;
                          },
                          initialSelectedItem:
                              earningsProvider.selectedWeekendStartTime,
                          selectedItemBackgroundColor: AppColors.brand,
                          selectedItemTextColor: AppColors.n0,
                          unselectedItemTextColor: AppColors.n90,
                          unselectedItemBorderColor: AppColors.n40,
                          isCircle: false,
                          itemPadding: EdgeInsets.symmetric(
                              vertical: 16.h, horizontal: 8.w),
                        )
                      ],
                      SizedBox(height: 32.h),
                      if (earningsProvider.selectedWeekendShiftDuration !=
                              null &&
                          earningsProvider.selectedWeekendStartTime != null)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: ShiftOverview(
                            startDay: languageProvider.getMessage(
                                'saturday', "Saturday"),
                            endDay:
                                languageProvider.getMessage('sunday', "Sunday"),
                            startTime: earningsProvider.selectedWeekendStartTime
                                    ?.to12HoursMinutes() ??
                                "",
                            duration: earningsProvider
                                    .selectedWeekendShiftDuration
                                    ?.durationHours ??
                                0,
                            topSectionColor: AppColors.y10,
                            bottomSectionColor: Color(0xFFFBBC05),
                            foregroundColor: AppColors.y60,
                          ),
                        ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    earningsProvider.resetWeekendsData();
    super.dispose();
  }
}
