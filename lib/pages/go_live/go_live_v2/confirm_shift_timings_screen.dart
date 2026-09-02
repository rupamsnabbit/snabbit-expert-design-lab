import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/cluster_details.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/utils/go_live_v2_tracking.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Screen: Confirm Shift Timings
class ConfirmShiftTimingsScreen extends StatefulWidget {
  static const String routeName = '/go-live-v2/confirm-shift-timings';

  const ConfirmShiftTimingsScreen({super.key});

  @override
  State<ConfirmShiftTimingsScreen> createState() =>
      _ConfirmShiftTimingsScreenState();
}

class _ConfirmShiftTimingsScreenState extends State<ConfirmShiftTimingsScreen> {
  bool _hasTrackedLoad = false;

  @override
  void initState() {
    super.initState();
    // Track screen load in next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasTrackedLoad) {
        _trackScreenLoad();
        _hasTrackedLoad = true;
      }
    });
  }

  Future<void> _trackScreenLoad() async {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    final selectedShift = provider.selectedShift;
    final selectedWeekendShift = provider.selectedWeekendShift;
    final hasSelectedWeekend = provider.hasSelectedWeekend;

    if (selectedShift == null) return;

    final weekdayHours = '${provider.shiftMinHours}-${provider.shiftMaxHours}';

    await GoLiveV2Tracking.trackFinalConfirmationLoad(
      weekendIsDifferent: hasSelectedWeekend,
      weekdayCluster: selectedShift.clusterName,
      weekdayShiftHoursOption: weekdayHours,
      weekdayStartTime: selectedShift.shiftTimings.formattedStartTime,
      weekdayEndTime: selectedShift.shiftTimings.formattedEndTime,
      estimatedMonthlyEarnings: selectedShift.estimatedMaxEarning,
      joiningBonus: selectedShift.joiningBonus,
      weekendCluster:
          hasSelectedWeekend ? selectedWeekendShift?.clusterName : null,
      weekendShiftHoursOption: hasSelectedWeekend
          ? '${provider.weekendShiftMinHours}-${provider.weekendShiftMaxHours}'
          : null,
      weekendStartTime: hasSelectedWeekend
          ? selectedWeekendShift?.shiftTimings.formattedStartTime
          : null,
      weekendEndTime: hasSelectedWeekend
          ? selectedWeekendShift?.shiftTimings.formattedEndTime
          : null,
    );
  }

  Future<void> _onProceed() async {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);

    // Track confirm CTA
    final selectedShift = provider.selectedShift;
    final selectedWeekendShift = provider.selectedWeekendShift;
    final hasSelectedWeekend = provider.hasSelectedWeekend;

    if (selectedShift != null) {
      final weekdayHours =
          '${provider.shiftMinHours}-${provider.shiftMaxHours}';

      await GoLiveV2Tracking.trackFinalConfirmationCta(
        ctaType: 'Confirm',
        weekendIsDifferent: hasSelectedWeekend,
        weekdayCluster: selectedShift.clusterName,
        weekdayShiftHoursOption: weekdayHours,
        weekdayStartTime: selectedShift.shiftTimings.formattedStartTime,
        weekdayEndTime: selectedShift.shiftTimings.formattedEndTime,
        estimatedMonthlyEarnings: selectedShift.estimatedMaxEarning,
        joiningBonus: selectedShift.joiningBonus,
        weekendCluster:
            hasSelectedWeekend ? selectedWeekendShift?.clusterName : null,
        weekendShiftHoursOption: hasSelectedWeekend
            ? '${provider.weekendShiftMinHours}-${provider.weekendShiftMaxHours}'
            : null,
        weekendStartTime: hasSelectedWeekend
            ? selectedWeekendShift?.shiftTimings.formattedStartTime
            : null,
        weekendEndTime: hasSelectedWeekend
            ? selectedWeekendShift?.shiftTimings.formattedEndTime
            : null,
      );
    }

    // Navigate to cluster details page
    // Note: confirm_shift API is now called in ClusterDetailsPage._confirmCluster()
    // This allows users to go back from cluster details and change V2 selections
    // without the "partner already onboarded" error
    Navigator.pushNamed(context, ClusterDetailsPage.routeName);
  }

  void _onGoBack() {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    final selectedShift = provider.selectedShift;
    final selectedWeekendShift = provider.selectedWeekendShift;
    final hasSelectedWeekend = provider.hasSelectedWeekend;

    // Track go back CTA
    if (selectedShift != null) {
      final weekdayHours =
          '${provider.shiftMinHours}-${provider.shiftMaxHours}';

      GoLiveV2Tracking.trackFinalConfirmationCta(
        ctaType: 'Go back',
        weekendIsDifferent: hasSelectedWeekend,
        weekdayCluster: selectedShift.clusterName,
        weekdayShiftHoursOption: weekdayHours,
        weekdayStartTime: selectedShift.shiftTimings.formattedStartTime,
        weekdayEndTime: selectedShift.shiftTimings.formattedEndTime,
        estimatedMonthlyEarnings: selectedShift.estimatedMaxEarning,
        joiningBonus: selectedShift.joiningBonus,
        weekendCluster:
            hasSelectedWeekend ? selectedWeekendShift?.clusterName : null,
        weekendShiftHoursOption: hasSelectedWeekend
            ? '${provider.weekendShiftMinHours}-${provider.weekendShiftMaxHours}'
            : null,
        weekendStartTime: hasSelectedWeekend
            ? selectedWeekendShift?.shiftTimings.formattedStartTime
            : null,
        weekendEndTime: hasSelectedWeekend
            ? selectedWeekendShift?.shiftTimings.formattedEndTime
            : null,
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final goLiveV2Provider = Provider.of<GoLiveV2Provider>(context);
    final userProvider = Provider.of<UserProfileProvider>(context);

    // Check if user is weekend-only
    final workSchedule = userProvider.user?.workSchedule?.value;
    final isWeekendOnly = workSchedule == WorkSchedule.weekendOnly;

    // Get selected shift data
    final selectedShift = goLiveV2Provider.selectedShift;
    final selectedWeekendShift = goLiveV2Provider.selectedWeekendShift;
    final hasSelectedWeekend = goLiveV2Provider.hasSelectedWeekend;

    // Calculate weekday shift data (only used for everyday users)
    final weekdayStartTime =
        selectedShift?.shiftTimings.formattedStartTime ?? '11:00 AM';
    final weekdayEndTime =
        selectedShift?.shiftTimings.formattedEndTime ?? '05:00 PM';
    final weekdayDuration = selectedShift?.durationText ?? '6 hours';

    // Calculate weekend shift data
    final weekendStartTime =
        selectedWeekendShift?.shiftTimings.formattedStartTime ?? '11:00 AM';
    final weekendEndTime =
        selectedWeekendShift?.shiftTimings.formattedEndTime ?? '05:00 PM';
    final weekendDuration = selectedWeekendShift?.durationText ?? '6 hours';

    // Determine display logic based on work schedule
    // - Weekend-only: Only show weekend card
    // - Everyday: Show weekday card, optionally show weekend if selected
    final showWeekdayCard = !isWeekendOnly;
    final showWeekendCard =
        isWeekendOnly || (hasSelectedWeekend && selectedWeekendShift != null);

    // For earnings, use weekend shift data if weekend-only, otherwise use weekday shift data
    final primaryShift = isWeekendOnly ? selectedWeekendShift : selectedShift;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CommonAppBar(
        title: const SizedBox.shrink(),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, _) => Text(
                      languageProvider.getMessage(
                        'go_live_v2_confirm_shift_timings',
                        'Confirm your shift timings',
                      ),
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Main card containing all elements
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Location - use primaryShift for location display
                        Row(
                          children: [
                            RemoteImageHandler(
                              imageUrl: "go_live/card_location.png".cdn,
                              width: 20.w,
                              height: 20.h,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                primaryShift != null
                                    ? '${primaryShift.hoodName}, ${primaryShift.clusterName}'
                                    : (goLiveV2Provider
                                            .selectedClusters.isNotEmpty
                                        ? goLiveV2Provider
                                            .selectedClusters.first.name
                                        : ''),
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),

                        // Weekday shift card - title depends on weekend selection
                        // If weekend is selected: "Monday to Friday"
                        // If no weekend: "Monday to Sunday"
                        if (showWeekdayCard)
                          _buildShiftCard(
                            title: hasSelectedWeekend
                                ? 'Monday to Friday'
                                : 'Monday to Sunday',
                            startTime: weekdayStartTime,
                            endTime: weekdayEndTime,
                            shiftHours: weekdayDuration,
                            color: const Color(0xFF64B5F6),
                          ),

                        // Weekend shift card (Saturday & Sunday)
                        if (showWeekendCard) ...[
                          if (showWeekdayCard) SizedBox(height: 16.h),
                          _buildShiftCard(
                            title: selectedWeekendShift?.shiftDaysText ??
                                'Saturday & Sunday',
                            startTime: weekendStartTime,
                            endTime: weekendEndTime,
                            shiftHours: weekendDuration,
                            color: const Color(0xFF66BB6A),
                          ),
                        ],
                        SizedBox(height: 20.h),

                        // Earnings section - use primaryShift for earnings data
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Column(
                            children: [
                              Consumer<LanguageProvider>(
                                builder: (context, languageProvider, _) =>
                                    _buildEarningsRow(
                                  iconUrl: "go_live/confirm_rupee.png".cdn,
                                  label: languageProvider.getMessage(
                                    'go_live_v2_estimated_monthly_earnings',
                                    'Estimated Monthly Earnings',
                                  ),
                                  amount:
                                      '₹${primaryShift?.estimatedMaxEarning ?? 0}',
                                  isBonus: false,
                                ),
                              ),

                              // Joining Bonus - only show if > 0
                              if ((primaryShift?.joiningBonus ?? 0) > 0) ...[
                                SizedBox(height: 16.h),
                                Consumer<LanguageProvider>(
                                  builder: (context, languageProvider, _) =>
                                      _buildEarningsRow(
                                    iconUrl: "go_live/bonus.png".cdn,
                                    label: languageProvider.getMessage(
                                      'go_live_v2_joining_bonus',
                                      'Joining Bonus',
                                    ),
                                    amount:
                                        '+ ₹ ${primaryShift?.joiningBonus ?? 0}',
                                    isBonus: false,
                                  ),
                                ),
                              ],

                              // Top Shift Bonus - only show if > 0
                              if ((primaryShift?.topShiftBonus ?? 0) > 0) ...[
                                SizedBox(height: 16.h),
                                Consumer<LanguageProvider>(
                                  builder: (context, languageProvider, _) =>
                                      _buildEarningsRow(
                                    iconUrl: "go_live/rupee_with_bg.png".cdn,
                                    label: languageProvider.getMessage(
                                      'go_live_v2_top_shift_bonus',
                                      'Top Shift Bonus',
                                    ),
                                    amount:
                                        '+ ₹ ${primaryShift?.topShiftBonus ?? 0}',
                                    isBonus: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildShiftCard({
    required String title,
    required String startTime,
    required String endTime,
    required String shiftHours,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),

          // Content card
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
              ),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Start/End time section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RemoteImageHandler(
                              imageUrl: "go_live/shift_time.png".cdn,
                              width: 20.w,
                              height: 20.h),
                          SizedBox(width: 6.w),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, _) => Text(
                          languageProvider.getMessage(
                            'go_live_v2_start_time_end_time',
                            'Start time - End time',
                          ),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$startTime - $endTime',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Shift hours section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RemoteImageHandler(
                        imageUrl: "go_live/shift_hour.png".cdn,
                        width: 20.w,
                        height: 20.h),
                    SizedBox(height: 8.h),
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, _) => Text(
                        languageProvider.getMessage(
                          'go_live_v2_shift_hour',
                          'Shift Hour',
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      shiftHours,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsRow({
    required String iconUrl,
    required String label,
    required String amount,
    required bool isBonus,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: RemoteImageHandler(
            imageUrl: iconUrl,
            width: 20.w,
            height: 20.h,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: isBonus ? const Color(0xFF52BD94) : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Consumer<GoLiveV2Provider>(
      builder: (context, provider, child) {
        // Keep isConfirmingShift check for defensive purposes
        // (in case confirm_shift is somehow triggered elsewhere)
        final isLoading = provider.isConfirmingShift;

        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Confirm button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _onProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLoading
                        ? AppColors.brand.withOpacity(0.7)
                        : AppColors.brand,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Consumer<LanguageProvider>(
                          builder: (context, languageProvider, _) => Text(
                            languageProvider.getMessage(
                              'go_live_v2_confirm',
                              'Confirm',
                            ),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(height: 16.h),

              // Go Back button
              Consumer<LanguageProvider>(
                builder: (context, languageProvider, _) => TextButton(
                  onPressed: isLoading ? null : _onGoBack,
                  child: Text(
                    languageProvider.getMessage(
                      'go_live_v2_go_back',
                      'Go Back',
                    ),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: isLoading ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
