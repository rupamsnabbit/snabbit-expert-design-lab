import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class PaymentOverview extends StatelessWidget {
  final int? amount;
  final String title;
  final VoidCallback? onTap;
  final String imageUrl;
  final Widget? subtitle;

  const PaymentOverview({
    super.key,
    required this.amount,
    required this.title,
    this.onTap,
    required this.imageUrl,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              imageUrl,
              height: 12.r,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.sp,
                            color: const Color(0xFF40515B),
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FittedBox(
                    child: Text(
                      formatIndianCurrency(amount ?? 0),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF40515B),
                              ),
                    ),
                  ),
                  if (subtitle != null) subtitle!
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
