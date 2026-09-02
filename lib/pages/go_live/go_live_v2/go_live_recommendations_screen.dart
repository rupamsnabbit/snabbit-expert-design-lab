import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/cluster_details.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/cluster_selection_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/confirm_shift_timings_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/recommended_shift.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/utils/go_live_v2_tracking.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/widgets/weekend_earnings_modal.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Screen 4: Go Live Recommendations and Confirmation
class GoLiveRecommendationsScreen extends StatefulWidget {
  static const String routeName = '/go-live-v2/recommendations';
  static const String weekendRouteName = '/go-live-v2/weekend-recommendations';

  const GoLiveRecommendationsScreen({super.key});

  @override
  State<GoLiveRecommendationsScreen> createState() =>
      _GoLiveRecommendationsScreenState();
}

class _GoLiveRecommendationsScreenState
    extends State<GoLiveRecommendationsScreen>
    with SingleTickerProviderStateMixin {
  bool _isConfirming = false;

  // Animation controller for card swipe
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Slide animation - card moves left
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.5, 0), // Slide left off screen
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Reset to first recommendation when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
      provider.resetRecommendationIndex();
      _fetchRecommendations();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    if (provider.isWeekendMode) {
      await provider.fetchWeekendRecommendedShifts();
    } else {
      await provider.fetchRecommendedShifts();
    }

    // Track recommendation load or error
    if (!mounted) return;
    if (provider.isPartnerAlreadyOnboardedOnRecommendations) {
      // Partner already onboarded - navigate to cluster details to continue flow
      Navigator.pushNamedAndRemoveUntil(
        context,
        ClusterDetailsPage.routeName,
        (route) =>
            route.settings.name == null ||
            !route.settings.name!.contains('go-live-v2'),
      );
    } else if (provider.isNoShiftsAvailableError) {
      // Track error
      await GoLiveV2Tracking.trackRecommendationError(
        errorType: 'NO_SHIFTS_AVAILABLE',
      );
      // Navigate to cluster selection screen with modal flag
      Navigator.pushNamed(context, ClusterSelectionScreen.noShiftsRouteName);
    } else if (provider.recommendationsError != null) {
      // Track other errors
      await GoLiveV2Tracking.trackRecommendationError(
        errorType: provider.recommendationsError!,
      );
    } else if (provider.currentRecommendedShift != null ||
        provider.currentWeekendRecommendedShift != null) {
      // Track successful load
      final shift = provider.isWeekendMode
          ? provider.currentWeekendRecommendedShift!
          : provider.currentRecommendedShift!;
      final weekdayHours =
          '${provider.shiftMinHours}-${provider.shiftMaxHours}';
      final weekdayTimeBucket = provider.shiftTime?.timeText ?? '';

      await GoLiveV2Tracking.trackRecommendationLoad(
        shift: shift,
        preferenceNo: provider.currentRecommendationIndex + 1,
        weekdayShiftHoursOption: weekdayHours,
        weekdayStartTimeBucket: weekdayTimeBucket,
        isWeekend: provider.isWeekendMode,
        weekendShiftHoursOption: provider.isWeekendMode
            ? '${provider.weekendShiftMinHours}-${provider.weekendShiftMaxHours}'
            : null,
        weekendStartTimeBucket:
            provider.isWeekendMode ? provider.weekendShiftTime?.timeText : null,
      );
    }
  }

  void _onEditPreferences() {
    // Navigate back to cluster selection screen
    Navigator.pushNamed(context, ClusterSelectionScreen.routeName);
  }

  void _onCancel() {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);

    // Track recommendation rejection
    final shift = provider.isWeekendMode
        ? provider.currentWeekendRecommendedShift
        : provider.currentRecommendedShift;
    if (shift != null) {
      final weekdayHours =
          '${provider.shiftMinHours}-${provider.shiftMaxHours}';
      final weekdayTimeBucket = provider.shiftTime?.timeText ?? '';

      GoLiveV2Tracking.trackRecommendationCta(
        shift: shift,
        preferenceNo: provider.currentRecommendationIndex + 1,
        weekdayShiftHoursOption: weekdayHours,
        weekdayStartTimeBucket: weekdayTimeBucket,
        isWeekend: provider.isWeekendMode,
        accepted: false,
        weekendShiftHoursOption: provider.isWeekendMode
            ? '${provider.weekendShiftMinHours}-${provider.weekendShiftMaxHours}'
            : null,
        weekendStartTimeBucket:
            provider.isWeekendMode ? provider.weekendShiftTime?.timeText : null,
      );
    }

    // Animate card out to the left
    _animationController.forward().then((_) {
      // After animation completes, try to show the next recommendation
      provider.showNextRecommendation();

      // Reset animation for next card
      _animationController.reset();

      // Track next recommendation load if available
      final nextShift = provider.isWeekendMode
          ? provider.currentWeekendRecommendedShift
          : provider.currentRecommendedShift;
      if (nextShift != null) {
        final weekdayHours =
            '${provider.shiftMinHours}-${provider.shiftMaxHours}';
        final weekdayTimeBucket = provider.shiftTime?.timeText ?? '';

        GoLiveV2Tracking.trackRecommendationLoad(
          shift: nextShift,
          preferenceNo: provider.currentRecommendationIndex + 1,
          weekdayShiftHoursOption: weekdayHours,
          weekdayStartTimeBucket: weekdayTimeBucket,
          isWeekend: provider.isWeekendMode,
          weekendShiftHoursOption: provider.isWeekendMode
              ? '${provider.weekendShiftMinHours}-${provider.weekendShiftMaxHours}'
              : null,
          weekendStartTimeBucket: provider.isWeekendMode
              ? provider.weekendShiftTime?.timeText
              : null,
        );
      }

      // If no more recommendations, the UI will show the exhausted state
      // (currentShift will be null)
    });
  }

  void _onGoBack() {
    // Reset recommendation index to show from beginning
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    provider.resetRecommendationIndex();
  }

  Future<void> _onConfirm() async {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);

    // Track recommendation acceptance
    final shift = provider.isWeekendMode
        ? provider.currentWeekendRecommendedShift
        : provider.currentRecommendedShift;
    if (shift != null) {
      final weekdayHours =
          '${provider.shiftMinHours}-${provider.shiftMaxHours}';
      final weekdayTimeBucket = provider.shiftTime?.timeText ?? '';

      await GoLiveV2Tracking.trackRecommendationCta(
        shift: shift,
        preferenceNo: provider.currentRecommendationIndex + 1,
        weekdayShiftHoursOption: weekdayHours,
        weekdayStartTimeBucket: weekdayTimeBucket,
        isWeekend: provider.isWeekendMode,
        accepted: true,
        weekendShiftHoursOption: provider.isWeekendMode
            ? '${provider.weekendShiftMinHours}-${provider.weekendShiftMaxHours}'
            : null,
        weekendStartTimeBucket:
            provider.isWeekendMode ? provider.weekendShiftTime?.timeText : null,
      );
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      // Call verify shift API (pass weekend mode)
      final response =
          await provider.verifyCurrentShift(isWeekend: provider.isWeekendMode);

      if (!mounted) return;

      setState(() {
        _isConfirming = false;
      });

      // Check for PARTNER_ALREADY_ONBOARDED error - navigate to cluster details
      if (provider.isPartnerAlreadyOnboardedOnVerify) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          ClusterDetailsPage.routeName,
          (route) =>
              route.settings.name == null ||
              !route.settings.name!.contains('go-live-v2'),
        );
        return;
      }

      // Check for SHIFT_NOT_AVAILABLE error
      if (provider.isShiftNotAvailableOnVerify) {
        // Track error
        await GoLiveV2Tracking.trackRecommendationError(
          errorType: 'SHIFT_NOT_AVAILABLE',
        );
        // Navigate to cluster selection and show modal
        Navigator.pushNamedAndRemoveUntil(
          context,
          ClusterSelectionScreen.shiftNotAvailableRouteName,
          (route) =>
              route.settings.name == null ||
              !route.settings.name!.contains('go-live-v2'),
        );
        return;
      }

      if (response != null && response.isAvailable) {
        if (provider.isWeekendMode) {
          // Weekend mode: Navigate directly to confirm screen
          Navigator.pushNamed(context, ConfirmShiftTimingsScreen.routeName);
        } else {
          // Weekday mode: Show weekend earnings modal on success
          showModalBottomSheet(
            context: context,
            isDismissible: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.r),
                topRight: Radius.circular(24.r),
              ),
            ),
            builder: (_) => WeekendEarningsModal(provider: provider),
          );
        }
      } else {
        // Handle error - show error state
        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);
        final errorMsg = response?.errors.isNotEmpty == true
            ? response!.errors.first.message
            : provider.verifyShiftError ??
                languageProvider.getMessage(
                  'go_live_v2_verification_failed',
                  'Verification failed',
                );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConfirming = false;
      });
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GoLiveV2Provider>(
      builder: (context, provider, child) {
        // Use weekend or weekday recommendations based on mode
        final currentShift = provider.isWeekendMode
            ? provider.currentWeekendRecommendedShift
            : provider.currentRecommendedShift;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: CommonAppBar(
            title: const SizedBox.shrink(),
          ),
          body: Column(
            children: [
              Expanded(
                child: provider.isLoadingRecommendations
                    ? _buildLoadingState()
                    : provider.recommendationsError != null
                        ? _buildErrorState(provider.recommendationsError!)
                        : currentShift == null
                            ? _buildExhaustedState()
                            : SingleChildScrollView(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20.w, vertical: 24.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Title (centered)
                                    Consumer<LanguageProvider>(
                                      builder: (context, languageProvider, _) =>
                                          Center(
                                        child: Column(
                                          children: [
                                            Text(
                                              languageProvider.getMessage(
                                                'go_live_v2_recommendations_title',
                                                'Go Live now',
                                              ),
                                              style: TextStyle(
                                                fontSize: 24.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            if (provider.isWeekendMode) ...[
                                              SizedBox(height: 8.h),
                                              Text(
                                                languageProvider.getMessage(
                                                  'go_live_v2_choose_weekend_shift',
                                                  'Choose your weekend shift',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      const Color(0xFFE91E63),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 20.h),

                                    // Edit preferences button (centered)
                                    _buildEditPreferencesButton(),
                                    SizedBox(height: 24.h),

                                    // Recommendation Card with Top Shift Badge (animated)
                                    SlideTransition(
                                      position: _slideAnimation,
                                      child: FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: _buildRecommendationCard(
                                            currentShift, provider),
                                      ),
                                    ),
                                    SizedBox(height: 40.h),
                                  ],
                                ),
                              ),
              ),

              // Action buttons (only show when not exhausted)
              if (currentShift != null) _buildActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 16.h),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) => Text(
              languageProvider.getMessage(
                'go_live_v2_finding_best_shift',
                'Finding your best shift...',
              ),
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48.sp,
            color: Colors.red,
          ),
          SizedBox(height: 16.h),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) => Column(
              children: [
                Text(
                  languageProvider.getMessage(
                    'go_live_v2_recommendations_load_failed',
                    'Failed to load recommendations',
                  ),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  error,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: _fetchRecommendations,
                  child: Text(languageProvider.getMessage(
                    'go_live_v2_retry',
                    'Retry',
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExhaustedState() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title (centered)
          Consumer<GoLiveV2Provider>(
            builder: (context, provider, _) => Consumer<LanguageProvider>(
              builder: (context, languageProvider, _) => Center(
                child: Text(
                  provider.isWeekendMode
                      ? languageProvider.getMessage(
                          'go_live_v2_go_live_weekend',
                          'Go Live on Weekend',
                        )
                      : languageProvider.getMessage(
                          'go_live_v2_recommendations_title',
                          'Go Live now',
                        ),
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 80.h),

          // Placeholder illustration
          RemoteImageHandler(
            imageUrl: "go_live/illustrationcontainer.png".cdn,
            width: 232.w,
            height: 160.h,
          ),
          SizedBox(height: 32.h),

          // Exhausted message
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) => Column(
              children: [
                Text(
                  languageProvider.getMessage(
                    'go_live_v2_all_options_exhausted',
                    'All your options\nare exhausted.',
                  ),
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  languageProvider.getMessage(
                    'go_live_v2_go_back_begin_again',
                    'Please begin again',
                  ),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: 40.h),

          // Go Back button
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) => SizedBox(
              width: 200.w,
              height: 52.h,
              child: ElevatedButton(
                onPressed: _onGoBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF70F79),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  languageProvider.getMessage(
                    'go_live_v2_start_again',
                    'Start Again',
                  ),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreferencesButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onEditPreferences,
          borderRadius: BorderRadius.circular(24.r),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 10.h,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit,
                  size: 16.sp,
                  color: Colors.black,
                ),
                SizedBox(width: 8.w),
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, _) => Text(
                    languageProvider.getMessage(
                      'go_live_v2_edit_preferences',
                      'Edit your preferences',
                    ),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
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

  Widget _buildRecommendationCard(
      RecommendedShift shift, GoLiveV2Provider provider) {
    // Calculate extra weekend bonus if in weekend mode
    final int? extraWeekendBonus =
        provider.isWeekendMode && provider.selectedShift != null
            ? shift.estimatedMaxEarning -
                provider.selectedShift!.estimatedMaxEarning
            : null;
    final bool showExtraWeekendBonus =
        extraWeekendBonus != null && extraWeekendBonus > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 30.0),
          padding: EdgeInsets.only(
            top: 24.h,
            left: 20.w,
            right: 20.w,
            bottom: 20.h,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: shift.isTopShift
                  ? const Color(0xFF52BD94)
                  : Colors.grey[300]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Stack(
            children: [
              // Background decorative vector (dotted circles pattern)
              if (shift.isTopShift)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: Opacity(
                      opacity: 0.15, // Subtle background
                      child: RemoteImageHandler(
                        imageUrl: "go_live/shift_card_background.png".cdn,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              // Card content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),
                  // Location row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: RemoteImageHandler(
                          imageUrl: "go_live/card_location.png".cdn,
                          width: 20.w,
                          height: 20.h,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${shift.hoodName}, ',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: shift.clusterName,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Shift timings row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: RemoteImageHandler(
                          imageUrl: "go_live/card_calendar.png".cdn,
                          width: 20.w,
                          height: 20.h,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shift.shiftTimings.displayText,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '${shift.durationText} • ${shift.shiftDaysText}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Earnings section with background
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      children: [
                        // Estimated Monthly Earnings with optional Extra Weekend Bonus sub-item
                        _buildEstimatedEarningsWithBonus(
                          amount: '₹${shift.estimatedMaxEarning}',
                          extraWeekendBonus:
                              showExtraWeekendBonus ? extraWeekendBonus : null,
                        ),

                        // Joining Bonus - only show if > 0
                        if (shift.joiningBonus > 0) ...[
                          SizedBox(height: 16.h),
                          Consumer<LanguageProvider>(
                            builder: (context, languageProvider, _) =>
                                _buildEarningsRow(
                              iconUrl: "go_live/bonus.png".cdn,
                              label: languageProvider.getMessage(
                                'go_live_v2_joining_bonus',
                                'Joining Bonus',
                              ),
                              amount: '+ ₹ ${shift.joiningBonus}',
                              isBonus: false,
                            ),
                          ),
                        ],

                        // Top Shift Bonus - only show if > 0
                        if (shift.topShiftBonus > 0) ...[
                          SizedBox(height: 16.h),

                          // Top Shift Bonus
                          Consumer<LanguageProvider>(
                            builder: (context, languageProvider, _) =>
                                _buildEarningsRow(
                              iconUrl: "go_live/rupee_with_bg.png".cdn,
                              label: languageProvider.getMessage(
                                'go_live_v2_top_shift_bonus',
                                'Top Shift Bonus',
                              ),
                              amount: '+ ₹ ${shift.topShiftBonus}',
                              isBonus: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Top Shift Badge - only show if is_top_shift is true
        if (shift.isTopShift)
          Positioned(
            top: -12.h,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(top: 25.0),
                padding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 8.h,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  image: DecorationImage(
                    image: NetworkImage("go_live/top_shift_background.png".cdn),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RemoteImageHandler(
                      imageUrl: "go_live/rupees.png".cdn,
                      width: 16.w,
                      height: 16.h,
                    ),
                    SizedBox(width: 6.w),
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, _) => Text(
                        languageProvider.getMessage(
                          'go_live_v2_top_shift',
                          'Top Shift',
                        ),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the Estimated Monthly Earnings row with an optional
  /// Extra Weekend Bonus sub-item (styled as italic per Figma design)
  Widget _buildEstimatedEarningsWithBonus({
    required String amount,
    int? extraWeekendBonus,
  }) {
    return Column(
      children: [
        // Main row: Estimated Monthly Earnings
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: RemoteImageHandler(
                imageUrl: "go_live/confirm_rupee.png".cdn,
                width: 20.w,
                height: 20.h,
              ),
            ),
            SizedBox(width: 12.w),
            // Label and sub-item column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main label - "Estimated Monthly Earnings"
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, _) => Text(
                      languageProvider.getMessage(
                        'go_live_v2_estimated_monthly_earnings',
                        'Estimated\nMonthly Earnings',
                      ),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6D7783),
                        height: 1.35,
                      ),
                    ),
                  ),
                  // Extra Weekend Bonus sub-item (italic, indented)
                  if (extraWeekendBonus != null) ...[
                    SizedBox(height: 4.h),
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, _) => Padding(
                        padding: EdgeInsets.only(left: 0.w),
                        child: Text(
                          languageProvider.getMessage(
                            'go_live_v2_extra_weekend_bonus',
                            'Extra Weekend Bonus',
                          ),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF6D7783),
                            letterSpacing: -0.24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Amount column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Main amount
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF101840),
                    letterSpacing: -0.6,
                  ),
                ),
                // Extra Weekend Bonus amount (italic)
                if (extraWeekendBonus != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '+$extraWeekendBonus',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF101840),
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
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

  Widget _buildActionButtons() {
    return Consumer<GoLiveV2Provider>(
      builder: (context, provider, child) {
        final isLoading = _isConfirming || provider.isVerifyingShift;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cancel button
              GestureDetector(
                onTap: isLoading ? null : _onCancel,
                child: Container(
                  width: 70.w,
                  height: 70.h,
                  decoration: BoxDecoration(
                    color: isLoading
                        ? const Color(0xFFEF5350).withOpacity(0.5)
                        : const Color(0xFFC50F1F),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 36.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 32.w),

              // Confirm button
              GestureDetector(
                onTap: isLoading ? null : _onConfirm,
                child: Container(
                  width: 70.w,
                  height: 70.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF37A660),
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? Center(
                          child: SizedBox(
                            width: 28.w,
                            height: 28.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 36.sp,
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
