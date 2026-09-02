import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/payout/bonus_home.dart';
import 'package:snabbit_runner/pages/payout/daily_earnings_list.dart';
import 'package:snabbit_runner/pages/payout/tips_info_screen.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:intl/intl.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/payout/widgets/additional_payout_item.dart';

/// Widget to display work earnings breakdown including daily earnings,
/// monthly bonus, customer tips, taxes, deductions, and net earnings
class WorkEarningsBreakdown extends StatefulWidget {
  const WorkEarningsBreakdown({super.key});

  @override
  State<WorkEarningsBreakdown> createState() => _WorkEarningsBreakdownState();
}

class _WorkEarningsBreakdownState extends State<WorkEarningsBreakdown> {
  bool init = true;
  late PayoutProvider payoutProvider;
  late LanguageProvider languageProvider;
  late CurrentPeriodProvider currentPeriodProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  /// Get daily earnings amount from earnings model
  double? get dailyEarnings {
    return payoutProvider.earnings?.earning;
  }

  /// Get monthly bonus amount from earnings model
  double? get monthlyBonus {
    return payoutProvider.earnings?.totalIncentive;
  }

  /// Get customer tips amount from earnings model
  double? get customerTips {
    return payoutProvider.earnings?.customerTipsEarning;
  }

  /// Get taxes amount from earnings model
  double? get taxes {
    return payoutProvider.earnings?.tds?.amount ??
        payoutProvider.earnings?.taxes;
  }

  /// Get loan amount from earnings model
  double? get loanAmount {
    return payoutProvider.earnings?.loanAmount;
  }

  /// Get total earnings amount from earnings model
  double? get totalEarnings {
    return payoutProvider.earnings?.earningDetails?.total;
  }

  /// Get deductions list from earnings model
  List<EarningsDeduction>? get deductions {
    return payoutProvider.earnings?.deductions;
  }

  /// Get net earnings amount from earnings model
  double? get netEarnings {
    return payoutProvider.earnings?.netEarnings;
  }

  /// Get additional payout items from earnings model
  List<AdditionalPayout>? get additionalPayouts {
    return payoutProvider.earnings?.additionalPayouts;
  }

