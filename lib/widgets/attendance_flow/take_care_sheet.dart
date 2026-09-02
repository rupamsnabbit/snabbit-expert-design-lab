import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

/// Standalone "Take care!" bottom sheet shown after successful period leave.
///
/// Figma node 7455:41537 — white bg, 24 top / 40 bottom padding, 24 top radius,
/// heart illustration, title + caption, full-width primary button.
class TakeCareSheet extends StatelessWidget {
  const TakeCareSheet({super.key});

  // Figma colour tokens
  static const _gray800 = Color(0xFF1F2937);
  static const _gray500 = Color(0xFF6B7280);
  static const _gray900 = Color(0xFF111827);

  /// [source] identifies which flow opened this sheet, for analytics.
  /// Values: 'emergency_logout', 'false_attendance'.
  static Future<void> show(BuildContext context, {required String source}) {
    final props = <String, dynamic>{'source': source};
    MixpanelSetup.logEvent(TrackingEvents.takeCareBsLoad, props);
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TakeCareSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 24.h,
          bottom: 40.h + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Heart illustration + title + subtitle — 16 between art and text, 4 between lines
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Heart illustration — Figma: 100×100
                CachedNetworkImage(
                  imageUrl:
                      'https://assets-expert.snabbit.com/period_leave/take_care_heart.png',
                  width: 100.r,
                  height: 100.r,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => Container(
                    width: 100.r,
                    height: 100.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFCE4EC),
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: 50.sp,
                      color: Colors.redAccent,
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Title + subtitle — gap 4
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "Take care!" — Outfit Semibold 24sp, #1f2937
                    Text(
                      lang.getMessage('take_care', 'Take care!'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: _gray800,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w600,
                        height: 32 / 24,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    // "No red card applied" — Caption/12-Medium, #6b7280
                    Text(
                      lang.getMessage(
                        'no_red_card_applied',
                        'No red card applied',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: _gray500,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        height: 16 / 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 40.h),

            // Primary button — gray-900, 48h, radius 8, full width
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gray900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  lang.getMessage('ok', 'Okay'),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    height: 24 / 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
