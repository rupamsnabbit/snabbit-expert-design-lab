import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RainbowAnimBg extends StatefulWidget {
  final Color initColor;
  const RainbowAnimBg({
    super.key,
    required this.initColor,
  });

  @override
  State<RainbowAnimBg> createState() => _RainbowAnimBgState();
}

class _RainbowAnimBgState extends State<RainbowAnimBg> with TickerProviderStateMixin {
  late AnimationController _controller;
  void runRainbowAnimation() {
    _controller.loop(count: 1);
  }

  @override
  void initState() {
    _controller = AnimationController(vsync: this, duration: 3600.ms);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.initColor.withOpacity(0.75),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: List.generate(
          4,
          (i) {
            return Positioned(
              top: 0,
              left: 0,
              child: Container(
                height: 180 + (i * 90),
                width: 180 + (i * 90),
                decoration: BoxDecoration(
                  color: widget.initColor.withOpacity(1 - (i * 0.25)),
                  // border: Border.all(),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(999),
                  ),
                ),
              )
                  .animate(controller: _controller)
                  .slide(duration: 1800.ms, curve: Curves.easeIn)
                  .shimmer(
                    delay: 900.ms,
                    duration: 900.ms,
                  ),
            );
          },
        ),
      ),
    );
  }
}
