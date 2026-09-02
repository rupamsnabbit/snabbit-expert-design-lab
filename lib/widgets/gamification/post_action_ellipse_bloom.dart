import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Soft circular bloom — Figma `6705:144672` (Ellipse 13967).
///
/// Penalty: `rgba(250, 56, 56, 0.50)` + `blur(70px)`.
/// Reward:  `rgba(255, 180, 0, 0.50)` + `blur(70px)`.
///
/// Sits **above** the star rays and **below** coins.
class PostActionEllipseBloom extends StatelessWidget {
  const PostActionEllipseBloom({
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

  // Figma CSS: background: rgba(250, 56, 56, 0.50)
  static const _penaltyColor = Color(0x80FA3838); // #FA3838 @ 50%
  // Reward equivalent — warm amber @ 50%.
  static const _rewardColor = Color(0x80FFB400); // #FFB400 @ 50%

  @override
  Widget build(BuildContext context) {
    // Figma: border-radius: 300px → 300pt diameter circle.
    final d = 300.sp;

    return Positioned(
      left: -horizontalOutset,
      right: -horizontalOutset,
      top: -topOutset,
      bottom: -bottomOutset,
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Center(
            // Figma ellipse center ≈ 9px below star center on 393pt wide screen.
            child: Transform.translate(
              offset: Offset(0, 9.h),
              // Figma CSS: filter: blur(70.09px)
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 70,
                  sigmaY: 70,
                  tileMode: TileMode.decal,
                ),
                child: Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isReward ? _rewardColor : _penaltyColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
