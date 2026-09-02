import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/widgets/gamification/nudge_pill_badge.dart'
    show kNudgePillGoldCoinIconUrl;

/// Full-screen overlay that animates coins from [sources] to [target].
///
/// Uses a **single** [AnimationController] with staggered [Interval] curves
/// instead of one controller per coin — reduces ticker overhead and avoids
/// jank from scheduling many independent animations.
class CoinFlightOverlay extends StatefulWidget {
  const CoinFlightOverlay({
    super.key,
    required this.sources,
    required this.target,
    required this.onComplete,
    this.startSize = 100,
    this.iconUrl = kNudgePillGoldCoinIconUrl,
  });

  /// Global center offsets of each coin image in the popup.
  final List<Offset> sources;

  /// Global center offset of the header pill segment.
  final Offset target;

  /// Called when all coins have landed.
  final VoidCallback onComplete;

  /// Initial coin display size (matches popup coin size).
  final double startSize;

  /// CDN icon URL for the flying asset (coin or red card).
  final String iconUrl;

  @override
  State<CoinFlightOverlay> createState() => _CoinFlightOverlayState();
}

class _CoinFlightOverlayState extends State<CoinFlightOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<Offset>> _positionAnims;
  late final List<Animation<double>> _sizeAnims;

  static const double _endSize = 18;

  @override
  void initState() {
    super.initState();
    final n = widget.sources.length;

    // Scale timing so total duration stays ~600-750ms regardless of count.
    final flightMs = n <= 2
        ? 600
        : n <= 4
            ? 500
            : n <= 6
                ? 400
                : 350;
    final staggerMs = n <= 2
        ? 100
        : n <= 4
            ? 70
            : n <= 6
                ? 50
                : 35;
    final totalMs = flightMs + (n - 1) * staggerMs;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    // Each coin occupies [start .. start+flightFrac] of the 0→1 timeline.
    final flightFrac = flightMs / totalMs;
    final staggerFrac = totalMs > 0 ? staggerMs / totalMs : 0.0;

    _positionAnims = List.generate(n, (i) {
      final start = i * staggerFrac;
      final end = (start + flightFrac).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: widget.sources[i],
        end: widget.target,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeInCubic),
      ));
    });

    _sizeAnims = List.generate(n, (i) {
      final start = i * staggerFrac;
      final end = (start + flightFrac).clamp(0.0, 1.0);
      return Tween<double>(begin: widget.startSize, end: _endSize).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeInCubic),
        ),
      );
    });

    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: List.generate(widget.sources.length, (i) {
              final pos = _positionAnims[i].value;
              final sz = _sizeAnims[i].value;
              return Positioned(
                left: pos.dx - sz / 2,
                top: pos.dy - sz / 2,
                width: sz,
                height: sz,
                child: RepaintBoundary(
                  child: CachedNetworkImage(
                    imageUrl: widget.iconUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.monetization_on_rounded,
                      size: sz,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
