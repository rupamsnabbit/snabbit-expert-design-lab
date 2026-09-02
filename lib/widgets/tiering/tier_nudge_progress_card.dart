import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/tiering/tier_coins_data.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/tiering/tier_nudge_week_flags.dart';

/// Tier-coins weekly progress card — a coloured header naming the [tier] and a
/// body that plots the active week's coin earnings against its milestone
/// [TierTarget]s.
///
/// The current value is the active week's `earned` (the week whose number
/// matches `current_week`); each target is a milestone plotted on the progress
/// bar at `amount / maxTarget`. Header and milestone badges are the same tier
/// image (from [RemoteConfigAssets]) at different sizes.
///
/// Colours default to the tier's own palette (the [AppColors] `nudgeTier*`
/// set): the header background, progress fill and border use the tier **accent**
/// and the body uses the tier **tint**, so the card reads distinctly per tier.
/// [headerGradient] / [headerColor], [bodyGradient] / [bodyColor] and
/// [progressColor] still let a caller override any surface. Neutral chrome
/// (track, text, coin badge) uses [AppColors] directly.
class TierNudgeProgressCard extends StatelessWidget {
  const TierNudgeProgressCard({
    super.key,
    required this.tier,
    required this.data,
    this.headerGradient,
    this.headerColor,
    this.bodyGradient,
    this.bodyColor,
    this.progressColor,
    this.coinsLabel = 'Snabbit coins',
    this.route,
    this.webViewTitle = '',
    this.onTap,
  });

  /// Tier this card represents — drives the header badge, title and the header
  /// background the caller wires up.
  final Tier tier;

  /// Coins payload; the active week supplies the current value + milestones.
  final TierCoinsData data;

  /// Header background gradient (placeholder — wire the real tier colour later).
  final Gradient? headerGradient;

  /// Header background solid colour, used when [headerGradient] is null.
  final Color? headerColor;

  /// Body background gradient (placeholder).
  final Gradient? bodyGradient;

  /// Body background solid colour, used when [bodyGradient] is null.
  final Color? bodyColor;

  /// Progress-bar fill colour (placeholder).
  final Color? progressColor;

  /// Copy after the coin count, e.g. "Snabbit coins".
  final String coinsLabel;

  /// [WebviewRoutes] path opened in the bifrost webview when the card is tapped.
  /// Null (or empty) renders the card non-tappable.
  final String? route;

  /// Title shown in the webview app bar once opened.
  final String webViewTitle;

  /// Analytics hook fired when the (tappable) card is tapped, before the webview
  /// opens. Null for cards that don't need instrumentation.
  final VoidCallback? onTap;

  bool get _isTappable => route != null && route!.isNotEmpty;

  void _handleTap(BuildContext context) {
    onTap?.call();
    final path = route;
    if (path == null || path.isEmpty) return;
    final url = buildWebviewUrl(path);
    if (!WebViewLauncher.isOpenableHttps(url)) return;
    WebViewLauncher.open(context, url: url, title: webViewTitle);
  }

  TierWeek? get _activeWeek => data.coins?.activeWeek;

  int get _earned => _activeWeek?.earned ?? 0;

  List<TierTarget> get _targets => _activeWeek?.targets ?? const [];

  /// Largest milestone amount — the full scale of the progress bar.
  int get _maxTargetAmount {
    var max = 0;
    for (final target in _targets) {
      final amount = target.amount ?? 0;
      if (amount > max) max = amount;
    }
    return max;
  }

  /// Per-tier accent — the header background, progress fill and border.
  /// Legacy/unknown tiers (PRO/ELITE/BASIC) fall back to the base accent.
  Color get _tierAccent => switch (tier) {
        Tier.BASE => AppColors.nudgeTierBaseAccent,
        Tier.SILVER => AppColors.nudgeTierSilverAccent,
        Tier.GOLD => AppColors.nudgeTierGoldAccent,
        Tier.DIAMOND => AppColors.nudgeTierDiamondAccent,
        Tier.PINK_DIAMOND => AppColors.nudgeTierPinkDiamondAccent,
        Tier.PRO || Tier.ELITE || Tier.BASIC => AppColors.nudgeTierBaseAccent,
      };

