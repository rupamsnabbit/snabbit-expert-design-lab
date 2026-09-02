import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 10-point star rays — Figma `6705:144671` (Star 35).
///
/// Wide petal-shaped rays (quadratic bezier) with a bright hub fading to
/// transparent tips. Slowly rotates while visible.
/// Placed **under** [PostActionEllipseBloom].
class PostActionSoftStarburst extends StatefulWidget {
  const PostActionSoftStarburst({
    super.key,
    required this.isReward,
    required this.horizontalOutset,
    required this.topOutset,
    required this.bottomOutset,
  });

  final bool isReward;
  final double horizontalOutset;
  final double topOutset;
  final double bottomOutset;

  @override
  State<PostActionSoftStarburst> createState() =>
      _PostActionSoftStarburstState();
}

class _PostActionSoftStarburstState extends State<PostActionSoftStarburst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationCtrl;

  @override
  void initState() {
    super.initState();
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -widget.horizontalOutset,
      right: -widget.horizontalOutset,
      top: -widget.topOutset,
      bottom: -widget.bottomOutset,
      child: RepaintBoundary(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _rotationCtrl,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationCtrl.value * 2 * math.pi,
                child: child,
              );
            },
            // Light blur only — Figma star is crisp rays + soft transparency.
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 1.8,
                sigmaY: 1.8,
                tileMode: TileMode.decal,
              ),
              child: CustomPaint(
                painter: _FigmaStarRaysPainter(isReward: widget.isReward),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FigmaStarRaysPainter extends CustomPainter {
  _FigmaStarRaysPainter({required this.isReward});

  final bool isReward;

  static const int _rays = 10;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rMax = size.shortestSide * 0.38;
    // Wide petal half-angle — ~70 % of each sector to match Figma shape.
    final halfAngle = math.pi / _rays * 0.70;
    // Bezier control-point radius — where the petal is widest.
    final rCtrl = rMax * 0.45;

    final hub = isReward
        ? const Color(0xFFFFF9F0)
        : const Color(0xFFFFFBFB);
    final mid = isReward
        ? const Color(0xFFFFF2DC)
        : const Color(0xFFFFE8E8);

    for (var i = 0; i < _rays; i++) {
      final a0 = -math.pi / 2 + i * 2 * math.pi / _rays;

      final tipX = center.dx + rMax * math.cos(a0);
      final tipY = center.dy + rMax * math.sin(a0);

      // Petal shape: narrow at center, wide at mid-radius, pointed at tip.
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          center.dx + rCtrl * math.cos(a0 - halfAngle),
          center.dy + rCtrl * math.sin(a0 - halfAngle),
          tipX,
          tipY,
        )
        ..quadraticBezierTo(
          center.dx + rCtrl * math.cos(a0 + halfAngle),
          center.dy + rCtrl * math.sin(a0 + halfAngle),
          center.dx,
          center.dy,
        )
        ..close();

      final tip = Offset(tipX, tipY);

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          center,
          tip,
          [
            hub.withValues(alpha: 0.12),
            mid.withValues(alpha: 0.05),
            mid.withValues(alpha: 0.0),
          ],
          const [0.0, 0.55, 1.0],
        );
      canvas.drawPath(path, paint);
    }

    // Subtle nucleus glow.
    final corePaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        rMax * 0.14,
        [
          hub.withValues(alpha: 0.08),
          hub.withValues(alpha: 0.0),
        ],
      );
    canvas.drawCircle(center, rMax * 0.14, corePaint);
  }

  @override
  bool shouldRepaint(covariant _FigmaStarRaysPainter old) =>
      old.isReward != isReward;
}
