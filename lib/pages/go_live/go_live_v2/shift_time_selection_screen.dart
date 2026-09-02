import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/shift_time_bucket.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/go_live_recommendations_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/utils/go_live_v2_tracking.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/widgets/go_live_progress_indicator.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/remote_config/go_live_feature_flags.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Screen 3: Select shift start time
class ShiftTimeSelectionScreen extends StatefulWidget {
  static const String routeName = '/go-live-v2/shift-time-selection';
  static const String weekendRouteName =
      '/go-live-v2/weekend-shift-time-selection';

  const ShiftTimeSelectionScreen({super.key});

  @override
  State<ShiftTimeSelectionScreen> createState() =>
      _ShiftTimeSelectionScreenState();
}

class _ShiftTimeSelectionScreenState extends State<ShiftTimeSelectionScreen> {
  ShiftTimeBucket? selectedShiftTime;
  late List<ShiftTimeBucket> timeOptions;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    timeOptions = provider.isWeekendMode
        ? GoLiveFeatureFlags.getWeekendShiftTime()
        : GoLiveFeatureFlags.getWeekdayShiftTime();

    // Track screen load
    GoLiveV2Tracking.trackStartTimeSelectionLoad(
      buckets: timeOptions.map((b) => b.timeText).toList(),
      isWeekend: provider.isWeekendMode,
    );
  }

  void _onTimeSelected(ShiftTimeBucket timeBucket) {
    setState(() {
      selectedShiftTime = timeBucket;
    });
  }

  void _onContinue() {
    if (selectedShiftTime == null) {
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(languageProvider.getMessage(
          'go_live_v2_select_shift_start_time_error',
          'Please select shift start time',
        ))),
      );
      return;
    }

    // Save to provider
    final goLiveV2Provider =
        Provider.of<GoLiveV2Provider>(context, listen: false);

    if (goLiveV2Provider.isWeekendMode) {
      goLiveV2Provider.setWeekendShiftTime(selectedShiftTime!);
    } else {
      goLiveV2Provider.setShiftTime(selectedShiftTime!);
    }

    // Track start time CTA
    GoLiveV2Tracking.trackStartTimeSelectionCta(
      bucketSelected: selectedShiftTime!.timeText,
      isWeekend: goLiveV2Provider.isWeekendMode,
    );

    // Navigate to go live recommendations screen (based on weekend mode from provider)
    Navigator.pushNamed(
      context,
      goLiveV2Provider.isWeekendMode
          ? GoLiveRecommendationsScreen.weekendRouteName
          : GoLiveRecommendationsScreen.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final goLiveV2Provider = Provider.of<GoLiveV2Provider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        title: const SizedBox.shrink(),
      ),
      body: Column(
        children: [
          // Progress indicator (only show in regular mode)
          if (!goLiveV2Provider.isWeekendMode)
            const GoLiveProgressIndicator(currentStep: 4, totalSteps: 5),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  RemoteImageHandler(
                    imageUrl: "go_live/screen_calendar.png".cdn,
                    width: 72.w,
                    height: 72.h,
                  ),
                  SizedBox(height: 4.h),

                  // Title
                  Consumer<GoLiveV2Provider>(
                    builder: (context, provider, _) =>
                        Consumer<LanguageProvider>(
                      builder: (context, languageProvider, _) => Text(
                        provider.isWeekendMode
                            ? languageProvider.getMessage(
                                'go_live_v2_weekend_shift_start_time_title',
                                'Select your weekend shift start time',
                              )
                            : languageProvider.getMessage(
                                'go_live_v2_shift_start_time_title',
                                'Select your shift start time',
                              ),
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Time options list
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: timeOptions.length,
                    itemBuilder: (context, index) =>
                        _buildTimeOption(timeOptions[index]),
                  ),
                ],
              ),
            ),
          ),

          // Continue button
          _buildContinueButton(),
        ],
      ),
    );
  }

  Widget _buildTimeOption(ShiftTimeBucket option) {
    final isSelected = selectedShiftTime?.timeText == option.timeText;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h, top: 12.h),
      child: Material(
        color: isSelected ? const Color(0xFFFCF0F7) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: () => _onTimeSelected(option),
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF50C8F).withOpacity(0.1)
                    : const Color(0xFFD8DAE5),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Time text
                Text(
                  option.timeText,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF313131),
                    height: 18 / 14,
                  ),
                ),

                // Radio button
                Container(
                  width: 24.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? null
                        : Border.all(
                            color: const Color(0xFFD8DAE5),
                            width: 1.5,
                          ),
                    color: isSelected ? const Color(0xFFF70F79) : null,
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 8.w,
                            height: 8.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final bool canContinue = selectedShiftTime != null;

    return Container(
      padding: EdgeInsets.all(20.w),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canContinue ? _onContinue : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF70F79),
            disabledBackgroundColor: Colors.grey[300],
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
          child: Consumer<LanguageProvider>(
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
