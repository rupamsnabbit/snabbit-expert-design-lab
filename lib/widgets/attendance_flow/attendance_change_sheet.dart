import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/gamification/shared_red_card_widgets.dart';
import 'package:snabbit_runner/widgets/gamification/sheet_warning_attendance.dart';

/// Headline for provisional/confirmed “not coming” sheets (matches parent question).
String attendanceChangeSheetHeadlineForShift(
  LanguageProvider lang,
  Map<String, dynamic>? widgetData,
) {
  final d = widgetData ?? {};
  final useTomorrowCopy =
      d['next_shift_tomorrow'] == true || d['type'] == 'TOMORROW';
  if (useTomorrowCopy) {
    return lang.getMessage(
      'are_you_coming_tomorrow',
      'Are you coming tomorrow?',
    );
  }
  return lang.getFormattedMessage(
    'are_you_coming_x_day',
    'Are you coming on {{x_day}}?',
    {'x_day': d['date'] ?? ''},
  );
}

enum _SheetPhase { changePenalty, changePenaltyWithLeave, markPeriodLeave }

/// Multi-state attendance change confirmation bottom sheet.
///
/// Manages 3 phases:
/// - [_SheetPhase.changePenalty]: penalty with no period leave option
/// - [_SheetPhase.changePenaltyWithLeave]: penalty with period leave toggle
/// - [_SheetPhase.markPeriodLeave]: period leave selected, confirm marking
class AttendanceChangeSheet extends StatefulWidget {
  /// Same [AttendanceSheetLifecycle] value used when computing [redCardCount] at
  /// the call site — must match or CTA badges and [RedCardIllustration] disagree.
  final String sheetWarningLifecycle;

  final VoidCallback onMarkAbsent;
  final VoidCallback? onMarkPresent;
  final VoidCallback? onMarkAbsentWithPeriodLeave;
  final int redCardCount;
  final bool periodLeaveAvailable;

  /// Whether period leave is even a valid concept in this flow. Defaults to
  /// true. Callers that never offer period leave (e.g. absent→present switch
  /// in [attendance_absent.dart]) should pass false so the BCP "temporarily
  /// unavailable" inline message is also suppressed for them.
  final bool supportsPeriodLeave;

  /// When non-null, uses simple chrome (gray circle, no shimmer/badges) even if
  /// the backend sends nudges — for provisional/confirmed/absent reversal flows.
  final String? headlineOverride;

  /// Identifies which screen opened this sheet, for analytics.
  /// Values: 'job_login', 'attendance_confirmed', 'attendance_absent'.
  final String entrySource;

  const AttendanceChangeSheet({
    super.key,
    required this.sheetWarningLifecycle,
    required this.onMarkAbsent,
    this.onMarkPresent,
    this.onMarkAbsentWithPeriodLeave,
    required this.redCardCount,
    required this.periodLeaveAvailable,
    this.supportsPeriodLeave = true,
    this.headlineOverride,
    required this.entrySource,
  });

  @override
  State<AttendanceChangeSheet> createState() => _AttendanceChangeSheetState();
}

class _AttendanceChangeSheetState extends State<AttendanceChangeSheet> {
  bool _isPeriodLeaveChecked = false;

  // Figma colour tokens
  static const _gray800 = Color(0xFF1F2937);
  static const _red600 = Color(0xFFDC2626);
  static const _green600 = Color(0xFF059669);

  _SheetPhase _phaseFor(int periodLeaveRemaining) {
    final showPeriodLeaveRow =
        widget.periodLeaveAvailable && periodLeaveRemaining > 0;
    if (_isPeriodLeaveChecked && showPeriodLeaveRow) {
      return _SheetPhase.markPeriodLeave;
    }
    if (widget.periodLeaveAvailable) return _SheetPhase.changePenaltyWithLeave;
    return _SheetPhase.changePenalty;
  }

