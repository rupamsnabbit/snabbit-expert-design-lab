import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/payout/early_payouts/early_payouts_screen.dart';
import 'package:snabbit_runner/pages/payout/transaction_history.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:intl/intl.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

/// Widget to display payout breakdown including cash collected,
/// early payout, remaining payout, and net payout
class PayoutBreakdown extends StatefulWidget {
  const PayoutBreakdown({super.key});

  @override
  State<PayoutBreakdown> createState() => _PayoutBreakdownState();
}

class _PayoutBreakdownState extends State<PayoutBreakdown> {
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

  /// Get cash collected amount from earnings model
  double? get cashCollected {
    return payoutProvider.earnings?.cashCollected?.amount;
  }

  /// Get early payout amount from earnings model
  EarlyPayout? get earlyPayout {
    return payoutProvider.earnings?.earlyPayout;
  }

  RemainingPayout? get remainingPayoutDetails {
    return payoutProvider.earnings?.remainingPayout;
  }

  /// Get remaining payout amount from earnings model
  double get remainingPayoutAmount {
    return remainingPayoutDetails?.amount ?? 0;
  }

  /// Get remaining payout subtitle from earnings model
  String? get remainingPayoutSubtitle {
    return remainingPayoutDetails?.subtitle;
  }

  /// Get net payout amount from earnings model
  double? get netPayout {
    return payoutProvider.earnings?.netPayout;
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
        border: Border.all(color: const Color(0xff0C0C0D).withOpacity(0.1)),
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
                        'payout_breakdown',
                        'Payout Breakdown',
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
                // Payout items section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cash Collected
                    // if (cashCollected != null && cashCollected! > 0)
                    Flexible(
                      child: _buildPayoutItem(
                        icon: AssetConstants.cashCollectedSvg,
                        title: languageProvider.getMessage(
                          'cash_collected',
                          'Cash Collected',
                        ),
                        amount: cashCollected!,
                        isPositive: true,
                      ),
                    ),
                    // Early Payout
                    if (earlyPayout != null)
                      Flexible(
                        child: _buildPayoutItem(
                          icon: AssetConstants.casWithdrawnSvg,
                          title: languageProvider.getMessage(
                            'early_payout',
                            'Early Payout',
                          ),
                          amount: earlyPayout?.amount ?? 0,
                          isPositive: true,
                          showArrow: true,
                          onTap: () {
                            Navigator.pushNamed(
                                context, EarlyPayoutsScreen.routeName);
                          },
                        ),
                      ),
                    // Remaining Payout
                    if (remainingPayoutDetails != null &&
                        remainingPayoutDetails != null &&
                        remainingPayoutAmount > 0)
                      Flexible(
                        child: _buildPayoutItemWithSubtitle(
                          icon: AssetConstants.bank,
                          title:
                              languageProvider.getMessage(
                                remainingPayoutDetails?.title ?? 'remaining_payout',
                                'Remaining Payout',
                              ),
                          amount: remainingPayoutAmount,
                          subtitle: remainingPayoutSubtitle,
                          showArrow: true,
                          subtitleColor: remainingPayoutDetails?.subtitleColor,
                          subtitleShouldBlink:
                              remainingPayoutDetails?.shouldBlink ?? false,
                          onTap: () {
                            Navigator.pushNamed(
                                context, TransactionHistory.routeName);
                          },
                        ),
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
          // Net Payout (highlighted)
          if (netPayout != null)
            Container(
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: const Color(0xffEAFAF1),
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.r),
                    bottomRight: Radius.circular(8.r)),
              ),
              child: _buildNetPayoutItem(
                title: '$periodMonth ${languageProvider.getMessage(
                  'net_payout',
                  'Net Payout',
                )}',
                amount: netPayout!,
              ),
            ),
        ],
      ),
    );
  }

  /// Build a payout item row with icon, title, and amount
  Widget _buildPayoutItem({
    required String icon,
    required String title,
    required double amount,
    bool isPositive = true,
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
              SvgPicture.asset(icon, width: 16.w, height: 16.h),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.n90,
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
          )),
          Text(
            '${isPositive ? '+' : ''} ${formatIndianCurrency2(amount)}',
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

  /// Build a payout item with subtitle
  Widget _buildPayoutItemWithSubtitle({
    required String icon,
    required String title,
    required double amount,
    String? subtitle,
    bool showArrow = false,
    VoidCallback? onTap,
    Color? subtitleColor,
    bool subtitleShouldBlink = false,
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
              SvgPicture.asset(icon, width: 16.w, height: 16.h),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.n90,
                            ),
                      ),
                      if (showArrow) SizedBox(width: 8.w),
                      if (showArrow)
                        GestureDetector(
                            onTap: onTap,
                            child: SvgPicture.asset(
                                AssetConstants.navigateChevronRight,
                                width: 16.w,
                                height: 16.h)),
                    ],
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2.h),
                    if (subtitleShouldBlink)
                      BlinkingText(
                        text: subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor ?? AppColors.n70,
                            ),
                        duration: const Duration(milliseconds: 800),
                      )
                    else
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor ?? AppColors.n70,
                            ),
                      ),
                  ],
                ],
              ),
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

  /// Build net payout item with money bag icon and green highlight
  Widget _buildNetPayoutItem({
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

class BlinkingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration; // New property for controlling blink speed

  const BlinkingText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<BlinkingText> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<BlinkingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Initialize AnimationController
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration, // Use the provided duration
    )..repeat(
        reverse:
            true); // Start the animation and repeat it, reversing each time.

    // 2. Create an Animation<double> for the opacity (from 1.0 to 0.0)
    // The FadeTransition widget will use this to automatically go from 0.0 to 1.0
    // and back again due to the `repeat(reverse: true)` setting on the controller.
    _opacityAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the widget tree.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 3. Use FadeTransition to apply the opacity animation
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Text(
        widget.text,
        style: widget.style,
      ),
    );
  }
}
