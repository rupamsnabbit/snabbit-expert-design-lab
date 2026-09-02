import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/tiering/tier_coins_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';

/// A centred row of up to four "Week N" flags — one per week in the coins body
/// ([coins]) supplied by the parent [TierNudgeProgressCard]. Each flag is the
/// [AssetConstants.weekCoinFlag] pennant tinted with the runner's [tier] colour,
/// with "Week N" centred in white. The current week (`current_week`) is full
/// opacity; preceding weeks are dimmed to 30%. When the current week is unknown
/// the whole row stays at full opacity rather than looking disabled.
///
/// Data is passed down from the card (which already parsed it) — this widget
/// does not re-read providers or re-parse the payload.
class TierNudgeWeekFlags extends StatelessWidget {
  const TierNudgeWeekFlags({
    super.key,
    required this.coins,
    required this.tier,
  });

  /// Weekly coins progress (weeks + `current_week`), from the parent card's data.
  final TierCoinsProgress? coins;

  /// Runner tier — drives the pennant colour.
  final Tier? tier;

  static const int _maxFlags = 4;
  static const double _flagWidth = 68;
  static const double _flagHeight = 20;

  @override
  Widget build(BuildContext context) {
    final weeks = coins?.weeks ?? const <TierWeek>[];
    if (weeks.isEmpty) return const SizedBox.shrink();

    final currentWeek = coins?.currentWeek;
    final color = _flagColor(tier);
    final visible = _windowed(weeks, currentWeek);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final week in visible)
          _WeekFlag(
            week: week.week,
            color: color,
            // Highlight the current week. When `current_week` is unknown, keep
            // the whole row at full opacity instead of dimming every flag to 30%.
            isCurrent: currentWeek == null || week.week == currentWeek,
          ),
      ],
    );
  }

  /// At most [_maxFlags] flags. When there are more weeks than that, window so
  /// the current week stays visible (the [_maxFlags] weeks ending at it); if the
  /// current week isn't found, fall back to the first [_maxFlags] in order.
  List<TierWeek> _windowed(List<TierWeek> weeks, int? currentWeek) {
    if (weeks.length <= _maxFlags) return weeks;
    final idx = currentWeek == null
        ? -1
        : weeks.indexWhere((w) => w.week == currentWeek);
    if (idx < 0) return weeks.take(_maxFlags).toList();
    final end = idx + 1 < _maxFlags ? _maxFlags : idx + 1;
    return weeks.sublist(end - _maxFlags, end);
  }
}

/// Per-tier flag background colour; legacy/unknown tiers fall back to base.
Color _flagColor(Tier? tier) {
  switch (tier) {
    case Tier.BASE:
      return AppColors.tierWeekFlagBase;
    case Tier.SILVER:
      return AppColors.tierWeekFlagSilver;
    case Tier.GOLD:
      return AppColors.tierWeekFlagGold;
    case Tier.DIAMOND:
      return AppColors.tierWeekFlagDiamond;
    case Tier.PINK_DIAMOND:
      return AppColors.tierWeekFlagPinkDiamond;
    case Tier.BASIC:
    case Tier.PRO:
    case Tier.ELITE:
    case null:
      return AppColors.tierWeekFlagBase;
  }
}

/// A single pennant: the tinted flag SVG with "Week N" centred, dimmed to 30%
/// unless it is the current week.
class _WeekFlag extends StatelessWidget {
  const _WeekFlag({
    required this.week,
    required this.color,
    required this.isCurrent,
  });

  final int? week;
  final Color color;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isCurrent ? 1.0 : 0.3,
      child: SizedBox(
        width: TierNudgeWeekFlags._flagWidth.w,
        height: TierNudgeWeekFlags._flagHeight.h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: SvgPicture.asset(
                AssetConstants.weekCoinFlag,
                fit: BoxFit.fill,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
            Text(
              'Week ${week ?? ''}'.trim(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.n0,
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
