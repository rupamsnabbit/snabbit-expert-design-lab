import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/gamification/cta_override.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/models/gamification/sheet_warning.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/attendance_flow/take_care_sheet.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/gamification/cta_badge.dart';
import 'package:snabbit_runner/widgets/gamification/shared_red_card_widgets.dart';
import 'package:snabbit_runner/widgets/gamification/sheet_warning_attendance.dart';

/// Full Shift penalty card — matches Figma (Expert App 2.0) alongside red cards.
const String _kFullShiftCardImageUrl =
    'https://assets-expert.snabbit.com/payouts/nudges/full_shift_card.png';

/// Rate card v2: dedicated [JobHttp.emergencyLogout] + gamification / period leave.
/// Rate card v1 uses [showEmergencyLogoutConfirmationV1] instead.
class EmergencyLogoutConfirmation extends StatefulWidget {
  /// Remaining emergency logouts when opened from the drawer (optional header).
  final int? emergencyLogoutsAvailable;

  /// From `GET .../emergency_logout/availability` → `sheet_warnings` (not from runner app state).
  final List<SheetWarning> sheetWarnings;

  /// Earning loss amount from the availability API (`earning_loss` field).
  /// When > 0, the title changes to show the earning loss prominently.
  final num? earningLoss;

  const EmergencyLogoutConfirmation({
    super.key,
    this.emergencyLogoutsAvailable,
    required this.sheetWarnings,
    this.earningLoss,
  });

  @override
  State<EmergencyLogoutConfirmation> createState() =>
      _EmergencyLogoutConfirmationState();
}

