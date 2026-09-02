import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Red card illustration — stylised card with penalty value (Figma 6705:143559)
// ─────────────────────────────────────────────────────────────────────────────

class RedCardIllustration extends StatelessWidget {
  const RedCardIllustration({super.key, required this.count});

  /// Number of red cards to display side by side.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count.clamp(1, 9), (i) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: SingleRedCard(),
        );
      }),
    );
  }
}

class SingleRedCard extends StatelessWidget {
  const SingleRedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cardWidth = 69.sp;
    final cardHeight = 98.sp;

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl:
                'https://assets-expert.snabbit.com/payouts/nudges/red_card_display.png',
            width: cardWidth,
            height: cardHeight,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer stripes (Figma 6705:143543-143545) — lighter gradient version
// ─────────────────────────────────────────────────────────────────────────────

class ShimmerStripes extends StatelessWidget {
  const ShimmerStripes({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const ShimmerStripesPainter(),
      size: Size.infinite,
    );
  }
}

class ShimmerStripesPainter extends CustomPainter {
  const ShimmerStripesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient: #ccc → #e5e5e5 (60%) → white
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFCCCCCC),
          Color(0xFFE5E5E5),
          Colors.white,
        ],
        stops: [0.0, 0.60, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Diagonal stripes
    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    const stripeWidth = 18.0;
    const gap = 12.0;
    final totalWidth = size.width + size.height;
    for (var x = -size.height; x < totalWidth; x += stripeWidth + gap) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripeWidth, size.height)
        ..lineTo(x + size.height + stripeWidth, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
