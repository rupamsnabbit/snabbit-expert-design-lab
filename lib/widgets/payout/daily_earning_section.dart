import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/daily_earnings_models.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

import '../../constants/assets_constants.dart';
import '../../utils/common_methods.dart';
import 'payment_overview.dart';

class DailyEarningSection extends StatefulWidget {
  final DailyEarnings? data;
  final String? earnStatusText;

  const DailyEarningSection({
    super.key,
    this.data,
    this.earnStatusText,
  });

  @override
  State<DailyEarningSection> createState() => _DailyEarningSectionState();
}

class _DailyEarningSectionState extends State<DailyEarningSection>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _iconController.forward();
      } else {
        _iconController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    if (widget.data == null) {
      return const SizedBox();
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
        ),
        padding: EdgeInsets.all(24.r),
        margin: EdgeInsets.symmetric(vertical: 16.h),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 40.r, color: Colors.grey),
              SizedBox(height: 16.h),
              Text(
                languageProvider.getMessage(
                    'no_earnings_data', 'No earnings data available'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.n90,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.all(24.r),
      margin: EdgeInsets.symmetric(vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getMessage(
              'daily_earning',
              'Daily Earning',
            ),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.n90,
                  fontSize: 16.sp,
                ),
          ),
          if (widget.earnStatusText != null && widget.earnStatusText != "")
            SizedBox(height: 4.h),

          if (widget.earnStatusText != null && widget.earnStatusText != "")
            Text(
              languageProvider.getMessage(
                  widget.earnStatusText!, widget.earnStatusText!),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.n90),
            ),
          SizedBox(height: 10.h),
          const Divider(color: Color(0xffD0D0D0)),
          SizedBox(height: 10.h),

          // Dynamic rows for earning items
          if (widget.data?.lineItems != null)
            ...processLineItems(context, widget.data!.lineItems!),

          SizedBox(height: 5.h),
          const Divider(color: Color(0xffD0D0D0)),
          SizedBox(height: 5.h),

          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                languageProvider.getMessage('total', 'Total'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.g50,
                    ),
              ),
              Text(
                formatIndianCurrency(widget.data!.totalAmount?.toInt() ?? 0),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.g50,
                    ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          SizeTransition(
            sizeFactor: _iconController,
            axisAlignment: -1.0,
            child: Column(
              children: [
                SizedBox(height: 10.h),
                _buildDetailedBreakdown(context),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // Toggle button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isExpanded
                    ? languageProvider.getMessage(
                        'hide_breakdown',
                        'Hide Breakdown',
                      )
                    : languageProvider.getMessage(
                        'view_breakdown',
                        'View Breakdown',
                      ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff40515B),
                    ),
              ),
              SizedBox(width: 8.w),
              SizedBox(
                width: 24.r,
                height: 18.r,
                child: OutlinedButton(
                  onPressed: _toggleExpanded,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.n90,
                    side: const BorderSide(color: AppColors.n50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RotationTransition(
                      turns:
                          Tween(begin: 0.0, end: 0.5).animate(_iconController),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  // Simplified implementation to match consistent lineItems structure
  List<Widget> processLineItems(
      BuildContext context, List<LineItem> lineItems) {
    final List<Widget> widgets = [];
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    for (int i = 0; i < lineItems.length; i++) {
      LineItem item = lineItems[i];
      bool isFirst = i == 0; // All items after the first will be positive

      // Create label text, including suffix in parentheses when available
      String label =
          languageProvider.getMessage(item.key ?? '', item.key ?? '');

      String? subtitle = item.subtitle == null
          ? null
          : languageProvider.getMessage(
              item.subtitle ?? '', item.subtitle ?? '');

      if (item.value.suffix != null && item.value.suffix!.isNotEmpty) {
        label +=
            " (${languageProvider.getMessage(item.value.suffix ?? '', item.value.suffix ?? '')})";
      }

      bool isPositive = !isFirst && (item.value.amount?.toDouble() ?? 0) >= 0;
      bool isNegative = (item.value.amount?.toDouble() ?? 0) < 0;

      widgets.add(
        Column(
          children: [
            _buildEarningRow(
              context,
              label,
              subtitle,
              item.value.amount?.toDouble() ?? 0,
              isPositive: isPositive,
              isNegative: isNegative,
              count: item.value.count,
              countAsset: item.value.countAsset,
            ),
            SizedBox(height: 6.h),
          ],
        ),
      );
    }

    return widgets;
  }

  Widget _buildDetailedBreakdown(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.n20,
        borderRadius: BorderRadius.circular(8.r),
      ),
      // padding: EdgeInsets.all(16.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: PaymentOverview(
              amount: widget.data?.totalAmount?.toInt() ?? 0,
              title: languageProvider.getMessage("total", "Total"),
              imageUrl: AssetConstants.cashCollected,
            ),
          ),
          Text(
            "=",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Flexible(
            child: PaymentOverview(
              amount: anyValueToInt(widget.data?.cashCollected ?? 0),
              title: languageProvider.getMessage(
                  "cash_collected", "Cash Collected"),
              imageUrl: AssetConstants.cashCollected,
            ),
          ),
          Text(
            "+",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          // SizedBox(
          //   height: 44.h,
          //   child: VerticalDivider(
          //     color: AppColors.n20,
          //     thickness: 1.r,
          //     width: 0.w,
          //   ),
          // ),
          Flexible(
            child: PaymentOverview(
              amount: anyValueToInt(widget.data?.amountDue ?? 0),
              title: languageProvider.getMessage("amount_due", "Amount due"),
              imageUrl: AssetConstants.amountDue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningRow(
    BuildContext context,
    String label,
    String? subtitle,
    double amount, {
    bool isPositive = false,
    bool isNegative = false,
    Color color = AppColors.n60,
    int? count,
    String? countAsset,
  }) {
    color = subtitle != null ? AppColors.n90 : AppColors.n60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: subtitle != null
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: color,
                        ),
                  ),
                  PenaltyCardView(
                    cardCount: count,
                    asset: countAsset,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (isPositive)
                  Text(
                    "+ ",
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: color,
                        ),
                  ),
                if (isNegative)
                  Text(
                    "- ",
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: color,
                        ),
                  ),
                Text(
                  formatIndianCurrency(amount.abs().toInt()),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: color,
                      ),
                ),
              ],
            ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 0.h),
            child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class PenaltyCardView extends StatelessWidget {
  final int? cardCount;
  final String? asset;

  const PenaltyCardView({
    super.key,
    this.cardCount,
    this.asset,
  });

  @override
  Widget build(BuildContext context) {
    if (cardCount == null || asset == null) return const SizedBox();
    return Padding(
      padding: EdgeInsets.only(left: 8.w),
      child: Row(
        children: [
          Image.network(
            asset ?? "",
            height: 20.r,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
          if (cardCount != null && cardCount! > 1)
            Text(
              " x$cardCount",
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.n60,
                  ),
            ),
        ],
      ),
    );
  }
}
