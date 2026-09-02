import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/go_live_recommendations_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/shift_time_selection_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/utils/go_live_v2_tracking.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/widgets/go_live_progress_indicator.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/remote_config/go_live_feature_flags.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Screen 2: Select shift hours duration
class ShiftHoursScreen extends StatefulWidget {
  static const String routeName = '/go-live-v2/shift-hours';
  static const String weekendRouteName = '/go-live-v2/weekend-shift-hours';

  const ShiftHoursScreen({super.key});

  @override
  State<ShiftHoursScreen> createState() => _ShiftHoursScreenState();
}

class _ShiftHoursScreenState extends State<ShiftHoursScreen> {
  int? selectedBucketIndex;
  bool _isLoading = false;
  late List<ShiftHoursBucket> shiftTimeBuckets;

  @override
  void initState() {
    super.initState();
    // Load shift hours from remote config
    _loadShiftHours();
  }

  void _loadShiftHours() {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    // Fetch from remote config based on weekend mode
    final configBuckets = provider.isWeekendMode
        ? GoLiveFeatureFlags.getWeekendShiftHours()
        : GoLiveFeatureFlags.getWeekdayShiftHours();

    // Convert remote config models to UI models
    var buckets = configBuckets.map((config) {
      return ShiftHoursBucket(
        startHours: config.startHours,
        endHours: config.endHours,
        potentialEarnings: config.potentialEarnings,
      );
    }).toList();

    // Filter weekend options based on weekday selection
    // Weekend shift hours must have startHours >= weekday startHours
    if (provider.isWeekendMode && provider.shiftMinHours != null) {
      final weekdayMinHours = provider.shiftMinHours!;
      buckets = buckets
          .where((bucket) => bucket.startHours >= weekdayMinHours)
          .toList();
    }

    shiftTimeBuckets = buckets;

    // debugPrint(
    //     '[ShiftHoursScreen] Loaded ${shiftTimeBuckets.length} shift hours buckets from remote config (isWeekendMode: ${provider.isWeekendMode})');
    // for (var i = 0; i < shiftTimeBuckets.length; i++) {
    //   final bucket = shiftTimeBuckets[i];
    //   debugPrint(
    //       '  - Bucket $i: ${bucket.startHours}-${bucket.endHours}h, ₹${bucket.potentialEarnings[0]}-${bucket.potentialEarnings[1]}');
    // }

    // Track screen load
    GoLiveV2Tracking.trackShiftHoursSelectionLoad(
      buckets:
          shiftTimeBuckets.map((b) => '${b.startHours}-${b.endHours}').toList(),
      isWeekend: provider.isWeekendMode,
    );
  }

  void _onShiftSelected(int index) {
    setState(() {
      selectedBucketIndex = index;
    });
  }