class _EmergencyLogoutConfirmationState
    extends State<EmergencyLogoutConfirmation> {
  bool _loading = false;
  bool _isPeriodLeaveChecked = false;
  String? _error;
  bool _bsLoadTracked = false;

  // Figma colour tokens
  static const _gray300 = Color(0xFFD1D5DB);
  static const _gray800 = Color(0xFF1F2937);
  static const _gray900 = Color(0xFF111827);
  static const _red600 = Color(0xFFDC2626);

  /// Builds analytics props from current state. Called at sheet load and
  /// each CTA click so the snapshot reflects the user's view at that
  /// moment (period leave toggle, etc.).
  Map<String, dynamic> _baseProps() {
    final earningLoss = widget.earningLoss ?? 0;
    final periodLeaveAvailable =
        context.read<PeriodLeaveProvider>().periodLeaveAvailable;
    final sheetNudges = filterSheetWarnings(
      widget.sheetWarnings,
      LifecycleActionType.emergencyLogout,
    );
    final ctaMap = ctaOverridesForSheet(sheetNudges);
    final logoutRedCards = ctaMap[CtaId.logout]?.redCards ?? 0;
    return {
      'period_leave_available': periodLeaveAvailable,
      'earnings_amount_shown': earningLoss,
      'earnings_copy_visible': earningLoss > 0,
      'red_cards_shown': logoutRedCards,
      'emergency_logouts_available': widget.emergencyLogoutsAvailable,
    };
  }

  void _trackBsLoadIfNeeded() {
    if (_bsLoadTracked) return;
    _bsLoadTracked = true;
    final props = _baseProps();
    MixpanelSetup.logEvent(TrackingEvents.emergencyLogoutBsLoad, props);
  }

  bool _effectivePeriodLeaveSelected() {
    final p = context.read<PeriodLeaveProvider>();
    // Must match [build]: row is shown when period leave is available, not the opposite.
    final showRow = p.periodLeaveAvailable && p.periodLeaveRemaining > 0;
    return showRow && _isPeriodLeaveChecked;
  }

  void _trackCtaClick(String ctaType) {
    final props = <String, dynamic>{
      ..._baseProps(),
      'cta_type': ctaType,
      'period_leave_selected': _effectivePeriodLeaveSelected(),
    };
    MixpanelSetup.logEvent(TrackingEvents.emergencyLogoutCtaClick, props);
  }

  void _trackCtaClickError(int? statusCode, dynamic responseData) {
    final props = <String, dynamic>{
      ..._baseProps(),
      'period_leave_selected': _effectivePeriodLeaveSelected(),
      'status_code': statusCode,
      'error_text': responseData?.toString(),
    };
    MixpanelSetup.logEvent(TrackingEvents.emergencyLogoutCtaClickError, props);
  }

  void _trackPeriodLeaveSelection(bool selected) {
    final props = <String, dynamic>{
      'source': 'emergency_logout',
      'selected': selected,
    };
    MixpanelSetup.logEvent(TrackingEvents.periodLeaveSelectionCta, props);
  }

  @override
  Widget build(BuildContext context) {
    // Fire screen-load once when the widget first renders. Doing this
    // here (instead of initState) avoids the no-context-in-initState
    // gotcha and the post-frame callback dance.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _trackBsLoadIfNeeded();
    });
    final lang = context.watch<LanguageProvider>();
    final earningLoss = widget.earningLoss ?? 0;
    final hasEarningLoss = earningLoss > 0;
    final periodLeave = context.watch<PeriodLeaveProvider>();
    final showPeriodLeave = periodLeave.periodLeaveAvailable;
    final showPeriodLeaveRow =
        showPeriodLeave && periodLeave.periodLeaveRemaining > 0;
    final periodLeaveSelected = showPeriodLeaveRow && _isPeriodLeaveChecked;

    // ── Sheet warnings + CTA overrides (from availability API) ──
    final sheetNudges = filterSheetWarnings(
      widget.sheetWarnings,
      LifecycleActionType.emergencyLogout,
    );
    final ctaMap = ctaOverridesForSheet(sheetNudges);
    final logoutCta = ctaMap[CtaId.logout];
    final goBackCta = ctaMap[CtaId.goBack];
    final logoutRedCards = logoutCta?.redCards;
    final showRedCardIllustration =
        logoutRedCards != null && logoutRedCards > 0;

    if (_loading) {
      return SizedBox(
        height: 0.2.sh,
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 24.h),

        // Red cards (only when BE sends redCards on logout CTA) + Full Shift card
        // (Figma 7455:41103). Red card stack is hidden when period leave is selected
        // (not dimmed). Full Shift stays visible.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showRedCardIllustration && !periodLeaveSelected) ...[
              RedCardIllustration(
                count: logoutRedCards.clamp(1, 9),
              ),
              SizedBox(width: 10.w),
            ],
            _FullShiftCardTile(),
          ],
        ),

        if (showRedCardIllustration) SizedBox(height: 16.h),

        // Title — when earning_loss is present, show earning loss prominently
        if (hasEarningLoss)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: lang.getMessage(
                    'you_will_miss_earnings_of',
                    'You will miss earnings of ',
                  ),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: _gray900,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w400,
                    height: 32 / 24,
                  ),
                ),
                TextSpan(
                  text: '₹${earningLoss.toInt()}',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: _gray900,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    height: 32 / 24,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          )
        else
          Text(
            lang.getMessage(
              'are_you_sure_logout',
              'Are you sure you want to logout?',
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

        SizedBox(height: 24.h),

        // Period leave checkbox
        if (showPeriodLeaveRow) ...[
          _PeriodLeaveRow(
            isChecked: _isPeriodLeaveChecked,
            availableCount: periodLeave.periodLeaveRemaining,
            lang: lang,
            onChanged: (val) {
              setState(() {
                _isPeriodLeaveChecked = val;
              });
              _trackPeriodLeaveSelection(val);
            },
          ),
          SizedBox(height: 24.h),
        ],

        // CTA buttons row
        Row(
          children: [
            // Go back — outlined secondary
            Expanded(
              child: SizedBox(
                height: 48.h,
                child: OutlinedButton(
                  onPressed: () {
                    _trackCtaClick('go_back');
                    Navigator.of(context).pop(false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _gray300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: _ctaButtonChild(
                    context,
                    cta: periodLeaveSelected ? null : goBackCta,
                    lang: lang,
                    fallbackKey: 'go_back',
                    fallbackEnglish: 'Go back',
                    foregroundColor: _gray800,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // Logout — red primary with CTA badge
            Expanded(
              child: SizedBox(
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _onLogoutPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                  ),
                  child: _ctaButtonChild(
                    context,
                    cta: periodLeaveSelected ? null : logoutCta,
                    lang: lang,
                    fallbackKey: 'logout',
                    fallbackEnglish: 'Logout',
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Error message
        if (_error != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Text(
              _error!,
              style: TextStyle(
                color: _red600,
                fontSize: 14.sp,
              ),
            ),
          ),

        SizedBox(height: 20.h),
      ],
    );
  }

  /// CTA button child with optional badge chip.
  Widget _ctaButtonChild(
    BuildContext context, {
    required CtaOverride? cta,
    required LanguageProvider lang,
    required String fallbackKey,
    required String fallbackEnglish,
    Color? foregroundColor,
  }) {
    final label = attendanceButtonLabelFromCta(
      cta,
      lang,
      fallbackKey,
      fallbackEnglish,
    );
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        );
    final showBadge = cta != null && (cta.hasCoinBadge || cta.hasRedCardBadge);
    if (!showBadge) {
      return Text(label, style: style);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 8.w),
        CtaBadgeChip(cta: cta),
      ],
    );
  }

  Future<void> _onLogoutPressed() async {
    _trackCtaClick('logout');
    setState(() {
      _loading = true;
      _error = null;
    });

    final periodLeaveSelected = _effectivePeriodLeaveSelected();

    final Response? response =
        await JobHttp.emergencyLogout(periodLeave: periodLeaveSelected);

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (response != null && response.statusCode == 200) {
      // Capture provider and response data before pop disposes this State.
      final runnerRt = context.read<RunnerRtDataProvider>();
      final responseData = response.data;
      final usedPeriodLeave = periodLeaveSelected;
      Navigator.of(context).pop(true);

      // Wait for the pop animation to complete so the Navigator is unlocked
      // before pushing any new routes (overlay / bottom sheet).
      await Future.delayed(const Duration(milliseconds: 300));

      // Check for post-action outcome in the response.
      final outcome = PostActionOverlayController.parseFromResponse(
        responseData,
        LifecycleActionType.emergencyLogout,
      );

      if (outcome != null) {
        // Show post-action animation (penalty/waiver).
        await PostActionOverlayController.instance.show(outcome);
      }

      // "Take care" is only for period-leave path (no red card); see [TakeCareSheet] doc.
      if (usedPeriodLeave) {
        final rootCtx = GlobalState().navigatorKey.currentContext;
        if (rootCtx != null && rootCtx.mounted) {
          await TakeCareSheet.show(rootCtx, source: 'emergency_logout');
        }
      }

      await runnerRt.fetchDataNow();
      unawaited(runnerRt.refreshEmergencyLogoutAvailability());
    } else {
      _trackCtaClickError(response?.statusCode, response?.data);
      setState(() {
        _error = 'Something went wrong';
      });
      Future.delayed(const Duration(seconds: 2)).then((_) {
        if (mounted) {
          setState(() {
            _error = null;
          });
        }
      });
    }
  }
}

/// Same footprint as [SingleRedCard] so the Full Shift asset aligns with Figma.
class _FullShiftCardTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final w = 69.sp;
    final h = 98.sp;
    return SizedBox(
      width: w,
      height: h,
      child: CachedNetworkImage(
        imageUrl: _kFullShiftCardImageUrl,
        width: w,
        height: h,
        fit: BoxFit.contain,
        placeholder: (_, __) => SizedBox(width: w, height: h),
        errorWidget: (_, __, ___) => SizedBox(width: w, height: h),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period leave row — reuses same pattern from attendance_change_sheet.dart
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
            // Right: checkbox
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

void showEmergencyLogoutConfirmation(
  BuildContext context, {
  int? emergencyLogoutsAvailable,
  required List<SheetWarning> sheetWarnings,
  num? earningLoss,
}) {
  showModalBottomSheet<bool?>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16.r),
      ),
    ),
    builder: (context) => CommonBottomSheetSetup(
      backgroundImageUrl: kNudgesBottomSheetBackgroundUrl,
      child: EmergencyLogoutConfirmation(
        emergencyLogoutsAvailable: emergencyLogoutsAvailable,
        sheetWarnings: sheetWarnings,
        earningLoss: earningLoss,
      ),
    ),
  ).then((value) {
    // Dismissal without successful logout: refresh. Success uses pop(true) and
    // [EmergencyLogoutConfirmation] fetches after overlay / take care.
    if (value == true) return;
    if (!context.mounted) return;
    context.read<RunnerRtDataProvider>().fetchDataNow();
  });
}
