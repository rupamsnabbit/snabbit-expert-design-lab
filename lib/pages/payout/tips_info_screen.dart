import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/constants/tip_strings.dart';
import 'package:snabbit_runner/pages/raise_dispute/new_issue_reporter.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/tips_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/rate_card_utils.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/raise_dispute/raise_dispute_button.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Main page for Tips Info Screen
class TipsInfoScreen extends StatefulWidget {
  static const String routeName = "/tips-info";

  const TipsInfoScreen({super.key});

  @override
  State<TipsInfoScreen> createState() => _TipsInfoScreenState();
}

class _TipsInfoScreenState extends State<TipsInfoScreen> {
  late TipsProvider tipsProvider;
  late CurrentPeriodProvider periodProvider;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      tipsProvider = Provider.of<TipsProvider>(context, listen: true);
      periodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      Future(() {
        initProcess();
      });
    }
  }

  void initProcess() {
    tipsProvider.fetchMonthlyTips(
        periodProvider.monthStartDate, periodProvider.monthEndDate);
  }

  bool get isNextDisabled {
    final now = DateTime.now();
    final currentMonth = periodProvider.monthStartDate;
    // Disable if current month is same as or later than today's month
    return currentMonth.year >= now.year && currentMonth.month >= now.month;
  }

  /// Chevron-right intercept. For a v2 runner with a known opt-in month,
  /// blocks stepping forward from a pre-opt-in (v1) month into opt-in-or-
  /// later (v2) territory — the native v1 Tips screen doesn't serve those
  /// months (the new Payouts does). Shows a toast and returns `true`
  /// (handled) so the period view skips its default advance. Returns
  /// `false` otherwise, letting normal month navigation proceed.
  bool _maybeBlockNextMonth() {
    if (!userProfileProvider.isRateCardV2Effective) return false;
    final user = userProfileProvider.user;
    final current = periodProvider.monthStartDate;
    final nextMonth = DateTime(current.year, current.month + 1, 1);
    if (!isInRateCardV2Territory(nextMonth, user?.rateCardOptinMonth)) {
      return false;
    }
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          languageProvider.getMessage(
            'tips_v2_month_unavailable',
            "Tips for this month are in the new Payouts",
          ),
        ),
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.n20,
      appBar: CommonAppBar(
        centerTitle: false,
        elevation: 10.r,
        title: Text(
          languageProvider.getMessage('tips', TipStrings.tips),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        actions: [
          ReportIssueButton(allowOverride: true),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 24.h),
            child: CurrentPeriodView(
              isNextDisabled: isNextDisabled,
              viewType: PayoutPeriod.monthly,
              onNextTapOverride: _maybeBlockNextMonth,
              onChanged: () {
                tipsProvider.fetchMonthlyTips(
                    periodProvider.monthStartDate, periodProvider.monthEndDate);
              },
            ),
          ),

          SizedBox(height: 12.h),

          // Main content - scrollable
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await tipsProvider.fetchMonthlyTips(
                    periodProvider.monthStartDate, periodProvider.monthEndDate);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                    top: 12.h, bottom: 24.h, left: 16.w, right: 16.w),
                child: tipsProvider.loading
                    ? SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child:
                            const Center(child: CupertinoActivityIndicator()),
                      )
                    : tipsProvider.error != null
                        ? SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: _buildErrorSection(),
                          )
                        : _buildContentSection(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${languageProvider.getMessage('error', TipStrings.error)}: ${tipsProvider.error}",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.r50,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              tipsProvider.fetchMonthlyTips(
                  periodProvider.monthStartDate, periodProvider.monthEndDate);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text(
              languageProvider.getMessage('retry', TipStrings.retry),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total tips card
        _buildTotalTipsCard(),

        SizedBox(height: 24.h),

        // How to earn tips section
        _buildHowToEarnTipsSection(),
      ],
    );
  }

  Widget _buildTotalTipsCard() {
    final bool hasNoTips = tipsProvider.totalTips == 0;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFEDCB),
            Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative coins: explicit size + slight scale so CDN art (often padded)
          // fills edge-to-edge inside the clipped card; RemoteImageHandler needs
          // width/height or CachedNetworkImage can letterbox.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double backgroundBleedScale = 1.14;
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Transform.scale(
                  alignment: Alignment.topCenter,
                  scale: backgroundBleedScale,
                  child: RemoteImageHandler(
                    imageUrl: AssetConstants.tipBackground.cdn,
                    width: w / backgroundBleedScale,
                    height: h / backgroundBleedScale,
                    fit: BoxFit.cover,
                    animate: false,
                  ),
                );
              },
            ),
          ),

          // Main content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 12.h),

              // Large coin icon with stars
              RemoteImageHandler(
                imageUrl: AssetConstants.tipShowcase.cdn,
                height: 80.h,
                width: 100.w,
                fit: BoxFit.contain,
                animate: false,
              ),
              SizedBox(height: 12.h),
              Text(
                languageProvider.getMessage('customer_tips', TipStrings.customerTips),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF101840),
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                    ),
              ),
              SizedBox(height: 4.h),
              Text(
                formatIndianCurrency(tipsProvider.totalTips),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: hasNoTips
                          ? const Color(0xFFD0D0D0)
                          : const Color(0xff26A179),
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: 24.h),

              // Divider
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                height: 2.h,
                color: const Color(0xFFF3F4F6),
              ),
              SizedBox(height: 14.h),

              // Warning row with icon
              Padding(
                padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
                child: Row(
                  children: [
                    Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDBDB),
                        borderRadius: BorderRadius.circular(7.2.r),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          AssetConstants.tipWarningIconSvg,
                          width: 24.r,
                          height: 24.r,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        languageProvider.getMessage('tips_warning_message',
                            TipStrings.tipsWarningMessage),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF101840),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              height: 16 / 12,
                              letterSpacing: -0.12,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowToEarnTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getMessage('how_to_earn_tips', TipStrings.howToEarnTips),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.black.withOpacity(0.5),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                height: 16 / 12,
                letterSpacing: -0.24,
              ),
        ),
        SizedBox(height: 16.h),

        // Row 1
        Row(
          children: [
            Expanded(
              child: _buildTipCard(
                imageUrl: AssetConstants.tipsGreetCustomer.cdn,
                bgColor: const Color(0xFFE9DDFF),
                label: languageProvider.getMessage(
                    'tip_greet_customer', TipStrings.greetCustomer),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildTipCard(
                imageUrl: AssetConstants.tipWorkDiligently.cdn,
                bgColor: const Color(0xFFE9DDFF),
                label: languageProvider.getMessage('tip_work_diligently',
                    TipStrings.workDiligently),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        // Row 2
        Row(
          children: [
            SizedBox(width: 8.w),
            Expanded(
              child: _buildTipCard(
                imageUrl: AssetConstants.tipAskMore.cdn,
                bgColor: const Color(0xFFFBF2FB),
                label: languageProvider.getMessage('tip_ask_more',
                    TipStrings.askMore),
              ),
            ),
            Expanded(
              child: _buildTipCard(
                imageUrl: AssetConstants.tipFiveStar.cdn,
                bgColor: const Color(0xFFFCF6FC),
                label: languageProvider.getMessage(
                    'tip_five_star', TipStrings.fiveStar),
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildTipCard({
    required String imageUrl,
    required Color bgColor,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 100.r,
          height: 100.r,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: RemoteImageHandler(
            imageUrl: imageUrl,
            width: 100.r,
            height: 100.r,
            fit: BoxFit.cover,
            animate: false,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF101840),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                height: 14 / 12,
                letterSpacing: -0.12,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  _DottedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    this.dashWidth = 3.0,
    this.dashSpace = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = _dashPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(Path path, double dashWidth, double dashSpace) {
    final dashPath = Path();
    final pathMetrics = path.computeMetrics();

    for (final pathMetric in pathMetrics) {
      double distance = 0;
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    return dashPath;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
