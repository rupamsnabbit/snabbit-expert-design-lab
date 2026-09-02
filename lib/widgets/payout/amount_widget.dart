import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';

abstract class AmountWidget extends StatelessWidget {
  final int amount;

  const AmountWidget({
    super.key,
    required this.amount,
  });

  factory AmountWidget.create({
    required int amount,
    PaymentState? state,
  }) {
    switch (state) {
      case PaymentState.pending:
        return PendingAmountWidget(amount: amount);
      case PaymentState.earned:
        return EarnedAmountWidget(amount: amount);
      case PaymentState.missed:
        return MissedAmountWidget(amount: amount);
      case PaymentState.deducted:
        return DeductedAmountWidget(amount: amount);
      default:
        return DefaultWidget(amount: amount);
    }
  }
}

class EarnedAmountWidget extends AmountWidget {
  const EarnedAmountWidget({
    super.key,
    required super.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      formatIndianCurrency(amount),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF40515B),
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class PendingAmountWidget extends AmountWidget {
  const PendingAmountWidget({
    super.key,
    required super.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.1.w, vertical: 9.3.h),
        decoration: BoxDecoration(
          color: AppColors.g40,
          borderRadius: BorderRadius.circular(1000.r),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            languageProvider.getMessage(
              'view_details',
              'View Details',
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.n0,
                ),
          ),
        ),
      ),
    );
  }
}

class MissedAmountWidget extends AmountWidget {
  const MissedAmountWidget({
    super.key,
    required super.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Original amount (slashed)
        Text(
          formatIndianCurrency(amount),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8F969B),
                decoration: TextDecoration.lineThrough,
              ),
        ),
        SizedBox(
          width: 2.w,
        ),
        // Zero amount
        Text(
          "₹0",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF40515B),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class DeductedAmountWidget extends AmountWidget {
  const DeductedAmountWidget({
    super.key,
    required super.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      formatIndianCurrency(-1 * amount),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.r60,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class DefaultWidget extends AmountWidget {
  const DefaultWidget({
    super.key,
    required super.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      formatIndianCurrency(amount),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF40515B),
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
