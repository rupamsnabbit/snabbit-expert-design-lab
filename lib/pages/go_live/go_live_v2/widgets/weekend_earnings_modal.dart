import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/shift_hours_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/confirm_shift_timings_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/utils/go_live_v2_tracking.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Modal to ask user if they want to earn more on weekends
class WeekendEarningsModal extends StatelessWidget {
  final GoLiveV2Provider provider;

  const WeekendEarningsModal({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop(); // Close modal
                navigator.pushNamed(ConfirmShiftTimingsScreen.routeName);
              },
              child: Icon(
                Icons.close,
                size: 28.sp,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: 24.h),

          RemoteImageHandler(
            imageUrl: "go_live/rupee_coin_modal.png".cdn,
            width: 96.w,
            height: 96.h,
          ),
          SizedBox(height: 32.h),

          // Title
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) => Text(
              languageProvider.getMessage(
                'go_live_v2_weekend_earnings_title',
                'Do you want to earn more\non Saturday & Sunday?',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 32.h),

          // Yes button
          GestureDetector(
            onTap: () {
              provider.setHasSelectedWeekend(true);
              // Track weekend prompt response
              GoLiveV2Tracking.trackWeekendPromptResponse(response: true);
              // debugPrint(
              //     '[WeekendEarningsModal] User selected YES - hasSelectedWeekend: true');
              final navigator = Navigator.of(context);
              navigator.pop(); // Close modal
              navigator.pushNamed(ShiftHoursScreen.weekendRouteName);
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF70F79), // Pink/Magenta color
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Consumer<LanguageProvider>(
                  builder: (context, languageProvider, _) => Text(
                    languageProvider.getMessage(
                      'go_live_v2_yes',
                      'Yes',
                    ),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // No button
          GestureDetector(
            onTap: () {
              provider.setHasSelectedWeekend(false);
              // Track weekend prompt response
              GoLiveV2Tracking.trackWeekendPromptResponse(response: false);
              // debugPrint(
              //     '[WeekendEarningsModal] User selected NO - hasSelectedWeekend: false');
              final navigator = Navigator.of(context);
              navigator.pop(); // Close modal
              navigator.pushNamed(ConfirmShiftTimingsScreen.routeName);
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Consumer<LanguageProvider>(
                  builder: (context, languageProvider, _) => Text(
                    languageProvider.getMessage(
                      'go_live_v2_no',
                      'No',
                    ),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}
