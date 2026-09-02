import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/providers/referral.dart';
import 'package:snabbit_runner/referrals/pages/wallet.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:intl/intl.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

/// Widget to display referral payout breakdown including referral earnings,
/// income tax, and net referral payout
class ReferralPayoutBreakdown extends StatefulWidget {
  const ReferralPayoutBreakdown({super.key});

  @override
  State<ReferralPayoutBreakdown> createState() =>
      _ReferralPayoutBreakdownState();
}

class _ReferralPayoutBreakdownState extends State<ReferralPayoutBreakdown> {
  bool init = true;
  late ReferralDataProvider referralDataProvider;
  late PayoutProvider payoutProvider;
  late LanguageProvider languageProvider;
  late CurrentPeriodProvider currentPeriodProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  /// Get monthly data from referral provider
  MonthlyData? get monthlyData {
    return referralDataProvider.monthlyData;
  }

  /// Get referral earnings amount from monthly data
  double? get referralEarnings {
    return monthlyData?.totalEarnings;
  }

  /// Get tax amount from monthly data
  double? get taxAmount {
    return monthlyData?.taxAmount;
  }

  /// Get tax percentage from monthly data
  int? get taxPercentage {
    return monthlyData?.taxPercentage;
  }

  /// Get net referral payout amount from monthly data
  double? get netReferralPayout {
    return monthlyData?.dueAmount;
  }

  /// Get current period month name for display
  String get periodMonth {
    return DateFormat('MMMM').format(currentPeriodProvider.monthStartDate);
  }

  @override
  Widget build(BuildContext context) {
    if (monthlyData == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.n0,
        border:
            Border.all(color: const Color(0xff0C0C0D).withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      // padding: EdgeInsets.all(20.w),
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
                        'referral_payout_earnings',
                        'Referral Payout Earnings',
                      ),
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
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
                // Breakdown items section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Referral Earnings
                    _buildEarningItem(
                      title: languageProvider.getMessage(
                        'referral_earnings',
                        'Referral Earnings',
                      ),
                      amount: referralEarnings!,
                      showArrow: true,
                      onTap: () {
                        Navigator.pushNamed(context, WalletHome.routeName);
                      },
                    ),
                    // Income Tax
                    _buildTaxItem(
                      title: languageProvider.getFormattedMessage(
                        'income_tax_with_percentage',
                        'Income Tax {{percentage}}',
                        {
                          'percentage':
                              taxPercentage != null ? "($taxPercentage%)" : '',
                        },
                      ),
                      amount: taxAmount!,
                      showInfo: true,
                      tooltipMessage:
                          referralDataProvider.monthlyData?.taxTooltip ??
                              languageProvider.getMessage(
                                'referral_tax_tooltip',
                                'Upload PAN Card to reduce the tax',
                              ),
                      subtitle: referralDataProvider.monthlyData?.taxSubtitle,
                    ),
                    // Divider
                    Divider(
                      height: 1.h,
                      color: const Color(0xffD0D0D0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Net Referral Payout (highlighted)
          if (netReferralPayout != null)
            Container(
              // margin: EdgeInsets.only(top: 16.h),
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: const Color(0xffEAFAF1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8.r),
                  bottomRight: Radius.circular(8.r),
                ),
              ),
              child: _buildNetPayoutItem(
                title: '$periodMonth ${languageProvider.getMessage(
                  'net_referral_earnings',
                  'Net Referral Earnings',
                )}',
                amount: netReferralPayout!,
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
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.n70,
                        ),
                  ),
                ),
                if (showArrow) SizedBox(width: 8.w),
                if (showArrow)
                  GestureDetector(
                    onTap: onTap,
                    child: SvgPicture.asset(AssetConstants.navigateChevronRight,
                        width: 16.w, height: 16.h),
                  ),
              ],
            ),
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

  /// Build a tax item row with title, amount, info icon, and subtitle
  Widget _buildTaxItem({
    required String title,
    required double amount,
    bool showInfo = false,
    String? tooltipMessage,
    Map<String, dynamic>? subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.n70,
                            ),
                      ),
                    ),
                    if (showInfo) SizedBox(width: 4.w),
                    if (showInfo)
                      Tooltip(
                        decoration: const BoxDecoration(
                          color: AppColors.n80,
                        ),
                        richMessage: WidgetSpan(
                          child: Text(
                            languageProvider.getMessage(
                              'itr_tooltip',
                              'Refundable when income tax is filed during ITR',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: AppColors.n0),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: 12.h,
                          horizontal: 10.w,
                        ),
                        // margin: EdgeInsets.only(left: 12.r, right: 79.r),
                        showDuration: const Duration(seconds: 3),
                        triggerMode: TooltipTriggerMode.tap,
                        preferBelow: true,
                        child: SvgPicture.asset(AssetConstants.tooltip,
                            width: 16.r, height: 16.r),
                      ),
                  ],
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2.h),
                  // Upload PAN Card to reduce the tax text with bold PAN Card
                  CustomText(
                    textData: subtitle ??
                        {
                          'key': 'referral_tax_subtitle',
                          'text': 'Upload {{pan_card}} to reduce the tax',
                          'style': {
                            'font_size': 11,
                            'color': '#D14343',
                            'weight': 500,
                            'style': 'normal',
                          },
                          'data': [
                            {
                              'key': 'pan_card',
                              'text': 'PAN Card',
                              'style': {
                                'font_size': 11,
                                'color': '#D14343',
                                'weight': 700,
                                'style': 'normal',
                              },
                            },
                          ],
                        },
                  ),
                ]
              ],
            ),
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
    );
  }

  /// Build net payout item with money bag icon and green highlight
  Widget _buildNetPayoutItem({
    required String title,
    required double amount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(AssetConstants.totalAmount,
                    width: 16.w, height: 16.h),
                SizedBox(width: 8.w),
                Flexible(
                  child: FittedBox(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.n90,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
