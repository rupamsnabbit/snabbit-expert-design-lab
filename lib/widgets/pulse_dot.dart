import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A dot with an optional outer ring. Used in Shield card status, activation
/// badge, and info bottom sheet badges.
///
/// When [animated] is true, the outer ring pulses (scale + fade). When false,
/// the ring is static. Use [ringColor] to match a specific design (e.g. light
/// red ring for Snabbit Shield Limited badge).
class PulseDot extends StatefulWidget {
  const PulseDot({
    super.key,
    this.color,
    this.ringColor,
    this.size,
    this.innerSize,
    this.animated = true,
  });

  /// Inner dot color. Defaults to brand blue (#326FE3) when null.
  final Color? color;

  /// Outer ring color. When null and [animated] is false, uses [color] with
  /// reduced opacity. When [animated] is true, the ring fades using [color].
  final Color? ringColor;

  /// Overall (outer) size. Defaults to 18.r.
  final double? size;

  /// Inner dot size. When null, derived from [size] (10/18 ratio).
  final double? innerSize;

  /// Whether the outer ring pulses. Defaults to true.
  ///
  /// Treated as immutable configuration — it must not change for the same
  /// widget instance. If you need to toggle animation, rebuild with a new key.
  final bool animated;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  static const _defaultColor = Color(0xFF326FE3);
  static const _innerSizeRatio = 10 / 18;

  AnimationController? _controller;
  Animation<double>? _scaleAnim;
  Animation<double>? _opacityAnim;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();

      _scaleAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeOut),
      );
      _opacityAnim = Tween<double>(begin: 0.5, end: 0.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeOut),
      );
    }
  }

  @override
  void didUpdateWidget(covariant PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      oldWidget.animated == widget.animated,
      'PulseDot.animated is treated as immutable and must not change for the same widget instance. '
      'If you need to toggle animation, rebuild PulseDot with a different key.',
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? _defaultColor;
    final outerSize = widget.size ?? 18.r;
    final innerSize =
        widget.innerSize ?? (widget.size ?? 18.r) * _innerSizeRatio;

    if (!widget.animated) {
      final ringColor = widget.ringColor ?? dotColor.withValues(alpha: 0.25);
      return SizedBox(
        width: outerSize,
        height: outerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ringColor,
              ),
            ),
            Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _scaleAnim!.value,
                child: Container(
                  width: outerSize,
                  height: outerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (widget.ringColor ?? dotColor)
                        .withValues(alpha: _opacityAnim!.value),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        ),
      ),
    );
  }
}
