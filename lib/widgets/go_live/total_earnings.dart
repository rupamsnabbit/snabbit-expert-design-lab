import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class TotalEarnings extends StatelessWidget {
  final int amount;
  final List<Color> gradientColors;
  final String? emojiUrl;

  const TotalEarnings({
    super.key,
    required this.amount,
    required this.gradientColors,
    this.emojiUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 118.w,
        height: 33.h,
        decoration: BoxDecoration(
          color: const Color(0xFF289654),
          border: Border.all(
            color: const Color(0xFF3F3F3F),
            width: 1.39333,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF3F3F3F),
              offset: Offset(0, 1.39333),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
          borderRadius: BorderRadius.circular(5.57333),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Inner background gradient rectangle (overflowing)
            Container(
              width: 140.w,
              height: 38.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                  stops: [0.1437, 0.9379],
                ),
                borderRadius: BorderRadius.circular(5.25),
              ),
            ),
            // Amount text
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 1.2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      emojiUrl ?? '',
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(),
                      width: 22.r,
                    ),
                    SizedBox(width: 7.68.w),
                    Text(
                      formatIndianCurrency(amount),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 14.86.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.13,
                        height: 1.1,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
