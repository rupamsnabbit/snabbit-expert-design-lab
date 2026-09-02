import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Widget to display other pending payouts including custom bonuses and arrears
class OtherPendingPayout extends StatefulWidget {
  const OtherPendingPayout({super.key});

  @override
  State<OtherPendingPayout> createState() => _OtherPendingPayoutState();
}

class _OtherPendingPayoutState extends State<OtherPendingPayout> {
  bool init = true;
  late PayoutProvider payoutProvider;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  /// Get custom bonus list from earnings model
  List<OtherPayout>? get pendingPayouts {
    return payoutProvider.earnings?.otherPendingPayouts;
  }

  /// Check if there are any pending payouts to display
  bool get hasPendingPayouts {
    return (pendingPayouts != null && pendingPayouts!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPendingPayouts) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(
        minHeight: 100.h,
        maxHeight: 300.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.n0,
        border: Border.all(color: const Color(0xff0C0C0D).withOpacity(0.1)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.getMessage(
                  'other_pending_payout',
                  'Other Pending Payout',
                ),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff40515B),
                    ),
              ),
              SizedBox(height: 12.h),
              Container(
                height: 1.h,
                color: const Color(0xffD0D0D0),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Pending payout items section
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Custom Bonuses
                  if (pendingPayouts != null && pendingPayouts!.isNotEmpty)
                    ...pendingPayouts!.map((bonus) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPendingPayoutItem(
                            title: languageProvider.getMessage(
                                bonus.title ?? '', bonus.title ?? ''),
                            amount: bonus.amount ?? 0,
                            subtitle: bonus.subtitle,
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a pending payout item row with title, amount, and optional subtitle
  Widget _buildPendingPayoutItem({
    required String title,
    required double amount,
    String? subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.n70,
                    ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.n70,
                      ),
                ),
              ],
            ],
          ),
          Text(
            formatIndianCurrency2(amount),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.g40,
                ),
          ),
        ],
      ),
    );
  }
}
