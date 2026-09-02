import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';

/// GlobalKeys for flight-animation target measurement.
class HomeRewardsHeaderPillKeys {
  static final coinSegmentKey = GlobalKey(debugLabel: 'coinSegment');
  static final redCardSegmentKey = GlobalKey(debugLabel: 'redCardSegment');

  /// Keys on the icon images — used as the precise flight landing target.
  static final coinIconKey = GlobalKey(debugLabel: 'coinIcon');
  static final redCardIconKey = GlobalKey(debugLabel: 'redCardIcon');
}

/// Dual-segment header pill (coins + red cards) — Figma 5510:12881.
/// Two segments with individual white borders, left-rounded / right-rounded.
/// Segments overlap by 1px so shared borders merge cleanly.
class HomeRewardsHeaderPill extends StatelessWidget {
  const HomeRewardsHeaderPill({
    super.key,
    this.coinsCount = 30,
    this.ticketsCount = 30,
    this.coinIconUrl =
        'https://assets-expert.snabbit.com/payouts/nudges/gold_coin.png',
    this.redCardIconUrl =
        'https://assets-expert.snabbit.com/payouts/nudges/red_card.png',
  });

  final int coinsCount;
  final int ticketsCount;
  final String coinIconUrl;
  final String redCardIconUrl;

  // Figma: yellow/red-100 backgrounds, yellow/red-700 text
  static const Color _yellowBg = Color(0xFFFEF3C7);
  static const Color _yellowText = Color(0xFFB45309);
  static const Color _redBg = Color(0xFFFEE2E2);
  static const Color _redText = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.displayMedium?.copyWith(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          height: 15 / 14,
          letterSpacing: -0.24,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Segment(
          debugLabel: 'coins',
          containerKey: HomeRewardsHeaderPillKeys.coinSegmentKey,
          iconKey: HomeRewardsHeaderPillKeys.coinIconKey,
          background: _yellowBg,
          imageUrl: coinIconUrl,
          fallbackIcon: Icons.monetization_on_rounded,
          fallbackColor: const Color(0xFFD97706),
          count: coinsCount,
          textStyle: baseStyle?.copyWith(color: _yellowText),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            bottomLeft: Radius.circular(24.r),
          ),
          route: WebviewRoutes.payoutsRewardsGoldCoins,
          title: 'Gold coins',
        ),
        // Overlap 1px so shared white borders merge cleanly (Figma mr-[-1px]).
        Transform.translate(
          offset: const Offset(-1, 0),
          child: _Segment(
            debugLabel: 'redCard',
            containerKey: HomeRewardsHeaderPillKeys.redCardSegmentKey,
            iconKey: HomeRewardsHeaderPillKeys.redCardIconKey,
            background: _redBg,
            imageUrl: redCardIconUrl,
            fallbackIcon: Icons.confirmation_number_rounded,
            fallbackColor: _redText,
            count: ticketsCount,
            textStyle: baseStyle?.copyWith(color: _redText),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(24.r),
              bottomRight: Radius.circular(24.r),
            ),
            route: WebviewRoutes.payoutsRewardsRedCards,
            title: 'Red cards',
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.debugLabel,
    this.containerKey,
    this.iconKey,
    required this.background,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.fallbackColor,
    required this.count,
    required this.textStyle,
    required this.borderRadius,
    required this.route,
    required this.title,
  });

  final String debugLabel;
  final Key? containerKey;
  final Key? iconKey;
  final Color background;
  final String imageUrl;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final int count;
  final TextStyle? textStyle;
  final BorderRadius borderRadius;

  /// Path from [WebviewRoutes] to open on tap.
  final String route;

  /// Title shown in the webview app bar.
  final String title;

  @override
  Widget build(BuildContext context) {
    final size = 16.sp;
    // Figma: px-8 py-5, min-w-54, border 1px white, per-segment radius.
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        AppWebViewPage.routeName,
        arguments: WebViewArgs(
          url: buildWebviewUrl(route),
          title: title,
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: containerKey,
        constraints: BoxConstraints(minWidth: 52.w),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: background,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.n0, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              key: iconKey,
              width: size,
              height: size,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => SizedBox(width: size, height: size),
                errorWidget: (_, __, ___) => Icon(
                  fallbackIcon,
                  size: size,
                  color: fallbackColor,
                ),
              ),
            ),
            SizedBox(width: 2.w),
            _RollingCount(value: count, style: textStyle),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-digit rolling animation — only digits that changed scroll.
// ─────────────────────────────────────────────────────────────────────────────

/// Splits [value] into individual digits and only animates the ones that
/// actually changed (e.g. 61→64: the "6" stays static, only "1→4" rolls).
class _RollingCount extends StatefulWidget {
  const _RollingCount({required this.value, required this.style});

  final int value;
  final TextStyle? style;

  @override
  State<_RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<_RollingCount> {
  int _prevValue = 0;

  @override
  void initState() {
    super.initState();
    _prevValue = widget.value;
  }

  @override
  void didUpdateWidget(_RollingCount old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _prevValue = old.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final newStr = '${widget.value}';
    final oldStr = '$_prevValue';

    // Right-align digits so ones/tens/etc. columns match up.
    final maxLen =
        newStr.length > oldStr.length ? newStr.length : oldStr.length;
    final newPadded = newStr.padLeft(maxLen);

    final goingUp = widget.value > _prevValue;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLen, (i) {
        return _RollingDigit(
          digit: newPadded[i],
          goingUp: goingUp,
          style: widget.style,
        );
      }),
    );

    // Settle so subsequent rebuilds with the same value don't stay in the
    // "transition" state and keep showing _RollingDigit slots based on stale
    // prev. _RollingDigit's own AnimatedSwitcher owns the actual animation.
    _prevValue = widget.value;
    return row;
  }
}

/// A single character slot that scrolls vertically when [digit] changes.
class _RollingDigit extends StatelessWidget {
  const _RollingDigit({
    required this.digit,
    required this.goingUp,
    required this.style,
  });

  final String digit;
  final bool goingUp;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final fontSize = style?.fontSize ?? 14.sp;
    final clipHeight = fontSize * 1.3;

    return SizedBox(
      height: clipHeight,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final isIncoming = child.key == ValueKey<String>(digit);
            final beginOffset = isIncoming
                ? Offset(0, goingUp ? 1.0 : -1.0)
                : Offset(0, goingUp ? -1.0 : 1.0);

            return SlideTransition(
              position: Tween(begin: beginOffset, end: Offset.zero)
                  .animate(animation),
              child: child,
            );
          },
          child: Text(
            digit,
            key: ValueKey<String>(digit),
            style: style,
          ),
        ),
      ),
    );
  }
}
