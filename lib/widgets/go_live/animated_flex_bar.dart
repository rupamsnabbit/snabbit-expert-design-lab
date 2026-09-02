import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AnimatedFlexBar extends StatelessWidget {
  final int totalEarnings;
  final int maxEarnings;
  final bool isWeekday;
  final bool showIndicator;

  const AnimatedFlexBar({
    super.key,
    required this.totalEarnings,
    required this.maxEarnings,
    required this.isWeekday,
    this.showIndicator=true,
  });

  @override
  Widget build(BuildContext context) {
    final maxEarnings= this.maxEarnings.toDouble();
    final totalEarnings= this.totalEarnings.toDouble();
    // To avoid divide-by-zero and bound flexes between 0–1
    final safeMax = maxEarnings == 0 ? 1.0 : maxEarnings;
    final startRatio = (totalEarnings / safeMax).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: startRatio),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      builder: (context, animatedRatio, child) {
        final earnedFlex = (animatedRatio * 100).round();
        final remainingFlex = 100 - earnedFlex;
        final isAnimating = animatedRatio != startRatio && animatedRatio != 0;

        return Row(
          children: [
            Expanded(
              flex: earnedFlex,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 13.6.h, // or your fixed height
                    decoration: isWeekday? BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFA47A00),
                          Color(0xFF37A660),
                          Color(0xFF107C41),
                        ],
                        stops: [0, 0, 1],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius:
                      BorderRadius.circular(4.6),
                      border: Border.all(
                        color: const Color(0xFF3F3F3F),
                        width: 1.16.r,
                      ),
                    ):BoxDecoration(
                      color: const Color(0xFFFFCC00),
                      borderRadius:
                      BorderRadius.circular(4.6),
                      border: Border.all(
                        color: const Color(0xFF3F3F3F),
                        width: 1.16,
                      ),
                    ),
                  ),
                  if(isAnimating && showIndicator)
                    Positioned(
                      right: -8,
                      child: isWeekday ?const GreenRadiantCircle(): const YellowRadiantCircle(),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: remainingFlex,
              child: const SizedBox(),
            ),
          ],
        );
      },
    );
  }
}


// A custom Flutter widget to display a radiant green circle.
class GreenRadiantCircle extends StatelessWidget {
  const GreenRadiantCircle({super.key,});

  @override
  Widget build(BuildContext context) {
    // The Stack widget allows positioning children widgets on top of one another.
    return SizedBox(
      width: 16.w, // The total width of the group.
      height: 24.h, // The total height of the group.
      child: Stack(
        children: [
          // This is the first, larger ellipse with the radial gradient.
          // It creates the outer, softer green glow.
          // The left and top properties are adjusted to center it within the stack.
          Positioned(
            left: 0,
            top: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Use a BoxShape.circle to create a circular shape.
                shape: BoxShape.circle,
                // The radial gradient from the CSS, converted to Dart.
                // The colors are the key to the glowing effect.
                gradient: const RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    Color(0xFF15FF00), // The center of the gradient.
                    Color(0x00289654), // Fades to transparent at the edge.
                  ],
                  stops: [0.0, 1.0],
                ),
                // The blur effect is applied using a BoxShadow with a spread radius.
                // Note: Flutter's blur is handled differently than CSS.
                // A BoxShadow with a blurRadius can be used to simulate a blur filter.
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF15FF00).withOpacity(0.5), // A hint of color for the blur.
                    blurRadius: 1.55,
                    spreadRadius: 1.55,
                  ),
                ],
              ),
              child: SizedBox(
                width: 16.w, // Width from the CSS.
                height: 18.h, // Height from the CSS.
              ),
            ),
          ),
          // This is the second, smaller ellipse with a different radial gradient.
          // It creates the inner, brighter yellow-green core of the glow.
          // It's positioned on top of the first circle.
          Positioned(
            left: 3,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Use a BoxShape.circle to create a circular shape.
                shape: BoxShape.circle,
                // The second radial gradient from the CSS.
                // The multiple color stops create the vibrant, multi-layered glow.
                gradient: const RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    Color(0xFFB3FF00), // Bright yellow-green at the core.
                    Color(0xED6DF806),
                    Color(0xAD5BDD1B),
                    Color(0x00289654), // Fading to transparent.
                  ],
                  stops: [0.0, 0.2958, 0.4906, 0.70],
                ),
                // BoxShadow is used again to simulate the blur filter.
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB3FF00).withOpacity(0.5),
                    blurRadius: 1.615,
                    spreadRadius: 1.615,
                  ),
                ],
              ),
              child: SizedBox(
                width: 10.w, // Width from the CSS.
                height: 24.h, // Height from the CSS.
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A custom Flutter widget to display a radiant yellow circle.
class YellowRadiantCircle extends StatelessWidget {
  const YellowRadiantCircle({super.key});

  @override
  Widget build(BuildContext context) {
    // The Stack widget allows positioning children widgets on top of one another.
    return SizedBox(
      width: 16.w,
      height: 24.h,
      child: Stack(
        children: [
          // This is the first, larger ellipse with the radial gradient.
          // It creates the outer, softer yellow glow.
          Positioned(
            left: 0,
            top: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Use a BoxShape.circle to create a circular shape.
                shape: BoxShape.circle,
                // The radial gradient from the CSS, converted to Dart.
                gradient: const RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    Color(0xFFFFF700), // The center of the gradient.
                    Color(0x00969628), // Fades to transparent at the edge.
                  ],
                  stops: [0.0, 1.0],
                ),
                // The blur effect is applied using a BoxShadow.
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFF700).withOpacity(0.5),
                    blurRadius: 1.55,
                    spreadRadius: 1.55,
                  ),
                ],
              ),
              child: SizedBox(
                width: 16.w,
                height: 18.h,
              ),
            ),
          ),
          // This is the second, smaller ellipse with a different radial gradient.
          // It creates the inner, brighter yellow core of the glow.
          Positioned(
            left: 3,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Use a BoxShape.circle to create a circular shape.
                shape: BoxShape.circle,
                // The second radial gradient from the CSS.
                // The multiple color stops create the vibrant, layered glow.
                gradient: const RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    Color(0xFFFFDC00), // Bright yellow at the core.
                    Color(0xEDF7FF00),
                    Color(0xADEFFF00),
                    Color(0x00F2FF00), // Fading to transparent.
                  ],
                  stops: [0.0, 0.2958, 0.4906, 0.70],
                ),
                // BoxShadow is used again to simulate the blur filter.
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFDC00).withOpacity(0.5),
                    blurRadius: 1.615,
                    spreadRadius: 1.615,
                  ),
                ],
              ),
              child: SizedBox(
                width: 10.w,
                height: 24.h,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
