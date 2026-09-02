import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/gamification/post_action_outcome.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/gamification/post_action_ellipse_bloom.dart';
import 'package:snabbit_runner/widgets/gamification/post_action_soft_starburst.dart';
import 'package:snabbit_runner/widgets/gamification/resolve_nudge_label.dart';

/// Post-action reward/penalty popup — Figma 5510:15060.
///
/// Full-screen blurred overlay with large coins/cards, radial glow, and parallelogram
/// title bar (Figma `6705:145668` / `7059:30990`). Assets pulse (500 ms per leg) then
/// [onReadyForFlight] fires
/// with measured global center offsets for the flight animation.
class PostActionPopup extends StatefulWidget {
  const PostActionPopup({
    super.key,
    required this.outcome,
    required this.onReadyForFlight,
  });

  final PostActionOutcome outcome;

  /// Called after the idle animation completes, with measured global center
  /// offsets, display size, and icon URL for the flight animation.
  final void Function(
    List<Offset> coinCenters,
    double coinSize,
    String iconUrl,
  ) onReadyForFlight;

  @override
  State<PostActionPopup> createState() => _PostActionPopupState();
}

class _PostActionPopupState extends State<PostActionPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;

  late final bool _isReward;
  late final int _displayCount;
  late final double _assetSize;
  late final String _iconUrl;
  late final List<GlobalKey> _assetKeys;
  final String _redCardUrl =
      'https://assets-expert.snabbit.com/payouts/nudges/red_card_display.png';
  final String _goldCoinUrl =
      'https://assets-expert.snabbit.com/payouts/nudges/gold_coin_straight.png';

  @override
  void initState() {
    super.initState();

    _isReward = widget.outcome.isReward;
    final rawCount =
        _isReward ? widget.outcome.goldCoins : widget.outcome.redCards;
    _displayCount = rawCount.abs().clamp(1, 9);
    _assetSize = _sizeForCount(_displayCount);
    _iconUrl = _isReward ? _goldCoinUrl : _redCardUrl;
    _assetKeys = List.generate(
      _displayCount,
      (i) => GlobalKey(debugLabel: 'popupAsset$i'),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Idle pulse — shorter for higher counts so the full sequence stays snappy.
    final idleMs = _displayCount <= 2
        ? 750
        : _displayCount <= 4
            ? 650
            : 550;
    _pulseCtrl.repeat(reverse: true);

    Future.delayed(Duration(milliseconds: idleMs), () async {
      if (!mounted) return;
      _pulseCtrl.stop();
      // Linear controller motion so [_scaleAnim]'s easeInOut applies only once
      // (easeInOut here would stack on CurvedAnimation and feel like two steps).
      await _pulseCtrl.animateTo(
        0,
        duration: _pulseCtrl.duration,
        curve: Curves.linear,
      );
      if (!mounted) return;
      // Hold the settled state for 1 second so the user can register the outcome.
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      // Defer measure until layout matches the final frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final centers = <Offset>[];
        for (final key in _assetKeys) {
          final box = key.currentContext?.findRenderObject() as RenderBox?;
          if (box != null) {
            final pos = box.localToGlobal(Offset.zero);
            centers.add(pos + Offset(box.size.width / 2, box.size.height / 2));
          }
        }
        widget.onReadyForFlight(centers, _assetSize, _iconUrl);
      });
    });
  }

  /// Asset image size scales down as more items are displayed.
  static double _sizeForCount(int count) {
    if (count <= 1) return 120.sp;
    if (count <= 2) return 100.sp;
    if (count <= 4) return 85.sp;
    if (count <= 6) return 75.sp;
    return 65.sp; // 7-9
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Asset grid layout (max 3 per row, overlap when > 2 in a row) ──

  /// Splits [_displayCount] items into rows of max 3, rendered as a Column.
  Widget _buildAssetGrid(Color fallbackIconColor) {
    final rows = <List<int>>[];
    for (var i = 0; i < _displayCount; i += 3) {
      final end = (i + 3).clamp(0, _displayCount);
      rows.add(List.generate(end - i, (j) => i + j));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: 4.h),
          _buildAssetRow(rows[r], fallbackIconColor),
        ],
      ],
    );
  }

  /// Builds a single row of assets. When the row has > 2 items the coins
  /// overlap horizontally (offset = 70 % of asset size) to stay compact.
  Widget _buildAssetRow(List<int> indices, Color fallbackIconColor) {
    if (indices.length <= 2) {
      // No overlap — simple horizontal layout.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final i in indices)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: _buildAsset(i, fallbackIconColor),
            ),
        ],
      );
    }

    // Overlap layout: each successive coin shifted by 70 % of asset size.
    final step = _assetSize * 0.70;
    final totalWidth = _assetSize + (indices.length - 1) * step;

    return SizedBox(
      width: totalWidth,
      height: _assetSize,
      child: Stack(
        children: [
          for (var j = 0; j < indices.length; j++)
            Positioned(
              left: j * step,
              child: _buildAsset(indices[j], fallbackIconColor),
            ),
        ],
      ),
    );
  }

  Widget _buildAsset(int index, Color fallbackIconColor) {
    return RepaintBoundary(
      child: SizedBox(
        key: _assetKeys[index],
        width: _assetSize,
        height: _assetSize,
        child: CachedNetworkImage(
          imageUrl: _iconUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => SizedBox(
            width: _assetSize,
            height: _assetSize,
          ),
          errorWidget: (_, __, ___) => Icon(
            _isReward
                ? Icons.monetization_on_rounded
                : Icons.confirmation_number_rounded,
            size: _assetSize,
            color: fallbackIconColor,
          ),
        ),
      ),
    );
  }

  // ── Figma colour tokens — reward (yellow/amber) ──
  static const _yellow700 = Color(0xFFB45309);

  // ── Figma colour tokens — penalty (red) ──
  static const _red700 = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    // Colour scheme based on outcome type.
    final titleRibbonColor = _isReward ? _yellow700 : _red700;
    final fallbackIconColor = _isReward ? const Color(0xFFD97706) : _red700;
    final lang = context.watch<LanguageProvider>();
    final titleText = resolveNudgeLabel(widget.outcome.label, lang);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Backdrop: blur 4px + 50% black (Figma 5510:15214) ──
          // RepaintBoundary isolates the expensive BackdropFilter so it
          // is rasterised once and not re-composited on every pulse frame.
          RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),

          // ── Centered content (slightly above center per Figma) ──
          Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600.w),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Figma `6705:144506`: Star 35 → Ellipse 13967 → coins.
                    // Top/bottom outsets shifted so the glow center aligns
                    // with the coins, not the full column (coins + gap + title).
                    PostActionSoftStarburst(
                      isReward: _isReward,
                      horizontalOutset: 88.w,
                      topOutset: 110.h,
                      bottomOutset: 62.h,
                    ),
                    PostActionEllipseBloom(
                      isReward: _isReward,
                      horizontalOutset: 88.w,
                      topOutset: 110.h,
                      bottomOutset: 62.h,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _scaleAnim,
                          child: _buildAssetGrid(fallbackIconColor),
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnim.value,
                              child: child,
                            );
                          },
                        ),
                        SizedBox(height: 24.h),
                        _PostActionTitleBar(
                          ribbonColor: titleRibbonColor,
                          label: titleText.toUpperCase(),
                          iconUrl: widget.outcome.iconUrl,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parallelogram title bar — Figma penalty `6705:145668`, reward `7059:30990`
// (25px tall bar, 16px dot, 7px gap, Metropolis Bold 14 / tracking 1, yellow-50)
// ─────────────────────────────────────────────────────────────────────────────

class _ParallelogramRibbonClipper extends CustomClipper<Path> {
  const _ParallelogramRibbonClipper({required this.skew});

  final double skew;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(skew, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - skew, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _ParallelogramRibbonClipper old) =>
      old.skew != skew;
}

/// Figma 16px leading slot: network image from [url], or solid cream dot if unset.
class _TitleBarLeadingIcon extends StatelessWidget {
  const _TitleBarLeadingIcon({this.url});

  final String? url;

  static const _dotColor = Color(0xFFFFFBEB);

  @override
  Widget build(BuildContext context) {
    final s = 16.r;
    final u = url?.trim();
    if (u == null || u.isEmpty) {
      return Container(
        width: s,
        height: s,
        decoration: const BoxDecoration(
          color: _dotColor,
          shape: BoxShape.circle,
        ),
      );
    }
    return SizedBox(
      width: s,
      height: s,
      child: CachedNetworkImage(
        imageUrl: u,
        fit: BoxFit.contain,
        placeholder: (_, __) => SizedBox(width: s, height: s),
        errorWidget: (_, __, ___) => Container(
          width: s,
          height: s,
          decoration: const BoxDecoration(
            color: _dotColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _PostActionTitleBar extends StatelessWidget {
  const _PostActionTitleBar({
    required this.ribbonColor,
    required this.label,
    this.iconUrl,
  });

  final Color ribbonColor;
  final String label;
  final String? iconUrl;

  static const double _barHeightPx = 25;
  static const double _skewFraction = 0.2;

  static const _labelColor = Color(0xFFFFFBEB);

  @override
  Widget build(BuildContext context) {
    final h = _barHeightPx.h;
    final skew = h * _skewFraction;

    return IntrinsicWidth(
      child: ClipPath(
        clipper: _ParallelogramRibbonClipper(skew: skew),
        child: Container(
          height: h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          color: ribbonColor,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TitleBarLeadingIcon(url: iconUrl),
              SizedBox(width: 7.w),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  color: _labelColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
