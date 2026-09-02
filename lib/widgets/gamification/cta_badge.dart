import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/gamification/cta_override.dart';
import 'package:snabbit_runner/widgets/gamification/nudge_pill_badge.dart'
    show kNudgePillGoldCoinIconUrl, kNudgePillRedCardIconUrl;

/// Compact inline pill for CTA buttons (e.g. Login, Absent, Logout).
///
/// **Red card** — Figma `7114:113392` (chip on `7114:113388`): `rgba(255,255,255,0.4)` fill, `red-200`
/// border, 16px icon, 4px gap, `px-7.5`, 14 Semibold white count, 20px line height.
///
/// **Gold coin** — Figma `6705:140052`: `rgba(255,255,255,0.2)` fill, no border,
/// 8px / 2px padding, 2px gap, 14px icon, 16 Semibold / 24 line height (no fixed
/// height — total ≈ 28px with padding + line box).
class CtaBadgeChip extends StatelessWidget {
  final CtaOverride cta;

  const CtaBadgeChip({super.key, required this.cta});

  @override
  Widget build(BuildContext context) {
    final hasCoin = cta.hasCoinBadge;
    final hasRed = cta.hasRedCardBadge;
    if (!hasCoin && !hasRed) return const SizedBox.shrink();

    // If BE sends both gold and red on the same CTA, prefer red for penalty flows.
    final isCoin = hasCoin && !hasRed;
    final count = isCoin ? cta.goldCoins! : cta.redCards!;

    return isCoin ? _CoinPill(count: count) : _RedCardPill(count: count);
  }
}

class _RedCardPill extends StatelessWidget {
  const _RedCardPill({required this.count});

  final int count;

  /// Figma `red-200` on translucent pill over red-600 button.
  static const Color _border = Color(0xFFFECACA);

  /// Figma 14/20 line: shared band so icon and digit sit on one center line.
  static double _rowHeight(BuildContext context) => 20.h;

  @override
  Widget build(BuildContext context) {
    final h = _rowHeight(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.5.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(
          color: _border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 16.r,
            height: h,
            child: Center(
              child: SizedBox(
                width: 16.r,
                height: 16.r,
                child: CachedNetworkImage(
                  imageUrl: kNudgePillRedCardIconUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => SizedBox(width: 16.r, height: 16.r),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.credit_card,
                    size: 13.r,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          SizedBox(
            height: h,
            child: Center(
              child: Text(
                '$count',
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                  height: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.count});

  final int count;

  /// Figma 16/24 line: shared band for icon + number.
  static double _rowHeight(BuildContext context) => 24.h;

  @override
  Widget build(BuildContext context) {
    final h = _rowHeight(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 14.r,
            height: h,
            child: Center(
              child: SizedBox(
                width: 14.r,
                height: 14.r,
                child: CachedNetworkImage(
                  imageUrl: kNudgePillGoldCoinIconUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => SizedBox(width: 14.r, height: 14.r),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.monetization_on,
                    size: 12.r,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          SizedBox(
            height: h,
            child: Center(
              child: Text(
                '$count',
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                  height: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