  /// Get current period month name for display
  String get periodMonth {
    return DateFormat('MMMM').format(currentPeriodProvider.monthStartDate);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.n0,
        border:
            Border.all(color: const Color(0xff0C0C0D).withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getMessage(
                        'work_earnings_breakdown',
                        'Work Earnings Breakdown',
                      ),
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xff40515B),
                              ),
                    ),
                    SizedBox(height: 12.h),
                    Divider(
                      height: 1.h,
                      color: const Color(0xffD0D0D0),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // Earnings items section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Daily Earnings
                    if (dailyEarnings != null && dailyEarnings! >= 0)
                      _buildEarningItem(
                        title: languageProvider.getMessage(
                          'daily_earnings',
                          'Daily Earnings',
                        ),
                        amount: dailyEarnings!,
                        showArrow: true,
                        onTap: () {
                          Navigator.pushNamed(
                              context, DailyEarningsList.routeName);
                        },
                      ),
                    // Monthly Bonus
                    if (monthlyBonus != null && monthlyBonus! >= 0)
                      _buildEarningItem(
                        title: languageProvider.getMessage(
                          'monthly_bonus',
                          'Monthly Bonus',
                        ),
                        amount: monthlyBonus!,
                        showArrow: true,
                        onTap: () {
                          Navigator.pushNamed(context, BonusHome.routeName);
                        },
                      ),
                    // Additional payouts
                    if (additionalPayouts != null &&
                        additionalPayouts!.isNotEmpty)
                      ...additionalPayouts!.map(
                        (item) => AdditionalPayoutItem(payout: item),
                      ),
                    // Customer Tips
                    if (customerTips != null && customerTips! > 0)
                      _buildEarningItem(
                        title: languageProvider.getMessage(
                          'customer_tips',
                          'Customer Tips',
                        ),
                        amount: customerTips!,
                        showArrow: true,
                        onTap: () {
                          Navigator.pushNamed(
                              context, TipsInfoScreen.routeName);
                        },
                      ),

                    // Loan EMI Deduction
                    if (loanAmount != null && loanAmount != 0)
                      _LoanEmiItem(
                        amount: loanAmount!.abs(),
                        languageProvider: languageProvider,
                      ),

                    // Income Tax
                    if (taxes != null && taxes! >= 0)
                      _buildTaxItem(
                        title: languageProvider.getMessage(
                              'income_tax',
                              'Income Tax',
                            ) +
                            (payoutProvider.earnings?.tds?.interestRate != null
                                ? ' (${payoutProvider.earnings?.tds?.interestRate}%)'
                                : ''),
                        amount: taxes!,
                        showInfo: true,
                        infoText: payoutProvider.earnings?.tds?.tooltip ?? '',
                        subtitle: payoutProvider.earnings?.tds?.subtitle,
                      ),

                    // Divider
                    if (totalEarnings != null ||
                        (deductions != null && deductions!.isNotEmpty))
                      Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: Divider(
                          height: 1.h,
                          color: const Color(0xffD0D0D0),
                        ),
                      ),
                    // Total Earnings
                    if (totalEarnings != null)
                      _buildTotalEarningsItem(
                        title: languageProvider.getMessage(
                          'total_earnings',
                          'Total Earnings',
                        ),
                        amount: totalEarnings!,
                      ),
                    // Deductions
                    if (deductions != null && deductions!.isNotEmpty)
                      ...deductions!.map((deduction) {
                        return Column(
                          children: [
                            _buildDeductionItemWithSubtitle(
                              title:
                                  deduction.description ?? deduction.key ?? '',
                              amount: deduction.amount ?? 0,
                              subtitle: deduction.subtitle,
                              showInfo: true,
                              infoText: deduction.tooltip ?? '',
                            ),
                          ],
                        );
                      }),
                    // Divider before net earnings
                    Divider(
                      height: 1.h,
                      color: const Color(0xffD0D0D0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Net Earnings (highlighted)
          if (netEarnings != null)
            Container(
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: const Color(0xffEAFAF1),
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.r),
                    bottomRight: Radius.circular(8.r)),
              ),
              child: _buildNetEarningsItem(
                title: '$periodMonth ${languageProvider.getMessage(
                  'net_earnings',
                  'Net Earnings',
                )}',
                amount: netEarnings!,
              ),
            ),
        ],
      ),
    );
  }

  /// Build an earning item row with title, amount, and optional arrow icon
  Widget _buildEarningItem({
    required String title,
    required double amount,
    bool showArrow = false,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showArrow && onTap != null)
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.n70,
                          ),
                    ),
                    SizedBox(width: 4.w),
                    SvgPicture.asset(AssetConstants.navigateChevronRight,
                        width: 15.w, height: 15.h),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.n70,
                      ),
                ),
              ],
            ),
          Text(
            '+ ${formatIndianCurrency2(amount)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.n70,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxItem({
    required String title,
    required double amount,
    bool showInfo = false,
    String? infoText,
    Map<String, dynamic>? subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.n70,
                        ),
                  ),
                  if (showInfo) SizedBox(width: 4.w),
                  if (showInfo)
                    Tooltip(
                      richMessage: TextSpan(
                        text: languageProvider.getMessage(
                            infoText ?? '', infoText ?? ''),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.n0,
                            ),
                      ),
                      // message: "infoText",
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 10.w,
                      ),
                      // margin: EdgeInsets.only(left: 12.r, right: 79.r),
                      showDuration: const Duration(seconds: 3),
                      triggerMode: TooltipTriggerMode.tap,
                      preferBelow: true,
                      child: SvgPicture.asset(AssetConstants.tooltip,
                          width: 15.w, height: 15.h),
                    ),
                ],
              ),
              Text(
                '- ${formatIndianCurrency2(amount)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.n70,
                    ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            // SizedBox(height: 2.h),
            CustomText(
              textData: subtitle,
            ),
          ]
        ],
      ),
    );
  }

  /// Build a deduction item with subtitle
  Widget _buildDeductionItemWithSubtitle({
    required String title,
    required int amount,
    String? subtitle,
    bool showInfo = false,
    String? infoText,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                AssetConstants.uniformSet,
                width: 16.w,
                height: 16.h,
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.n90,
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
              if (showInfo && infoText != null) SizedBox(width: 4.w),
              if (showInfo && infoText != null)
                Tooltip(
                  richMessage: TextSpan(
                    text: languageProvider.getMessage(infoText, infoText),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.n0,
                        ),
                  ),
                  // message: "infoText",
                  padding: EdgeInsets.symmetric(
                    vertical: 12.h,
                    horizontal: 10.w,
                  ),
                  // margin: EdgeInsets.only(left: 12.r, right: 79.r),
                  showDuration: const Duration(seconds: 3),
                  triggerMode: TooltipTriggerMode.tap,
                  preferBelow: true,
                  child: SvgPicture.asset(AssetConstants.tooltip,
                      width: 15.w, height: 15.h),
                ),
            ],
          ),
          Text(
            '- ${formatIndianCurrency(amount)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.n70,
                ),
          ),
        ],
      ),
    );
  }

  /// Build total earnings item with rupee icon
  Widget _buildTotalEarningsItem({
    required String title,
    required double amount,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                AssetConstants.rupeeCoinOutlined,
                width: 16.w,
                height: 16.h,
              ),
              SizedBox(width: 8.w),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.n90,
                    ),
              ),
            ],
          ),
          Text(
            formatIndianCurrency2(amount),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.n90,
                ),
          ),
        ],
      ),
    );
  }

  /// Build net earnings item with money bag icon and green highlight
  Widget _buildNetEarningsItem({
    required String title,
    required double amount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SvgPicture.asset(AssetConstants.totalAmount,
                width: 16.w, height: 16.h),
            SizedBox(width: 8.w),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.n90,
                  ),
            ),
          ],
        ),
        Text(
          formatIndianCurrency2(amount),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.g40,
              ),
        ),
      ],
    );
  }
}

class _LoanEmiItem extends StatelessWidget {
  final double amount;
  final LanguageProvider languageProvider;

  const _LoanEmiItem({
    required this.amount,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                languageProvider.getMessage(
                  'loan_emi',
                  'Loan EMI',
                ),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.n70,
                    ),
              ),
              SizedBox(width: 4.w),
              Tooltip(
                richMessage: TextSpan(
                  text: languageProvider.getMessage(
                    'loan_emi_tooltip',
                    'This is the EMI amount for the loan you have taken.',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.n0,
                      ),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: 12.h,
                  horizontal: 10.w,
                ),
                showDuration: const Duration(seconds: 3),
                triggerMode: TooltipTriggerMode.tap,
                preferBelow: true,
                child: SvgPicture.asset(
                  AssetConstants.tooltip,
                  width: 15.w,
                  height: 15.h,
                ),
              ),
            ],
          ),
          Text(
            '- ${formatIndianCurrency2(amount)}',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 16.sp,
                  color: AppColors.n70,
                ),
          ),
        ],
      ),
    );
  }
}