  Future<void> _onContinue() async {
    if (selectedBucketIndex == null) {
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(languageProvider.getMessage(
          'go_live_v2_select_shift_hours_error',
          'Please select shift hours',
        ))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save selection to provider using actual hour values from bucket
      final goLiveV2Provider =
          Provider.of<GoLiveV2Provider>(context, listen: false);
      final selectedBucket = shiftTimeBuckets[selectedBucketIndex!];

      if (goLiveV2Provider.isWeekendMode) {
        goLiveV2Provider.setWeekendShiftHours(
          selectedBucket.startHours,
          selectedBucket.endHours,
        );
      } else {
        goLiveV2Provider.setShiftHours(
          selectedBucket.startHours,
          selectedBucket.endHours,
        );
      }

      // Track shift hours CTA
      await GoLiveV2Tracking.trackShiftHoursSelectionCta(
        bucketSelected:
            '${selectedBucket.startHours}-${selectedBucket.endHours}',
        isWeekend: goLiveV2Provider.isWeekendMode,
      );

      // Log selection
      // debugPrint(
      //     '[ShiftHoursScreen] ✅ Continue pressed (isWeekendMode: ${provider.isWeekendMode})');
      // debugPrint(
      //     '[ShiftHoursScreen] Selected bucket index: $selectedBucketIndex');
      // debugPrint(
      //     '[ShiftHoursScreen] Hours range: ${selectedBucket.startHours}-${selectedBucket.endHours} hours');
      // debugPrint(
      //     '[ShiftHoursScreen] Data stored in: GoLiveV2Provider (minHours: ${selectedBucket.startHours}, maxHours: ${selectedBucket.endHours})');

      // If weekend mode, call the weekend recommended shifts API and wait for it
      // NOTE: API is now called in GoLiveRecommendationsScreen to match weekday flow
      // Just log and continue
      if (goLiveV2Provider.isWeekendMode) {
        // debugPrint(
        //     '[ShiftHoursScreen] 🔄 Weekend mode - will navigate to time selection screen');
        // debugPrint(
        //     '[ShiftHoursScreen] ➡️ API will be called in GoLiveRecommendationsScreen');
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // Navigate to next screen based on weekend mode
      final targetRoute = goLiveV2Provider.isWeekendMode
          ? ShiftTimeSelectionScreen.weekendRouteName
          : ShiftTimeSelectionScreen.routeName;
      Navigator.pushNamed(context, targetRoute);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageProvider.getMessage(
            'go_live_v2_error_occurred',
            'An error occurred: $e',
          )),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleBackPressed() {
    final goLiveV2Provider =
        Provider.of<GoLiveV2Provider>(context, listen: false);

    if (goLiveV2Provider.isWeekendMode) {
      // Reset weekend selection state when going back from weekend flow
      goLiveV2Provider.setHasSelectedWeekend(false);
      // Navigate to weekday recommendations screen instead of default pop
      Navigator.pushReplacementNamed(
        context,
        GoLiveRecommendationsScreen.routeName,
      );
    } else {
      // Default back navigation for weekday flow
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goLiveV2Provider = Provider.of<GoLiveV2Provider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: CommonAppBar(
          title: const SizedBox.shrink(),
          onBackPressed: _handleBackPressed,
        ),
        body: Column(
          children: [
            // Progress indicator (only show in regular mode)
            if (!goLiveV2Provider.isWeekendMode)
              const GoLiveProgressIndicator(currentStep: 3, totalSteps: 5),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon
                    RemoteImageHandler(
                      imageUrl: "go_live/clock_shift.png".cdn,
                      width: 72.w,
                      height: 72.h,
                    ),
                    SizedBox(height: 8.h),

                    // Title
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, _) => Text(
                        goLiveV2Provider.isWeekendMode
                            ? languageProvider.getMessage(
                                'go_live_v2_weekend_shift_hours_title',
                                'Select your weekend shift hours',
                              )
                            : languageProvider.getMessage(
                                'go_live_v2_shift_hours_title',
                                'Select your shift hours',
                              ),
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Shift options list using ListView.builder for better performance
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: shiftTimeBuckets.length,
                      itemBuilder: (context, index) =>
                          _buildShiftOption(shiftTimeBuckets[index]),
                    ),
                  ],
                ),
              ),
            ),

            // Continue button
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftOption(ShiftHoursBucket bucket) {
    final index = shiftTimeBuckets.indexOf(bucket);
    final isSelected = selectedBucketIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h, top: 16.h),
      child: Material(
        color: isSelected ? const Color(0xFFFCF0F7) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: () => _onShiftSelected(index),
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF50C8F).withOpacity(0.1)
                    : const Color(0xFFD8DAE5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Duration text
                      Text(
                        bucket.displayText,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF313131),
                        ),
                      ),
                      SizedBox(height: 4.h),

                      // Subtitle
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, _) => Text(
                          languageProvider.getMessage(
                            'go_live_v2_total_hours_work',
                            'Total hours of work',
                          ),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6D7783),
                            letterSpacing: -0.12,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Earnings range with teal border
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, _) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF52BD94),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                          child: Text(
                            languageProvider.getMessage(
                              'go_live_v2_potential_earnings',
                              'Potential earnings = ₹${bucket.potentialEarningsFormatted}',
                            ),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF52BD94),
                              letterSpacing: -0.11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),

                // Radio button
                Container(
                  width: 24.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? null
                        : Border.all(
                            color: const Color(0xFFF0F0F0),
                            width: 2,
                          ),
                    color: isSelected ? const Color(0xFFF70F79) : null,
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10.w,
                            height: 10.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Center(
                          child: Container(
                            width: 5.w,
                            height: 5.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
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

  Widget _buildContinueButton() {
    final bool canContinue = selectedBucketIndex != null && !_isLoading;

    return Container(
      padding: EdgeInsets.all(20.w),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canContinue ? _onContinue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _isLoading ? AppColors.brand.withOpacity(0.7) : AppColors.brand,
            disabledBackgroundColor: Colors.grey[300],
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Consumer<LanguageProvider>(
                  builder: (context, languageProvider, _) => Text(
                    languageProvider.getMessage(
                      'go_live_v2_continue',
                      'Continue',
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
    );
  }
}

// Models
/// Represents a shift hours bucket configurable from Firebase Remote Config
/// Each bucket defines a time range and potential earnings range
class ShiftHoursBucket {
  final int startHours;
  final int endHours;
  final List<int> potentialEarnings; // [minEarnings, maxEarnings]

  ShiftHoursBucket({
    required this.startHours,
    required this.endHours,
    required this.potentialEarnings,
  });

  /// Display text like "4 hours to 8 hours"
  String get displayText => '$startHours hours to $endHours hours';

  /// Formatted earnings like "15,000 to 24,000"
  String get potentialEarningsFormatted =>
      '${_formatNumber(potentialEarnings[0])} to ₹${_formatNumber(potentialEarnings[1])}';

  static String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
