import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/gamification/post_action_outcome.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/gamification/resolve_nudge_label.dart';
import 'package:snabbit_runner/widgets/gamification/shared_red_card_widgets.dart';

/// Waiver warning bottom sheet — Figma 6705:143542.
///
/// Shown when a penalty action returns `status: 'WAIVED'`. Displays a warning
/// badge, stylised red-card illustration, outcome title, and a dismissible
/// "I will not repeat" button.
class WaiverBottomSheet extends StatelessWidget {
  const WaiverBottomSheet({super.key, required this.outcome});

  final PostActionOutcome outcome;

  /// Shows the waiver bottom sheet. Returns a Future that completes when
  /// the user dismisses it.
  static Future<void> show(BuildContext context, PostActionOutcome outcome) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => WaiverBottomSheet(outcome: outcome),
    );
  }

  // ── Figma colour tokens ──
  static const _gray800 = Color(0xFF1F2937);
  static const _yellow50 = Color(0xFFFFFBEB);
  static const _yellow600 = Color(0xFFD97706);
  static const _greenDark = Color(0xFF317159);
  static const _greenLight = Color(0xFF429777);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final resolvedTitle = resolveNudgeLabel(outcome.label, lang);
    final titleText = resolvedTitle.trim().isEmpty
        ? lang.getMessage(
            'waiver_outcome_title_fallback',
            'No red card applied',
          )
        : resolvedTitle;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      child: Stack(
        children: [
          // ── Shimmer stripe decoration (Figma 6705:143543) ──
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
            ),
            child: Opacity(
              opacity: 0.20,
              child: SizedBox(
                height: 185.h,
                width: double.infinity,
                child: const ShimmerStripes(),
              ),
            ),
          ),

          // ── Content ──
          Padding(
            padding: EdgeInsets.only(
              left: 16.w,
              right: 16.w,
              top: 24.h,
              bottom: 48.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Warning pill badge (Figma 6705:143554) ──
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: _yellow600,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        size: 16.sp,
                        color: _yellow50,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        lang.getMessage('warning', 'Warning'),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: _yellow50,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          height: 20 / 14,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12.h),

                // ── Red card illustration at 20% opacity (Figma 6705:143559) ──
                Opacity(
                  opacity: 0.40,
                  child: RedCardIllustration(
                    count: outcome.redCards,
                  ),
                ),

                SizedBox(height: 12.h),

                // ── Title — e.g. "No red card applied" (Figma 6705:143569) ──
                Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: _gray800,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    height: 32 / 24,
                  ),
                ),

                SizedBox(height: 24.h),

                // ── "I will not repeat" button (Figma 6705:143571) ──
                SizedBox(
                  width: double.infinity,
                  height: 47.h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      gradient: const LinearGradient(
                        colors: [_greenDark, _greenLight],
                      ),
                    ),
                    child: MaterialButton(
                      onPressed: () => Navigator.of(context).pop(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        lang.getMessage(
                            'i_will_not_repeat', 'I will not repeat'),
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
