import 'package:flutter/material.dart';

/// Three concentric circles with vertical white-to-transparent gradient at 0.4 opacity.
/// Centered in the available bounds to match the bottom sheet design.
class ShieldBackgroundCirclesPainter extends CustomPainter {
  static const double _viewBoxSize = 237;
  static const List<double> _radii = [76, 61, 44];
  static const double _opacity = 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale to fit and center circles in the visible area (width x height)
    final scale = size.width / _viewBoxSize;
    final center = Offset((size.width / 2), (size.height / 2) + 24);

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Colors.white.withOpacity(0),
      ],
    );
    final gradientRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final shader = gradient.createShader(gradientRect);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    for (final r in _radii) {
      final radius = r * scale;
      final bounds = Rect.fromCircle(center: center, radius: radius);

      canvas.saveLayer(
          bounds, Paint()..color = Colors.white.withOpacity(_opacity));
      canvas.drawCircle(center, radius, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
