import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../utils/colors.dart';

/// CDN header artwork for nudge sheets (emergency logout, attendance change, etc.).
const String kNudgesBottomSheetBackgroundUrl =
    'https://assets-expert.snabbit.com/payouts/nudges/nudges_bs_bg.png';

class CommonBottomSheetSetup extends StatelessWidget {
  final Widget child;
  final double horizontalPadding;
  final Color? bgColor;
  final LinearGradient? gradient;
  final bool showDragHandle;
  final double bottomPadding;
  final BorderRadius? borderRadius;

  /// When set, a top band (Figma ~185) shows this image above the white surface.
  final String? backgroundImageUrl;

  const CommonBottomSheetSetup({
    super.key,
    required this.child,
    this.horizontalPadding = 16,
    this.bgColor,
    this.gradient,
    this.showDragHandle = true,
    this.bottomPadding = 28,
    this.borderRadius,
    this.backgroundImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ?? BorderRadius.vertical(top: Radius.circular(16.r));

    final column = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding.w),
      child: Column(
        children: [
          if (showDragHandle)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10.h),
                Center(
                  child: Container(
                    height: 4.h,
                    width: 36.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4.h),
                      color: const Color(0xffD1D1D1),
                    ),
                  ),
                ),
              ],
            ),
          child,
          SizedBox(height: bottomPadding.h),
        ],
      ),
    );

    final Widget sheetBody;
    if (backgroundImageUrl != null) {
      sheetBody = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Container(
              color: bgColor ?? AppColors.n0,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 185.h,
            child: CachedNetworkImage(
              imageUrl: backgroundImageUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          column,
        ],
      );
    } else {
      sheetBody = Container(
        decoration: BoxDecoration(
          color: bgColor ?? AppColors.n0,
          gradient: gradient,
        ),
        child: column,
      );
    }

    return SingleChildScrollView(
      child: ClipRRect(
        borderRadius: radius,
        child: sheetBody,
      ),
    );
  }
}
