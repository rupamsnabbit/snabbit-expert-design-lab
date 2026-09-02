import 'package:flutter/material.dart';

class DashedLineVerticalPainter extends CustomPainter {
  DashedLineVerticalPainter({
    this.dashHeight = 5,
    this.dashSpace = 3,
    this.color = Colors.grey,
  });

  final double dashHeight, dashSpace;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    double startY = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
