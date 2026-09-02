import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// A subtle tilted "shine" strip that sweeps left → right across [child] and
/// repeats forever. Purely decorative and non-interactive — the strip is
/// clipped to [borderRadius] so it never escapes the child's rounded bounds,
/// and wrapped in [IgnorePointer] so taps still reach the child.
///
/// Self-contained: owns its [AnimationController] and disposes it. Set
/// [enabled] to false to render the (clipped) child without animating.
class SweepingShine extends StatefulWidget {
  const SweepingShine({
    super.key,
    required this.child,
    required this.borderRadius,
    this.color,
    this.duration = const Duration(milliseconds: 2800),
    this.pauseFraction = 0.45,
    this.stripWidthFactor = 0.38,
    this.skew = -0.35,
    this.enabled = true,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Strip colour. Defaults to a low-opacity white over the dark button.
  final Color? color;

  /// One full sweep-and-rest cycle.
  final Duration duration;

  /// Fraction of the cycle (0–1) the strip rests off-screen before sweeping
  /// again, so it pulses rather than moving constantly.
  final double pauseFraction;

  /// Strip width as a fraction of the child's width.
  final double stripWidthFactor;

  /// Horizontal skew (radians) applied to the strip for the tilt.
  final double skew;

  final bool enabled;

  @override
  State<SweepingShine> createState() => _SweepingShineState();
}

class _SweepingShineState extends State<SweepingShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SweepingShine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return ClipRRect(borderRadius: widget.borderRadius, child: widget.child);
    }
    final stripColor = widget.color ?? AppColors.n0.withAlpha(64);
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            // Isolate the per-frame repaint so it never invalidates the
            // button (or the map/timers behind it).
            child: RepaintBoundary(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final stripWidth = width * widget.stripWidthFactor;
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        // Sweep over the active portion of the cycle, then hold
                        // off-screen for the remaining (pause) portion.
                        final progress =
                            (_controller.value / (1 - widget.pauseFraction))
                                .clamp(0.0, 1.0);
                        // Travel from fully off the left to fully off the right.
                        final dx =
                            -stripWidth + progress * (width + stripWidth);
                        // Align gives the strip loose constraints so its width
                        // is honoured — Positioned.fill alone would force it to
                        // the full button width.
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(dx, 0),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.skewX(widget.skew),
                              child: Container(
                                width: stripWidth,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      stripColor.withAlpha(0),
                                      stripColor,
                                      stripColor.withAlpha(0),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
