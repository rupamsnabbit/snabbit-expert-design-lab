import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/assets_constants.dart';
import '../../models/common/countdown_model.dart';
import '../../models/delayed_checkin/delayed_checkin_models.dart';
import '../../models/gamification/nudge_pill.dart';
import '../../models/gamification/pre_action_nudge.dart';
import '../../providers/language_provider.dart';
import '../../utils/colors.dart';
import '../common/countdown_timer_widget.dart';
import '../awol/nudge_theme.dart';
import '../gamification/nudge_banner.dart' show NudgeStripTile;
import '../gamification/nudge_pill_badge.dart';

class DelayedCheckinPenaltyWidget extends StatelessWidget {
  final DelayedCheckinData data;
  final LanguageProvider languageProvider;
  final PreActionNudge? penaltyNudge;

  const DelayedCheckinPenaltyWidget({
    super.key,
    required this.data,
    required this.languageProvider,
    this.penaltyNudge,
  });

  @override
  Widget build(BuildContext context) {
    final redCardCount = data.receivedRedCards ?? 0;
    final totalSeconds =
        data.countdown?.totalSeconds ?? CountdownData.defaultTotalSeconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.countdown?.triggerAt != null) ...[
          SizedBox(height: 16.h),
          NudgePillBadge(
            pill: NudgePillDisplay.redCard(redCardCount),
            label: languageProvider.getMessage(
              redCardCount == 1 ? 'red_card_received' : 'red_cards_received',
              redCardCount == 1 ? 'RED CARD RECEIVED' : 'RED CARDS RECEIVED',
            ),
          ),
          SizedBox(height: 12.h),
          Center(
            child: CountdownTimerWidget(
              totalSeconds: totalSeconds,
              triggerAt: data.countdown!.triggerAt!,
              size: 220.r,
              strokeWidth: 28.0,
              label: languageProvider.getMessage('reach_by', 'REACH BY'),
              allowNegative: false,
              invertProgress: true,
              progressGradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.dcTimerArcStart, AppColors.dcTimerArcEnd],
              ),
            ),
          ),
          SizedBox(height: 20.h),
        ],
        if (penaltyNudge != null) _buildNudgeStrip(context),
      ],
    );
  }

  Widget _buildNudgeStrip(BuildContext context) {
    final nudge = penaltyNudge!;
    final colors = NudgeTheme.forNudge(nudge);
    final nudgeLabel = languageProvider.getFormattedMessage(
      nudge.label.key,
      nudge.label.defaultText ?? '',
      nudge.label.params,
    );
    return NudgeStripTile(
      isLastStrip: false,
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border.all(color: colors.border, width: 2),
        borderRadius: BorderRadius.circular(12.r),
      ),
      leading: const _NudgeIcon(),
      label: Text(
        nudgeLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
              color: colors.text,
              height: 18 / 13,
            ),
      ),
      trailing: nudge.redCards != null
          ? NudgePillBadge(pill: NudgePillDisplay.redCard(nudge.redCards!))
          : null,
    );
  }
}

class _NudgeIcon extends StatelessWidget {
  const _NudgeIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36.r,
      height: 36.r,
      child: Image.asset(AssetConstants.redCardAlert, fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.error, color: Colors.red);
      }),
    );
  }
}