  /// Per-tier body tint — the light background under the progress row.
  Color get _tierTint => switch (tier) {
        Tier.BASE => AppColors.nudgeTierBaseTint,
        Tier.SILVER => AppColors.nudgeTierSilverTint,
        Tier.GOLD => AppColors.nudgeTierGoldTint,
        Tier.DIAMOND => AppColors.nudgeTierDiamondTint,
        Tier.PINK_DIAMOND => AppColors.nudgeTierPinkDiamondTint,
        Tier.PRO || Tier.ELITE || Tier.BASIC => AppColors.nudgeTierBaseTint,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isTappable ? () => _handleTap(context) : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: _tierAccent, width: 1.r),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                _buildBody(),
              ],
            ),
          ),
        ),
        TierNudgeWeekFlags(coins: data.coins, tier: tier),
      ],
    );
  }

  Widget _buildHeader() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: headerGradient,
        color: headerGradient == null ? (headerColor ?? _tierAccent) : null,
      ),
      child: Stack(
        children: [
          // Decorative top-right glow (CSS Ellipse 38424/25/26).
          Positioned(top: -46.h, left: 240.w, child: _glow(135)),
          Positioned(top: -37.h, left: 266.w, child: _glow(118)),
          Positioned(top: -29.h, left: 293.w, child: _glow(102)),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 16.w, 12.h),
            child: Row(
              children: [
                _tierBadge(20.r),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    '${tier.normalizedDescription ?? ''} Level'.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.n0,
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

  Widget _buildBody() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
      decoration: BoxDecoration(
        gradient: bodyGradient,
        color: bodyGradient == null ? (bodyColor ?? _tierTint) : null,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.r)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _coinBadge(),
          SizedBox(width: 12.w),
          Expanded(child: _progressColumn()),
        ],
      ),
    );
  }

  Widget _progressColumn() {
    final maxAmount = _maxTargetAmount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$_earned',
              style: TextStyle(
                fontSize: 16.sp,
                height: 24 / 16,
                fontWeight: FontWeight.w600,
                color: AppColors.n80,
              ),
            ),
            SizedBox(width: 4.w),
            Text(
              coinsLabel,
              style: TextStyle(
                fontSize: 14.sp,
                height: 20 / 14,
                fontWeight: FontWeight.w500,
                color: AppColors.n60,
              ),
            ),
            const Spacer(),
            if (maxAmount > 0)
              Text(
                '$maxAmount',
                style: TextStyle(
                  fontSize: 10.sp,
                  height: 14 / 10,
                  fontWeight: FontWeight.w400,
                  color: AppColors.n60,
                ),
              ),
          ],
        ),
        SizedBox(height: 4.h),
        _MilestoneProgressBar(
          earned: _earned,
          maxAmount: maxAmount,
          targets: _targets,
          progressColor: progressColor ?? _tierAccent,
          trackColor: AppColors.n30,
        ),
      ],
    );
  }

  Widget _coinBadge() {
    return Container(
      width: 36.r,
      height: 36.r,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.n20,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 24.r,
        height: 24.r,
        child: RemoteImageHandler(
          imageUrl: RemoteConfigAssets.tierCoin,
          fit: BoxFit.contain,
          animate: false,
          loadingWidget: const SizedBox.shrink(),
          errorWidget: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _tierBadge(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: RemoteImageHandler(
        key: ValueKey(tier.tierBadgeImage),
        imageUrl: tier.tierBadgeImage,
        fit: BoxFit.contain,
        animate: false,
        loadingWidget: const SizedBox.shrink(),
        errorWidget: const SizedBox.shrink(),
      ),
    );
  }

  Widget _glow(double diameter) {
    return Container(
      width: diameter.r,
      height: diameter.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.n0.withValues(alpha: 0.03),
      ),
    );
  }
}

/// The 8px progress track with the fill and the milestone tier badges plotted
/// on top at `amount / maxAmount`.
class _MilestoneProgressBar extends StatelessWidget {
  const _MilestoneProgressBar({
    required this.earned,
    required this.maxAmount,
    required this.targets,
    required this.progressColor,
    required this.trackColor,
  });

  final int earned;
  final int maxAmount;
  final List<TierTarget> targets;
  final Color progressColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final barHeight = 8.h;
    final milestoneSize = 22.r;
    final fraction =
        maxAmount <= 0 ? 0.0 : (earned / maxAmount).clamp(0.0, 1.0);

    return SizedBox(
      height: milestoneSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: width,
                height: barHeight,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              Container(
                width: width * fraction,
                height: barHeight,
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              ..._buildMilestones(width, milestoneSize),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildMilestones(double width, double milestoneSize) {
    final maxLeft = width - milestoneSize;
    return targets.map((target) {
      final tier = target.tier;
      if (tier == null) return const SizedBox.shrink();
      final amount = target.amount ?? 0;
      final fraction =
          maxAmount <= 0 ? 0.0 : (amount / maxAmount).clamp(0.0, 1.0);
      final center = fraction * width;
      final left =
          maxLeft <= 0 ? 0.0 : (center - milestoneSize / 2).clamp(0.0, maxLeft);
      return Positioned(
        left: left,
        child: SizedBox(
          width: milestoneSize,
          height: milestoneSize,
          child: RemoteImageHandler(
            key: ValueKey(tier.tierBadgeImage),
            imageUrl: tier.tierBadgeImage,
            fit: BoxFit.contain,
            animate: false,
            loadingWidget: const SizedBox.shrink(),
            errorWidget: const SizedBox.shrink(),
          ),
        ),
      );
    }).toList();
  }
}

/// Maps a [Tier] to its badge image in [RemoteConfigAssets]. Kept in the
/// presentation layer so the shared `enums.dart` stays free of a service
/// dependency. Tiers without a tiering badge resolve to an empty URL, which
/// [RemoteImageHandler] renders as its (empty) error widget.
extension _TierBadgeImage on Tier {
  String get tierBadgeImage {
    switch (this) {
      case Tier.SILVER:
        return RemoteConfigAssets.silverTier;
      case Tier.GOLD:
        return RemoteConfigAssets.goldTier;
      case Tier.DIAMOND:
        return RemoteConfigAssets.diamondTier;
      case Tier.PINK_DIAMOND:
        return RemoteConfigAssets.pinkDiamondTier;
      case Tier.BASE:
        return RemoteConfigAssets.baseTier;
      case Tier.PRO:
      case Tier.ELITE:
      case Tier.BASIC:
        return '';
    }
  }
}
