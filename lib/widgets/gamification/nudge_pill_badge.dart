import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/gamification/nudge_pill.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// CDN URLs for the standard nudge pill icons.
const String kNudgePillGoldCoinIconUrl =
    'https://assets-expert.snabbit.com/payouts/nudges/gold_coin.png';
const String kNudgePillRedCardIconUrl =
    'https://assets-expert.snabbit.com/payouts/nudges/red_card_straight.png';

/// Rounded icon + count badge for nudge strips and AWOL status pills.
///
/// Derives background, border, and foreground colors from [pill.kind].
/// Pass [label] to append a text suffix after the count (e.g. "RED CARD RECEIVED").
///
/// Figma refs — coin: 5510:15609, red card: 5510:28120.
class NudgePillBadge extends StatelessWidget {
  final NudgePillDisplay pill;

  /// Optional text appended after the count (e.g. "RED CARD RECEIVED").
  /// When null only the count is shown.
  final String? label;

  const NudgePillBadge({super.key, required this.pill, this.label});

  // Gold coin — yellow-50, yellow-200 hairline.
  static const Color _coinFill = AppColors.nudgeOpportunityBg;
  static const Color _coinBorder = AppColors.nudgeOpportunityBorder;
  static const Color _coinFg = AppColors.nudgeOpportunityText;

  // Red card — red-50, red-300 1px.
  static const Color _redCardFill = AppColors.nudgeRiskBg;
  static const Color _redCardBorder = AppColors.nudgeRiskBorder;
  static const Color _redCardFg = AppColors.nudgeRiskText;

  @override
  Widget build(BuildContext context) {
    final isCoin = pill.kind == NudgePillKind.coin;
    final fill = isCoin ? _coinFill : _redCardFill;
    final borderColor = isCoin ? _coinBorder : _redCardBorder;
    final fg = isCoin ? _coinFg : _redCardFg;
    final iconUrl = isCoin ? kNudgePillGoldCoinIconUrl : kNudgePillRedCardIconUrl;
    final iconSize = 14.w;

    final countText = label != null ? '${pill.count} $label' : '${pill.count}';

    return Container(
      padding: isCoin
          ? EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h)
          : EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: borderColor, width: isCoin ? 1.333 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CachedNetworkImage(
              imageUrl: iconUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => SizedBox(
                width: iconSize,
                height: iconSize,
                child: Center(
                  child: SizedBox(
                    width: 10.w,
                    height: 10.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: fg.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Icon(
                isCoin ? Icons.monetization_on : Icons.credit_card,
                size: iconSize,
                color: fg,
              ),
            ),
          ),
          SizedBox(width: isCoin ? 5.33.w : 4.w),
          Text(
            countText,
            style: isCoin
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 20.sp,
                      height: 28 / 20,
                    )
                : Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.sp,
                      letterSpacing: 0.5,
                      height: 16 / 12,
                    ),
          ),
        ],
      ),
    );
  }
}