  Map<String, dynamic> _baseProps() => {
        'entry_source': widget.entrySource,
        'sheet_warning_lifecycle': widget.sheetWarningLifecycle,
        'period_leave_available': widget.periodLeaveAvailable,
        'red_card_count': widget.redCardCount,
      };

  void _trackBsLoad() {
    final props = _baseProps();
    MixpanelSetup.logEvent(TrackingEvents.changeAttendanceBsLoad, props);
  }

  void _trackCtaClick(String ctaType) {
    final remaining = context.read<PeriodLeaveProvider>().periodLeaveRemaining;
    final showRow = widget.periodLeaveAvailable && remaining > 0;
    final props = <String, dynamic>{
      ..._baseProps(),
      'cta_type': ctaType,
      'period_leave_selected': showRow && _isPeriodLeaveChecked,
    };
    MixpanelSetup.logEvent(TrackingEvents.changeAttendanceCtaClick, props);
  }

  void _trackPeriodLeaveSelection(bool selected) {
    final props = <String, dynamic>{
      'source': 'change_attendance',
      'entry_source': widget.entrySource,
      'selected': selected,
    };
    MixpanelSetup.logEvent(TrackingEvents.periodLeaveSelectionCta, props);
  }

  @override
  void initState() {
    super.initState();
    _trackBsLoad();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final periodLeaveRemaining =
        context.watch<PeriodLeaveProvider>().periodLeaveRemaining;
    final runnerRtData = context.watch<RunnerRtDataProvider>();
    final phase = _phaseFor(periodLeaveRemaining);

    final sheetNudges = filterSheetWarnings(
      runnerRtData.sheetWarnings,
      widget.sheetWarningLifecycle,
    );
    final ctaMap = ctaOverridesForSheet(sheetNudges);
    final primaryCta = ctaMap[AttendanceSheetCtaIds.markAbsent];
    final secondaryCta = ctaMap[AttendanceSheetCtaIds.goBack];

    final isMarkPeriodLeave = phase == _SheetPhase.markPeriodLeave;
    final hasNudges = sheetNudges.isNotEmpty;
    final useSimpleChrome = widget.headlineOverride != null;
    final showPenaltyChrome = hasNudges && !useSimpleChrome;

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
          if (showPenaltyChrome)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
              child: SizedBox(
                height: 185.h,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: kNudgesBottomSheetBackgroundUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

          // Content
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
                if (showPenaltyChrome)
                  Opacity(
                    opacity: isMarkPeriodLeave ? 0.20 : 1.0,
                    child: RedCardIllustration(
                      count: widget.redCardCount.clamp(1, 9),
                    ),
                  )
                else
                  Container(
                    width: 100.r,
                    height: 100.r,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(99.r),
                    ),
                    child: Image.asset(
                      // image,
                      'assets/pngs/attendance_icon.png',
                      width: 100.r,
                      height: 100.r,
                      fit: BoxFit.contain,
                    ),
                  ),

                SizedBox(height: 16.h),

                // Title — Figma: Outfit Semibold 24sp, line-height 32, #1f2937
                SizedBox(
                  width: 327.w,
                  child: Text(
                    isMarkPeriodLeave
                        ? lang.getMessage(
                            'confirm_period_leave',
                            'Are you sure you want to mark Period Leave?',
                          )
                        : widget.headlineOverride ??
                            lang.getMessage(
                              'confirm_change_attendance',
                              'Are you sure you want to change attendance?',
                            ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: _gray800,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      height: 32 / 24,
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                // Period leave checkbox (States 2 & 3)
                if (widget.periodLeaveAvailable &&
                    periodLeaveRemaining > 0) ...[
                  _PeriodLeaveRow(
                    isChecked: _isPeriodLeaveChecked,
                    availableCount: periodLeaveRemaining,
                    lang: lang,
                    onChanged: (val) {
                      setState(() {
                        _isPeriodLeaveChecked = val;
                      });
                      _trackPeriodLeaveSelection(val);
                    },
                  ),
                  SizedBox(height: 32.h),
                ] else if (widget.supportsPeriodLeave &&
                    context.watch<PeriodLeaveProvider>().degradedFromBcp) ...[
                  _PeriodLeaveUnavailableMessage(lang: lang),
                  SizedBox(height: 32.h),
                ],
                // Buttons — Figma: Row, gap 12, both 174.5w x 48h
                if (isMarkPeriodLeave) ...[
                  // State 3: full-width "Absent" button (no badge)
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () {
                        _trackCtaClick('absent_with_period_leave');
                        widget.onMarkAbsentWithPeriodLeave?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        lang.getMessage('absent', 'Absent'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.white,
                          letterSpacing: -0.24,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // States 1-2: "Absent" + "Present" in a row
                  Row(
                    children: [
                      // Absent button — Figma: red-600, 174.5w x 48h
                      Expanded(
                        child: SizedBox(
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: () {
                              _trackCtaClick('absent');
                              widget.onMarkAbsent();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _red600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                            ),
                            child: attendanceSheetCtaButtonChild(
                              context,
                              cta: showPenaltyChrome ? primaryCta : null,
                              languageProvider: lang,
                              fallbackKey: 'absent',
                              fallbackEnglish: 'Absent',
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Present button — Figma: green-600, flex-1 x 48h
                      Expanded(
                        child: SizedBox(
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: () {
                              _trackCtaClick('present');
                              if (widget.onMarkPresent != null) {
                                widget.onMarkPresent!();
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                            ),
                            child: attendanceSheetCtaButtonChild(
                              context,
                              cta: showPenaltyChrome ? secondaryCta : null,
                              languageProvider: lang,
                              fallbackKey: 'present',
                              fallbackEnglish: 'Present',
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Inline message shown in place of the period-leave row when the
// period_leave/availability API is currently BCP-degraded.
class _PeriodLeaveUnavailableMessage extends StatelessWidget {
  final LanguageProvider lang;
  const _PeriodLeaveUnavailableMessage({required this.lang});

  static const _gray100 = Color(0xFFF3F4F6);
  static const _gray700 = Color(0xFF374151);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: _gray100,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        lang.getMessage(
          'period_leave_temporarily_unavailable',
          'Period leave is temporarily unavailable',
        ),
        style: TextStyle(
          fontFamily: 'Outfit',
          color: _gray700,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          height: 20 / 14,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period leave row — Figma: gray-100 bg, rounded-12, blood drop icon, checkbox
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodLeaveRow extends StatelessWidget {
  final bool isChecked;
  final int availableCount;
  final LanguageProvider lang;
  final ValueChanged<bool> onChanged;

  const _PeriodLeaveRow({
    required this.isChecked,
    required this.availableCount,
    required this.lang,
    required this.onChanged,
  });

  static const _gray100 = Color(0xFFF3F4F6);
  static const _gray300 = Color(0xFFD1D5DB);
  static const _gray900 = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isChecked),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: _gray100,
          border: Border.all(color: _gray100),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: icon + text
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 5.w),
                // Blood drop icon
                CachedNetworkImage(
                  imageUrl:
                      'https://assets-expert.snabbit.com/period_leave/period_leave_drop.png',
                  width: 15.w,
                  height: 18.h,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => Icon(
                    Icons.water_drop,
                    size: 18.sp,
                    color: Colors.red,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  lang.getFormattedMessage(
                    'period_leave_with_available',
                    'Period leave ({{count}} Available)',
                    {'count': availableCount},
                  ),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: _gray900,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    height: 24 / 16,
                  ),
                ),
              ],
            ),
            // Right: checkbox — Figma: 24x24, rounded-4
            SizedBox(
              width: 24.r,
              height: 24.r,
              child: Checkbox(
                value: isChecked,
                onChanged: (val) => onChanged(val ?? false),
                activeColor: _gray900,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.r),
                ),
                side: BorderSide(
                  color: _gray300,
                  width: 2.4,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
