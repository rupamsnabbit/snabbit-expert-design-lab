import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/payout/transaction.dart';
import 'package:snabbit_runner/providers/payout_history_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Widget for individual transaction card
class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final PayoutHistoryProvider payoutHistoryProvider;
  final String Function(String?) formatDateShort;
  final String Function(double?) formatAmount;
  final Color Function(Transaction) getTransactionTypeColor;
  final Widget Function(Transaction) getTransactionTypeIcon;
  final String? Function(int?) getTransactionTypeName;
  final String Function(DateTime?) getDay;
  final String Function(DateTime?) getMonth;
  final Widget Function(Transaction) getTransactionDetailsWidget;
  const TransactionCard({
    required this.transaction,
    required this.payoutHistoryProvider,
    required this.formatDateShort,
    required this.formatAmount,
    required this.getTransactionTypeColor,
    required this.getTransactionTypeIcon,
    required this.getTransactionTypeName,
    required this.getDay,
    required this.getMonth,
    required this.getTransactionDetailsWidget,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isTransactionSuccessful = transaction.transactionTypeId == 1;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            offset: Offset(0, 2.h),
            blurRadius: 4.r,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date icon container
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: AppColors.n20,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Date text
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        getDay(transaction.transactionDate),
                        style: textTheme.displayMedium?.copyWith(
                          fontSize: 16.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        getMonth(transaction.transactionDate),
                        style: textTheme.bodySmall?.copyWith(
                          color: Color(0xFF6D7783),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                //todo: convert the above text, to show only the day and month on separate lines and styles
                // Transaction type indicator
                Positioned(
                  left: -10.w,
                  top: -5.h,
                  child: getTransactionTypeIcon(transaction),
                ),
              ],
            ),
          ),

          SizedBox(width: 12.w),

          // Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transaction type and amount row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        child: Text(
                          (isTransactionSuccessful
                              ? 'Withdrawal successful'
                              : 'Withdrawal failed'),
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.011,
                            color: isTransactionSuccessful
                                ? AppColors.g40
                                : AppColors.r40,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        formatAmount(transaction.amount),
                        style: textTheme.displayMedium?.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.011,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 4.h),

                // Description
                Text(
                  transaction.description ?? '',
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.n70,
                    letterSpacing: -0.02,
                  ),
                ),

                SizedBox(height: 4.h),

                // Transaction details (bank/UPI/period)
                getTransactionDetailsWidget(transaction),

                SizedBox(height: 4.h),

                // Transaction ID
                Text(
                  'Transaction ID : ${transaction.externalReferenceId ?? ''}',
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.n70,
                    letterSpacing: -0.02,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
