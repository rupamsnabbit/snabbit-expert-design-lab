import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/models/go_live/shift_change_request.dart';
import 'package:snabbit_runner/pages/go_live/confirm_shift_timings.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/providers/potential_earnings_provider.dart';
import 'package:snabbit_runner/services/server_requests/go_live_http.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/date_time_extension.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/go_live/animated_flex_bar.dart';
import 'package:snabbit_runner/widgets/go_live/capsule_list.dart';
import 'package:snabbit_runner/widgets/go_live/confirm_potential_earnings.dart';
import 'package:snabbit_runner/widgets/go_live/dropdown_list.dart';
import 'package:snabbit_runner/widgets/go_live/shift_overview.dart';
import 'package:snabbit_runner/widgets/go_live/slots_unavailable.dart';
import 'package:snabbit_runner/widgets/go_live/total_earnings.dart';

import '../../models/potential_earnings.dart';

class PotentialEarnings extends StatefulWidget {
  static const String routeName = '/potential-earnings';

  const PotentialEarnings({super.key});

  @override
  State<PotentialEarnings> createState() => _PotentialEarningsState();
}

class _PotentialEarningsState extends State<PotentialEarnings> {
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
          earningsProvider.fetchAvailableClusters(runnerId);
        }
      });
    }
    super.didChangeDependencies();
  }

  void _confirmAction() async {
    try {
      // Track CleverTap event for Proceed button
      final selectedCluster = earningsProvider.selectedCluster;
      final selectedLocality = earningsProvider.selectedLocality;
      final selectedShift = earningsProvider.selectedRegularShiftDuration;
      final selectedStartTime = earningsProvider.selectedRegularStartTime;
      final selectedTransport = earningsProvider.selectedTransport;
      final workScheduleValue = workSchedule;

      ClevertapSetup.logEvent('Proceed Button Clicked', {
        'cluster_id': selectedCluster?.id,
        'cluster_name': selectedCluster?.name ?? '',
        'cluster_recommended_status_text':
            earningsProvider.getClusterRecommendedStatusText(selectedCluster) ??
                '',
        'locality_id': selectedLocality?.hoodId,
        'locality_name': selectedLocality?.hoodName ?? '',
        'locality_recommended_status_text':
            earningsProvider.getHoodRecommendedStatusText(selectedLocality) ??
                '',
        'shift_duration_hours': selectedShift?.durationHours ?? 0,
        'start_time': selectedStartTime?.to12HoursMinutes() ?? '',
        'start_time_24h': selectedStartTime?.toHhMmSs() ?? '',
        'mode_of_transport': selectedTransport ?? '',
        'work_schedule': workScheduleValue?.name ?? '',
        'total_earnings': totalEarnings,
        'min_earnings': minEarnings,
        'max_earnings': maxEarnings,
        'regular_earnings': earningsProvider.regularEarnings,
      });

      setState(() => loading = true);
      final response = await GoLiveHttp.postConfirmShiftTimings(
        data: ShiftChangeRequestData(
          duration:
              earningsProvider.selectedRegularShiftDuration?.durationHours ?? 0,
          startTime: earningsProvider.selectedRegularStartTime?.toHhMmSs(),
          clusterId: earningsProvider.selectedCluster?.id,
          hoodId: earningsProvider.selectedLocality?.hoodId,
          adm: earningsProvider.selectedTransport,
          weekend: workSchedule == WorkSchedule.weekendOnly,
          weekdayEarning: workSchedule == WorkSchedule.everyday
              ? earningsProvider.regularEarnings
              : null,
          weekendEarning: workSchedule == WorkSchedule.weekendOnly
              ? earningsProvider.regularEarnings
              : null,
        ),
      );
      setState(() => loading = false);
      if (response != null && response.statusCode == 200) {
        final data = response.data;

        final extraEarningEligibility =
            data?["extra_earning_eligible"] ?? false;
        if (extraEarningEligibility && workSchedule == WorkSchedule.everyday) {
          showConfirmPotentialEarnings(context);
        } else {
          Navigator.pushNamed(context, ConfirmShiftTimings.routeName);
        }
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
                earningsProvider.fetchShiftData();
              },
            );
          }
        } catch (e) {
          showSnackbar(
              context,
              languageProvider.getMessage(
                  'error_confirming_shift', 'Error confirming shift timings.'));
        }
      }
    } catch (_) {
      showSnackbar(
          context,
          languageProvider.getMessage(
              'error_confirming_shift', 'Error confirming shift timings.'));
    }
  }

  PotentialEarningsTopSection? get topSectionData =>
      earningsProvider.topSectionData;

  PotentialEarningsBottomSection? get bottomSectionData =>
      earningsProvider.bottomSectionData;

  Shift? get selectedRegularShiftDuration =>
      earningsProvider.selectedRegularShiftDuration;

  List<Cluster> get clusters => earningsProvider.allClusters;

  List<Hood> get localities => earningsProvider.allHoods;

  List<Shift> get shiftDurations =>
      earningsProvider.selectedLocality?.shifts ?? [];

  List<DateTime> get startTimes =>
      selectedRegularShiftDuration?.startTimes ?? [];

  List<String> get availableTransports =>
      bottomSectionData?.modeTransport ?? [];

  int get maxEarnings => earningsProvider.maxEarnings;

  int get minEarnings => 0;

  int get totalEarnings => earningsProvider.regularEarnings;

  WorkSchedule? get workSchedule =>
      userProfileProvider.user?.workSchedule?.value;

  bool _canContinue() {
    return earningsProvider.selectedCluster != null &&
        earningsProvider.selectedLocality != null &&
        earningsProvider.selectedRegularShiftDuration != null &&
        earningsProvider.selectedRegularStartTime != null &&
        earningsProvider.selectedTransport != null;
  }

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
                onPressed: !loading && _canContinue() ? _confirmAction : null,
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
      body: init || loading || earningsProvider.loading
          ? const Center(
              child: CupertinoActivityIndicator(
                color: AppColors.n60,
              ),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 15),
                      Center(
                        child: Text(
                          languageProvider.getMessage(
                              'potential_earnings', 'Potential Earnings'),
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
                                amount: totalEarnings,
                                emojiUrl: earningsProvider
                                    .topSectionData?.assets?.regularEarnings,
                                gradientColors: [
                                  Color(0xFF009534),
                                  Color(0xFF66F33F),
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
                                  if (totalEarnings > 0)
                                    AnimatedFlexBar(
                                      totalEarnings: totalEarnings,
                                      maxEarnings: maxEarnings,
                                      isWeekday: true,
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
                      // Select Cluster
                      DropDownList<Cluster>(
                        label: languageProvider.getMessage(
                            'select_cluster', "Select Cluster"),
                        items: clusters,
                        initialSelection: earningsProvider.selectedCluster,
                        onSelectionChanged: (value) {
                          earningsProvider.selectedCluster = value;
                        },
                        itemNameBuilder: (item) => item.name ?? "",
                        showStatusChips:
                            earningsProvider.hasRecommendedClusters,
                      ),
                      earningsProvider.regularShiftsLoading
                          ? Container(
                              alignment: Alignment.center,
                              padding: EdgeInsets.only(top: 16.h),
                              child: const CupertinoActivityIndicator(),
                            )
                          : earningsProvider.bottomSectionData != null
                              ? Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 24),
                                      DropDownList<Hood>(
                                        label: languageProvider.getMessage(
                                            'select_locality',
                                            'Select Locality'),
                                        items: localities,
                                        initialSelection:
                                            earningsProvider.selectedLocality,
                                        onSelectionChanged: (value) {
                                          earningsProvider.selectedLocality =
                                              value;
                                        },
                                        itemNameBuilder: (item) =>
                                            item.hoodName ?? "",
                                        showStatusChips: earningsProvider
                                            .hasRecommendedHoods,
                                      ),
                                      const SizedBox(height: 24),
                                      DropDownList<String>(
                                        label: languageProvider.getMessage(
                                            'mode_of_transport',
                                            "Mode of transport"),
                                        items: availableTransports,
                                        initialSelection:
                                            earningsProvider.selectedTransport,
                                        onSelectionChanged: (value) {
                                          earningsProvider.selectedTransport =
                                              value;
                                        },
                                        itemNameBuilder: (item) => item,
                                      ),
                                      if (earningsProvider.selectedLocality !=
                                          null)
                                        Flexible(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              const SizedBox(height: 24),
                                              // Select Shift hours
                                              CapsuleList<Shift>(
                                                label:
                                                    languageProvider.getMessage(
                                                        'select_shift_hours',
                                                        'Select Shift hours'),
                                                items: shiftDurations,
                                                titleBuilder: (item) =>
                                                    '${item.durationHours ?? 0} hours',
                                                onSelectionChanged: (item) {
                                                  earningsProvider
                                                          .selectedRegularShiftDuration =
                                                      item;
                                                },
                                                initialSelectedItem:
                                                    earningsProvider
                                                        .selectedRegularShiftDuration,
                                                selectedItemBackgroundColor:
                                                    AppColors.brand,
                                                selectedItemTextColor:
                                                    AppColors.n0,
                                                unselectedItemTextColor:
                                                    AppColors.n90,
                                                unselectedItemBorderColor:
                                                    AppColors.n40,
                                                isCircle: false,
                                                itemPadding:
                                                    EdgeInsets.symmetric(
                                                        vertical: 16.h,
                                                        horizontal: 8.w),
                                              ),
                                              if (earningsProvider
                                                      .selectedRegularShiftDuration !=
                                                  null) ...[
                                                const SizedBox(height: 24),
                                                // Select Start Time
                                                CapsuleList<DateTime>(
                                                  label: languageProvider
                                                      .getMessage(
                                                          'select_start_time',
                                                          'Select Start Time'),
                                                  items: startTimes,
                                                  titleBuilder: (item) =>
                                                      item.to12HoursMinutes(),
                                                  onSelectionChanged: (item) {
                                                    earningsProvider
                                                            .selectedRegularStartTime =
                                                        item;
                                                  },
                                                  initialSelectedItem:
                                                      earningsProvider
                                                          .selectedRegularStartTime,
                                                  selectedItemBackgroundColor:
                                                      AppColors.brand,
                                                  selectedItemTextColor:
                                                      AppColors.n0,
                                                  unselectedItemTextColor:
                                                      AppColors.n90,
                                                  unselectedItemBorderColor:
                                                      AppColors.n40,
                                                  isCircle: false,
                                                  itemPadding:
                                                      EdgeInsets.symmetric(
                                                          vertical: 16.h,
                                                          horizontal: 8.w),
                                                ),
                                              ],
                                              SizedBox(height: 32.h),
                                              if (earningsProvider
                                                          .selectedRegularStartTime !=
                                                      null &&
                                                  earningsProvider
                                                          .selectedRegularShiftDuration !=
                                                      null)
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 16.w),
                                                  child:
                                                      userProfileProvider
                                                                  .user
                                                                  ?.workSchedule
                                                                  ?.value ==
                                                              WorkSchedule
                                                                  .everyday
                                                          ? ShiftOverview(
                                                              startDay: languageProvider
                                                                  .getMessage(
                                                                      'monday',
                                                                      "Monday"),
                                                              endDay: languageProvider
                                                                  .getMessage(
                                                                      'friday',
                                                                      "Friday"),
                                                              startTime: earningsProvider
                                                                      .selectedRegularStartTime
                                                                      ?.to12HoursMinutes() ??
                                                                  "",
                                                              duration: earningsProvider
                                                                      .selectedRegularShiftDuration
                                                                      ?.durationHours ??
                                                                  0,
                                                              topSectionColor:
                                                                  AppColors.g10,
                                                              bottomSectionColor:
                                                                  const Color(
                                                                      0xFF5AD448),
                                                              foregroundColor:
                                                                  AppColors.g50,
                                                            )
                                                          : ShiftOverview(
                                                              startDay: languageProvider
                                                                  .getMessage(
                                                                      'saturday',
                                                                      "Saturday"),
                                                              endDay: languageProvider
                                                                  .getMessage(
                                                                      'sunday',
                                                                      "Sunday"),
                                                              startTime: earningsProvider
                                                                      .selectedRegularStartTime
                                                                      ?.to12HoursMinutes() ??
                                                                  "",
                                                              duration: earningsProvider
                                                                      .selectedRegularShiftDuration
                                                                      ?.durationHours ??
                                                                  0,
                                                              topSectionColor:
                                                                  AppColors.y10,
                                                              bottomSectionColor:
                                                                  const Color(
                                                                      0xFFFBBC05),
                                                              foregroundColor:
                                                                  AppColors.y60,
                                                            ),
                                                )
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
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
    earningsProvider.reset();
    super.dispose();
  }
}
