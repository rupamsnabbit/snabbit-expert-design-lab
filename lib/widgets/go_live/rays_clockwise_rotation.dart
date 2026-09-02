import 'package:flutter/material.dart';
import 'dart:math' as math;

class RaysClockwiseRotation extends StatefulWidget {
  final double size;
  final Duration duration;
  final Widget raysImage;

  const RaysClockwiseRotation({
    super.key,
    required this.size,
    required this.raysImage,
    this.duration = const Duration(seconds: 20),
  });

  @override
  State<RaysClockwiseRotation> createState() => _RaysClockwiseRotationState();
}

class _RaysClockwiseRotationState extends State<RaysClockwiseRotation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(); // Infinite clockwise rotation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: child,
          );
        },
        child: widget.raysImage,
      ),
    );
  }
}
