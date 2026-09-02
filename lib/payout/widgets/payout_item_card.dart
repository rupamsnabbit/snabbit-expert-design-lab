import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class PayoutItemCard extends StatelessWidget {
  final String? title;
  final int? amount;
  final Color? amountColor;
  final Widget? subtitle;
  final VoidCallback onTap;

  const PayoutItemCard({
    super.key,
    this.title,
    this.amount,
    this.amountColor,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 60.h,
      ),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.n90,
          side: const BorderSide(color: AppColors.n40),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title ?? "",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                if (amount != null)
                  Text(
                    formatIndianCurrency(amount),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: amountColor,
                    ),
                  ),
                SizedBox(width: 12.w),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.n90,
                  size: 24.sp,
                ),
              ],
            ),
            if (subtitle != null)
              subtitle!,
          ],
        ),
      ),
    );
  }
}
