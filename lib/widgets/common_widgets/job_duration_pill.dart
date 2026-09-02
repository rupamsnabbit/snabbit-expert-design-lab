import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Stateless pill-shaped widget that displays a job duration with a clock icon.
class JobDurationPill extends StatelessWidget {
  /// Duration in minutes to display (e.g. 45 → "45 Mins").
  final int duration;

  const JobDurationPill({
    super.key,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final durationStyle = textTheme.displayLarge?.copyWith(
      fontSize: 16.sp,
      color: AppColors.n90,
      letterSpacing: -0.194911,
    );

    return Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: Color(0xFF9FD4FD),
          borderRadius: BorderRadius.circular(40.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_filled_rounded,
              size: 18.r,
              color: Colors.black,
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  languageProvider.getFormattedMessage('duration_Mins', '{{duration}} Mins',
                      {
                    'duration': duration,
                      }),
                  style: durationStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
