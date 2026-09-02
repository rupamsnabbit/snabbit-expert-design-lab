import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../models/awol/awol_models.dart';
import '../../models/common/countdown_model.dart';
import '../../providers/language_provider.dart';
import '../../services/remote_config/remote_config_assets.dart';
import '../../utils/awol_strings.dart';
import '../../utils/colors.dart';
import '../../models/gamification/nudge_pill.dart';
import '../../models/gamification/pre_action_nudge.dart';
import '../gamification/nudge_pill_badge.dart';
import 'awol_view_helper.dart';
import '../attendance_flow/custom_timer.dart';
import '../common/countdown_timer_widget.dart';
import 'nudge_theme.dart';
import '../gamification/nudge_banner.dart' show NudgeStripTile;

/// Breach state widget — shown when expert is outside the hotspot.
///
/// [isDialog] = true: modal card (20dp radius), 2 CTAs.
/// [isDialog] = false: home card (8dp radius), only "Show Directions" CTA.
class AwolBreachWidget extends StatefulWidget {
  final AwolData data;
  final LanguageProvider languageProvider;
  final bool isDialog;
  final VoidCallback? onShowDirections;
  final VoidCallback? onUnderstood;
  final PreActionNudge? awolBreachNudge;

  const AwolBreachWidget({
    super.key,
    required this.data,
    required this.languageProvider,
    this.isDialog = true,
    this.onShowDirections,
    this.onUnderstood,
    this.awolBreachNudge,
  });

  @override
  State<AwolBreachWidget> createState() => _AwolBreachWidgetState();
}

class _AwolBreachWidgetState extends State<AwolBreachWidget> {
  LanguageProvider get _lp => widget.languageProvider;
  AwolViewHelper get _helper => AwolViewHelper(data: widget.data, lp: _lp);

  @override
  Widget build(BuildContext context) {
    final radius = widget.isDialog ? 20.r : 8.r;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.awolBreachGradientStart, AppColors.n0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapSection(radius),
          _buildStatusPill(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 15.h),
                Text(
                  _helper.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 18.sp,
                    color: AppColors.r60,
                    height: 24 / 18,
                  ),
                ),
                SizedBox(height: 20.h),
                if (widget.data.isJob && widget.data.detectedAt != null)
                  _buildJobTimer()
                else
                  if (widget.data.countdown?.triggerAt != null)
                    CountdownTimerWidget(
                      totalSeconds: widget.data.countdown!.totalSeconds ?? CountdownData.defaultTotalSeconds,
                      triggerAt: widget.data.countdown!.triggerAt!,
                      size: 160.r,
                    ),
                SizedBox(height: 20.h),
                Text(
                  _helper.warning,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14.sp,
                    color: AppColors.r60,
                    height: 18 / 14,
                  ),
                ),
              ],
            ),
          ),
          if ((widget.awolBreachNudge?.redCards ?? 0) > 0) ...[
            SizedBox(height: 12.h),
            _buildRedCardNudge(),
          ],
          SizedBox(height: 20.h),
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildJobTimer() {
    final detectedAtUtc = widget.data.detectedAt!.toUtc();
    final totalSeconds = widget.data.countdown?.totalSeconds ?? CountdownData.defaultTotalSeconds;

    return CircularTimerWidget(
      persistDuration: false,
      showLateBlinking: true,
      width: 124,
      height: 124,
      sharedPrefsKeyPrefix: 'awol_job_${widget.data.eventId ?? 'unknown'}',
      utcTimeString: DateFormat('HH:mm:ss').format(
        detectedAtUtc.add(Duration(seconds: totalSeconds)),
      ),
      backgroundColor: AppColors.y30,
      lateBackgroundColor: AppColors.r20,
      labelTextColor: AppColors.y45,
      lateTextColor: AppColors.r50,
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 47.h,
            child: ElevatedButton(
              onPressed: widget.onShowDirections,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.n90,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.navigation, size: 14.r, color: AppColors.n0),
                  SizedBox(width: 8.w),
                  Text(
                    _lp.getMessage(
                        AwolStrings.showDirectionsKey, AwolStrings.showDirectionsDefault),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.n0,
                      height: 18 / 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isDialog) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 47.h,
              child: OutlinedButton(
                onPressed: widget.onUnderstood,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.n90),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  _lp.getMessage(AwolStrings.understoodKey, AwolStrings.understoodDefault),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 18 / 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapSection(double radius) {
    return SizedBox(
      height: 203.h,
      width: double.infinity,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(radius)),
            child: Image.network(
              widget.data.imageUrl ?? RemoteConfigAssets.awolEnterHotspot,
              width: double.infinity,
              height: 203.h,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: double.infinity,
                height: 203.h,
                color:
                    AppColors.awolBreachGradientStart.withValues(alpha: 0.5),
                child: Center(
                  child: Icon(Icons.map_outlined,
                      size: 80.r, color: AppColors.r20),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 42.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.awolBreachGradientStart.withValues(alpha: 0),
                    AppColors.awolBreachGradientStart,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    final receivedCount = widget.data.redCardsTotal ?? 0;
    return Padding(
      padding: EdgeInsets.only(top: 14.h),
      child: receivedCount > 0
          ? NudgePillBadge(
              pill: NudgePillDisplay.redCard(receivedCount),
              label: AwolStrings.redCardReceivedLabel(_lp, receivedCount),
            )
          : Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.n0,
                borderRadius: BorderRadius.circular(40.r),
              ),
              child: Text(
                _helper.badge,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.r50,
                  letterSpacing: 0.5,
                  height: 16 / 12,
                ),
              ),
            ),
    );
  }

  // Bottom nudge strip: [notification icon] "Outside Hotspot" → [red card icon + count badge].
  // Mirrors RedCardPenaltyNudge (non-compact) in the native overlay.
  Widget _buildRedCardNudge() {
    final nudge = widget.awolBreachNudge!;
    final colors = NudgeTheme.forNudge(nudge);
    final displayCount = nudge.redCards!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: NudgeStripTile(
        isLastStrip: false,
        decoration: BoxDecoration(
          color: colors.bg,
          border: Border.all(color: colors.border, width: 2),
          borderRadius: BorderRadius.circular(12.r),
        ),
        leading: Icon(Icons.notifications_off, size: 20.r, color: colors.text),
        label: Text(
          _lp.getMessage(AwolStrings.breachOutsideHotspotKey, AwolStrings.breachOutsideHotspotDefault),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
            color: colors.text,
            height: 18 / 13,
          ),
        ),
        trailing: NudgePillBadge(pill: NudgePillDisplay.redCard(displayCount)),
      ),
    );
  }
}
