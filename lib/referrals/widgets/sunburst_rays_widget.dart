import 'dart:math';
import 'package:flutter/material.dart';

class SunburstRaysWidget extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final double verticalPosition;
  final Widget? child;
  final Duration animationDuration;

  const SunburstRaysWidget({
    Key? key,
    required this.primaryColor,
    required this.secondaryColor,
    this.verticalPosition = 0.4,
    this.child,
    this.animationDuration = const Duration(seconds: 50),
  }) : super(key: key);

  @override
  State<SunburstRaysWidget> createState() => _SunburstRaysWidgetState();
}

class _SunburstRaysWidgetState extends State<SunburstRaysWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: SunburstRaysPainter(
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
            verticalPosition: widget.verticalPosition,
            rotationAngle: _rotationAnimation.value,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class SunburstRaysPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double verticalPosition;
  final int rayCount;
  final double rayOpacity;
  final double blurSigma;
  final double
      wedgeThicknessFactor; // 0..1 proportion of step filled by a wedge
  final BlendMode blendMode;
  final double rotationAngle;

  SunburstRaysPainter({
    required this.primaryColor,
    required this.secondaryColor,
    this.verticalPosition = 0.36,
    this.rayCount = 28,
    this.rayOpacity = 0.34,
    this.blurSigma = 4.0,
    this.wedgeThicknessFactor = 0.92,
    this.blendMode = BlendMode.screen,
    this.rotationAngle = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background radial gradient: brighter near origin, darker at edges
    final Paint backgroundPaint = Paint()
      ..color = primaryColor
      ..shader = RadialGradient(
        center: Alignment(0, (verticalPosition - 0.5) * 2),
        radius: 4,
        colors: [
          Color.lerp(primaryColor, const Color(0xFFFFFFFF), 0.18)!,
          Color.lerp(primaryColor, const Color(0xFF000000), 0.10)!,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Rays origin
    final double originX = size.width / 2;
    final double originY = size.height * verticalPosition;
    final Offset center = Offset(originX, originY);

    // Large radius to fully cover widget
    final double radius =
        sqrt(size.width * size.width + size.height * size.height);
    final Rect circle = Rect.fromCircle(center: center, radius: radius);

    // Angular setup
    final double step = (2 * pi) / rayCount;
    final double wedgeSweep =
        step * wedgeThicknessFactor; // leave subtle gap between wedges
    final double baseRotation =
        -pi / 2 + rotationAngle; // start pointing up, then rotate

    final Paint wedgePaint = Paint()
      ..style = PaintingStyle.fill
      // ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma)
      ..blendMode = blendMode;

    // Draw every alternate wedge in secondary color over the primary background
    for (int i = 0; i < rayCount; i++) {
      if (i % 2 != 0) continue;

      final double startAngle = baseRotation + i * step;
      final Path p = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + cos(startAngle) * radius,
            center.dy + sin(startAngle) * radius)
        ..arcTo(circle, startAngle, wedgeSweep, false)
        ..close();

      wedgePaint.color = secondaryColor.withOpacity(rayOpacity);
      canvas.drawPath(p, wedgePaint);
    }

    // Subtle vignette at the very edges for depth
    final Paint vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, (verticalPosition - 0.5) * 2),
        radius: 4,
        colors: [
          Color(0xff545BC4).withOpacity(0.9),
          Color(0xffBEE5FF).withOpacity(0.2)
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is SunburstRaysPainter) {
      return oldDelegate.primaryColor != primaryColor ||
          oldDelegate.rotationAngle != rotationAngle;
    }
    return true;
  }
}
