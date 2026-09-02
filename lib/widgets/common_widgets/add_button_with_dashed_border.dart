import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double radius;

  DashedRoundedBorderPainter({
    required this.color,
    this.strokeWidth = 1,
    this.dashWidth = 6,
    this.dashGap = 4,
    this.radius = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;

    double distance = 0;
    while (distance < metrics.length) {
      final length = dashWidth;
      canvas.drawPath(
        metrics.extractPath(distance, distance + length),
        paint,
      );
      distance += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AddButtonWithDashedBorder extends StatelessWidget {
  final String text;
  const AddButtonWithDashedBorder({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedRoundedBorderPainter(
        color: AppColors.brand,
        strokeWidth: 1,
        dashWidth: 6.r,
        dashGap: 4.r,
        radius: 8.r,
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.n90,
                    ),
              ),
            ),
            Icon(
              Icons.add,
              size: 28.r,
              color: AppColors.brand,
            ),
          ],
        ),
      ),
    );
  }
}
