import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/payout/amount_widget.dart';

class EarningItemCard extends StatelessWidget {
  final String title;
  final int amount;
  final VoidCallback? onTap;
  final Widget? trailingIcon;
  final Color? textColor;
  final Color? amountColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final Widget? subtitle;
  final PaymentState? paymentState;

  const EarningItemCard({
    super.key,
    required this.title,
    required this.amount,
    this.onTap,
    this.trailingIcon,
    this.textColor,
    this.amountColor,
    this.borderColor,
    this.backgroundColor,
    this.subtitle,
    this.paymentState,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          minimumSize: Size(double.infinity, 64.h),
          backgroundColor: backgroundColor ?? AppColors.n0,
          side: BorderSide(
            color: borderColor ?? AppColors.n40,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          foregroundColor: textColor ?? AppColors.g50,
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    softWrap: true,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: textColor ?? AppColors.g50,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (subtitle != null) subtitle!,
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AmountWidget.create(
                  amount: amount,
                  state: paymentState,
                ),
                SizedBox(width:paymentState==PaymentState.pending? 0 : 12.w),
                trailingIcon ??
                    Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF40515B),
                      size: 24.sp,
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
