import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../utils/colors.dart';

class CustomProgressBar extends StatelessWidget {
  final double progress; // Value between 0.0 and 1.0
  final Widget? endValue;
  final bool addMileStoneLock;
  final bool addEndCircle;

  /// lockPosition means when the success happens inversely
  /// Eg. if lockPosition is 0 then success requirement of progress is 100%
  /// Eg. if lockPosition is 0.25 then success requirement of progress is 75%
  final double lockPosition;
  final Color? color;

  const CustomProgressBar({
    required this.progress,
    this.endValue,
    this.addMileStoneLock = true,
    this.addEndCircle = true,
    required this.lockPosition,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24.h,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          double filledWidth = constraints.maxWidth * progress;
          double successDonePosition = 1.0 - lockPosition;
          return Stack(
            children: [
              // Full progress bar (background)
              Center(
                child: Container(
                  height: 10.h,
                  decoration: BoxDecoration(
                    color: AppColors.n30, // Light grey background
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),

              // Filled progress bar (foreground)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  // alignment: Alignment.center,
                  height: 10.h,
                  width: filledWidth,
                  decoration: BoxDecoration(
                    gradient: color != null
                        ? null
                        : const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFFFD522),
                              Color(0xFFFCAF42),
                            ],
                          ),
                    color: color ?? AppColors.y40, // Green foreground
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),

              // Lock icon at the end
              if (addMileStoneLock)
                Positioned(
                  right: constraints.maxWidth * lockPosition,
                  child: progress >= successDonePosition
                      ? Container(
                          width: 24.r,
                          height: 24.r,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xff47369E),
                          ),
                          padding: EdgeInsets.all(2.r),
                          child: FittedBox(
                            child: Image.asset(
                              "assets/pngs/custom_progress_bar_reward.png",
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.currency_rupee_rounded,
                                color: AppColors.y40,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 24.r,
                          width: 24.r,
                          decoration: const BoxDecoration(
                            color: AppColors.n30,
                            // color: progress >= successDonePosition
                            //     ? AppColors.g40
                            //     : AppColors.n30,
                            // color: AppColors.g40,
                            shape: BoxShape.circle,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Icon(
                              Icons.lock,
                              size: 17.sp,
                              color: const Color(0xff9CA2BA),
                            ),
                          ),
                        ),
                ),
              if (addEndCircle)
                Positioned(
                  right: 0,
                  child: Container(
                    height: 24.r,
                    width: 24.r,
                    decoration: BoxDecoration(
                      color: progress >= 1.0 ? AppColors.g40 : AppColors.n30,
                      // color: AppColors.r50,
                      shape: BoxShape.circle,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: endValue,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
