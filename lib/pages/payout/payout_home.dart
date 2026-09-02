import 'package:dio/dio.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/widgets/generic_banner_widget.dart';
import 'package:snabbit_runner/models/banner_config.dart';
import 'package:snabbit_runner/models/payout_home_assets.dart';
import 'package:snabbit_runner/pages/payout/bonus_home.dart';
import 'package:snabbit_runner/pages/payout/daily_earnings_list.dart';
import 'package:snabbit_runner/pages/payout/payout_v2_handoff.dart';
import 'package:snabbit_runner/pages/payout/tips_info_screen.dart';
import 'package:snabbit_runner/pages/payout/transaction_history.dart';
import 'package:snabbit_runner/payout/widgets/other_pending_payout.dart';
import 'package:snabbit_runner/payout/widgets/payout_breakdown.dart';
import 'package:snabbit_runner/payout/widgets/work_earnings_breakdown.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/referral.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/referrals/widgets/monthly_view.dart';
import 'package:snabbit_runner/referrals/widgets/referral_header.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/payout_http.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_helper_utils.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/constants.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/pages/payout/early_payouts/early_payouts_screen.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/rate_card_utils.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/payout/bank_account_widget.dart';
import 'package:snabbit_runner/widgets/payout/navigation_list_tile.dart';
import 'package:snabbit_runner/widgets/payout/pan_card_widget.dart';
import 'package:snabbit_runner/widgets/pdf_view.dart';
import 'package:snabbit_runner/widgets/raise_dispute/raise_dispute_button.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/upload_documents/upload_pan_modal_sheet_v2.dart';

import '../../payout/bonus/widgets/festive_jackpot_banner.dart';
import '../../payout/widgets/adjustment_breakdown_view.dart';
import '../../payout/widgets/bank_view.dart';
import '../../payout/widgets/earnings_breakdown_view.dart';
import '../../payout/widgets/earnings_summary_view.dart';
import '../../payout/widgets/final_payout_view.dart';
import '../../payout/widgets/pan_view.dart';
import '../../providers/payout.dart';
import '../../utils/common_methods.dart';
import '../../widgets/common_bottomsheet_setup.dart';
import '../../widgets/payout/current_period_view.dart';
import '../../widgets/payout/jackpot.dart';
import '../../widgets/support_popup.dart';

/// Route arguments for [PayoutHome]. Pass via
/// `Navigator.pushNamed(PayoutHome.routeName, arguments: PayoutHomeArgs(...))`.
class PayoutHomeArgs {
  const PayoutHomeArgs({this.initialMonth, this.fromWebview = false});

  /// Month the screen should land on. Any day-of-month is accepted; only
  /// year+month are read. When `null`, defaults to the current month.
  final DateTime? initialMonth;

  /// `true` when the runner was pushed here by the v2 webview for a
  /// pre-optin month. Used by PayoutHome to decide whether a right-arrow
  /// tap that would land on an optin-or-later month should pop back to
  /// the webview instead of advancing natively.
  final bool fromWebview;
}

class PayoutHome extends StatefulWidget {
  static const String routeName = "/payout-home";

  const PayoutHome({super.key});

  @override
  State<PayoutHome> createState() => _PayoutHomeState();
}

//  check figma comments as well for old and new designs
class _PayoutHomeState extends State<PayoutHome> with TickerProviderStateMixin {
  bool init = true;
  bool loading = true;
  String? error;
  late UserProfileProvider userProfileProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  late PayoutProvider payoutProvider;
  late LanguageProvider languageProvider;
  late TabController _tabController;
  late ReferralDataProvider referralDataProvider;

  /// `true` when the runner was pushed here by the v2 webview for a
  /// pre-optin month. See [PayoutHomeArgs.fromWebview].
  bool _fromWebview = false;

  /// Hides the Work/Referral segmented control and the referral tab once the
  /// referrals webview migration is live — v2 surfaces referrals separately.
  bool get _showReferralTab => !RemoteConfigHelperUtils.isReferralsV2Enabled;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _showReferralTab ? 2 : 1, vsync: this);
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      currentPeriodProvider.reset();
      // Seed the period provider if the caller asked for a specific month
      // (e.g. web sends runner back to v1 earnings for a pre-optin month).
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs is PayoutHomeArgs) {
        _fromWebview = routeArgs.fromWebview;
        if (routeArgs.initialMonth != null) {
          currentPeriodProvider.updateCurrentDate(routeArgs.initialMonth!, notify: false);
        }
      }
      payoutProvider.reset();
      if (userProfileProvider
                  .user?.runnerAppConfig?.payoutConfig?.showDailyPayout ==
              true &&
          userProfileProvider
                  .user?.runnerAppConfig?.payoutConfig?.showMonthlyPayout ==
              true) {
      } else if (userProfileProvider
              .user?.runnerAppConfig?.payoutConfig?.showDailyPayout ==
          true) {
        payoutProvider.payoutPeriod = PayoutPeriod.daily;
      } else {
        payoutProvider.payoutPeriod = PayoutPeriod.monthly;
      }

      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      }).onError((e, __) {
        error = e.toString();
        setState(() {});
      });
    }
    super.didChangeDependencies();
  }

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

  PayoutHomeAssets? get assets {
    return payoutProvider.earnings?.assets;
  }

  /// Right-arrow intercept for the monthly period picker. When a v2 runner
  /// with a known opt-in month steps forward into v2 territory (the opt-in
  /// month or later) — which the native v1 screen doesn't serve — hands off
  /// to the v2 webview: pops back if the runner came from the webview,
  /// otherwise launches the v2 monthly payouts summary. Fires for native
  /// navigation too (not just from-webview). Returns `true` when handled,
  /// `false` to fall through to the default month-advance behavior.
  bool _maybeHandoffOnNextMonth() {
    if (payoutProvider.payoutPeriod != PayoutPeriod.monthly) return false;
    if (!userProfileProvider.isRateCardV2Effective) return false;
    final user = userProfileProvider.user;
    final current = currentPeriodProvider.monthStartDate;
    final target = DateTime(current.year, current.month + 1, 1);
    if (!isInRateCardV2Territory(target, user?.rateCardOptinMonth)) {
      return false;
    }
    if (!mounted) return false;
    handoffToV2MonthlyPayouts(context, fromWebview: _fromWebview);
    return true;
  }

  Future<void> initProcess() async {
    if (_showReferralTab) {
      referralDataProvider.getReferrals(queryParameters: {
        'from_date': dateFormat.format(currentPeriodProvider.monthStartDate),
        'to_date': dateFormat.format(currentPeriodProvider.monthEndDate),
      });
    }
    await callPayoutApi();
  }

  void _logWorkEvents() {
    ClevertapSetup.logEvent(TrackingEvents.earningPage, {
      "month": dateFormat.format(currentPeriodProvider.monthStartDate),
      "toggle": "work",
      "daily_earning": dailyEarnings,
      "monthly_bonus": monthlyBonus,
      "tips": customerTips,
      "income_tax": payoutProvider.earnings?.tds?.amount,
      "total_earnings": payoutProvider.earnings?.earningDetails?.total,
      "cash_collected": payoutProvider.earnings?.cashCollected?.amount,
      "early_payout": payoutProvider.earnings?.earlyPayout?.amount,
      "remaining_payout": payoutProvider.earnings?.remainingPayout?.amount,
      "net_payout": payoutProvider.earnings?.netPayout,
      "net_earnings": payoutProvider.earnings?.netEarnings,
    });
  }

  void _logReferralEvents() {
    ClevertapSetup.logEvent(TrackingEvents.earningPage, {
      "month": dateFormat.format(currentPeriodProvider.monthStartDate),
      "toggle": "referral",
      "referral_earning": payoutProvider.earnings?.referralEarnings,
      "income_tax": referralDataProvider.monthlyData?.taxAmount,
      'net_referral_earnings': referralDataProvider.monthlyData?.dueAmount,
    });
  }

  Future<void> callPayoutApi() async {
    try {
      Response? response = await PayoutHttp.getPayout(
        start: payoutProvider.payoutPeriod == PayoutPeriod.monthly
            ? currentPeriodProvider.monthStartDate
            : currentPeriodProvider.currentDate,
        end: payoutProvider.payoutPeriod == PayoutPeriod.monthly
            ? currentPeriodProvider.monthEndDate
            : currentPeriodProvider.currentDate,
      );
      if (response != null) {
        currentPeriodProvider.prevSelectedStartDate =
            currentPeriodProvider.monthStartDate;
        currentPeriodProvider.prevSelectedEndDate =
            currentPeriodProvider.monthEndDate;
        error = null;
        payoutProvider.setEarnings(response.data);
      } else {
        error = "Something went wrong";
      }
    } catch (e) {
      error = "Something went wrong";
    }
  }

  bool isLoading() {
    try {
      return loading || payoutProvider.loading;
    } catch (e) {
      return loading;
    }
  }

  void showModalBottomNeedHelp() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return const CommonBottomSheetSetup(
          child: SupportPopup(
            type: SupportType.PAYOUT,
          ),
        );
      },
    );
  }

  ServiceAssuranceBannerData? get serviceAssuranceBannerData {
    return payoutProvider.earnings?.serviceAssuranceBannerData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      // backgroundColor: Colors.white,
      appBar: AppBar(
        leading: InkWell(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.n80,
          ),
        ),
        elevation: 10.r,
        title: Text(
          "#${userProfileProvider.user?.id}",
          style: Theme.of(context).textTheme.labelLarge,
        ),
        actions: [
          ReportIssueButton(allowOverride: true),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 25.h, bottom: 20.h),
            child: CurrentPeriodView(
              viewType: payoutProvider.payoutPeriod,
              onChanged: () async {
                setState(() {
                  loading = true;
                });
                await initProcess();
                setState(() {
                  loading = false;
                });
              },
              onNextTapOverride: _maybeHandoffOnNextMonth,
            ),
          ),
          // Custom segmented control
          if (_showReferralTab)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Work button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_tabController.index != 0) {
                              _tabController.animateTo(0);
                            }
                            _logWorkEvents();
                          },
                          child: Container(
                            height: 32.h,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: _tabController.index == 0
                                  ? const Color(0xFF171717)
                                  : AppColors.n0,
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                            child: Center(
                              child: Text(
                                languageProvider.getMessage("work", "Work"),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      height: 16 / 12,
                                      letterSpacing: -0.02,
                                      color: _tabController.index == 0
                                          ? AppColors.n0
                                          : const Color(0xFF171717),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 21.w),
                      // Referral button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_tabController.index != 1) {
                              _tabController.animateTo(1);
                            }
                            _logReferralEvents();
                          },
                          child: Container(
                            height: 32.h,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: _tabController.index == 1
                                  ? const Color(0xFF171717)
                                  : AppColors.n0,
                              borderRadius: BorderRadius.circular(30.r),
                            ),
                            child: Center(
                              child: Text(
                                languageProvider.getMessage(
                                    "referral", "Referral"),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      height: 16 / 12,
                                      letterSpacing: -0.02,
                                      color: _tabController.index == 1
                                          ? AppColors.n0
                                          : const Color(0xFF171717),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (_showReferralTab) SizedBox(height: 20.h),
          // TabBarView content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // First tab - Earnings (original content)
                isLoading()
                    ? const CupertinoActivityIndicator()
                    : RefreshIndicator(
                        onRefresh: () async {
                          setState(() {
                            loading = true;
                          });
                          await callPayoutApi();
                          setState(() {
                            loading = false;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                const Jackpot(),
                                const FestiveJackpotBanner(),
                                if (error != null)
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          error ?? "Something went wrong",
                                        ),
                                        SizedBox(height: 12.h),
                                        ElevatedButton(
                                          onPressed: () async {
                                            setState(() {
                                              loading = true;
                                            });
                                            await callPayoutApi();
                                            setState(() {
                                              loading = false;
                                            });
                                          },
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Column(
                                    children: [
                                      // Container(
                                      //   alignment: Alignment.center,
                                      //   decoration: BoxDecoration(
                                      //     borderRadius:
                                      //         BorderRadius.circular(12.r),
                                      //     color: AppColors.n0,
                                      //     boxShadow: [
                                      //       BoxShadow(
                                      //         color: AppColors.n90
                                      //             .withOpacity(0.25),
                                      //         offset: const Offset(0, 1),
                                      //         blurRadius: 2.r,
                                      //         spreadRadius: 0,
                                      //       ),
                                      //     ],
                                      //   ),
                                      //   padding: EdgeInsets.symmetric(
                                      //       vertical: 20.h, horizontal: 16.w),
                                      //   child: Column(
                                      //     crossAxisAlignment:
                                      //         CrossAxisAlignment.start,
                                      //     children: [
                                      //       const FinalPayoutView(),
                                      //       SizedBox(height: 16.h),
                                      //       Text(
                                      //         languageProvider.getMessage(
                                      //             'payout_summary',
                                      //             'Payout Summary'),
                                      //         style: Theme.of(context)
                                      //             .textTheme
                                      //             .displayMedium
                                      //             ?.copyWith(
                                      //                 color: AppColors.n90,
                                      //                 fontSize: 16.sp),
                                      //       ),
                                      //       SizedBox(height: 16.h),
                                      //       const EarningsSummaryView(),
                                      //       Padding(
                                      //         padding: EdgeInsets.symmetric(
                                      //             vertical: 8.h),
                                      //         child: DottedLine(
                                      //           lineThickness: 1.h,
                                      //           dashLength: 2.w,
                                      //           dashGapLength: 3.w,
                                      //           dashColor: AppColors.n30,
                                      //         ),
                                      //       ),
                                      //       const AdjustmentSummaryView(),
                                      //     ],
                                      //   ),
                                      // ),
                                      // SizedBox(height: 20.h),
                                      // const EarningsBreakdownView(),
                                      // SizedBox(height: 20.h),
                                      // const AdjustmentBreakdownView(),
                                      // SizedBox(height: 20.h),
                                      if (payoutProvider
                                              .earnings?.isProcessing !=
                                          true) ...[
                                        const WorkEarningsBreakdown(),
                                        SizedBox(height: 20.h),
                                        const OtherPendingPayout(),
                                        SizedBox(height: 20.h),
                                        const PayoutBreakdown(),
                                      ],
                                      if (payoutProvider
                                              .earnings?.isProcessing ==
                                          true) ...[
                                        SizedBox(height: 20.h),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.n0,
                                            borderRadius:
                                                BorderRadius.circular(8.r),
                                            border: Border.all(
                                              color: Color(0x330C0C0D),
                                              width: 1,
                                            ),
                                          ),
                                          padding: EdgeInsets.all(20.r),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Text(
                                                payoutProvider.earnings!.banner!
                                                            .title !=
                                                        null
                                                    ? languageProvider.getMessage(
                                                        payoutProvider
                                                                .earnings!
                                                                .banner!
                                                                .title!
                                                                .key ??
                                                            "processing_earning_title",
                                                        payoutProvider
                                                                .earnings!
                                                                .banner!
                                                                .title!
                                                                .text ??
                                                            "Today's Earnings")
                                                    : languageProvider.getMessage(
                                                        "processing_earning_title",
                                                        "Today's Earnings"),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium
                                                    ?.copyWith(
                                                      color: Color(0xFF40515B),
                                                      fontSize: 16.sp,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              SizedBox(height: 4.h),
                                              Text(
                                                payoutProvider.earnings!.banner!
                                                            .subtitle !=
                                                        null
                                                    ? languageProvider.getMessage(
                                                        payoutProvider
                                                                .earnings!
                                                                .banner!
                                                                .subtitle!
                                                                .key ??
                                                            "processing_earning_body_text",
                                                        payoutProvider
                                                                .earnings!
                                                                .banner!
                                                                .subtitle!
                                                                .text ??
                                                            "Calculation is under processing... We will be update in next 48 hours")
                                                    : languageProvider.getMessage(
                                                        "processing_earning_body_text",
                                                        "Calculation is under processing..."
                                                            "We will be update in next 48 hours"),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: AppColors.n80,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                if (serviceAssuranceBannerData != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 20.h),
                                    child: GestureDetector(
                                      onTap:
                                          serviceAssuranceBannerData?.pdfUrl !=
                                                  null
                                              ? () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          PdfViewPage(
                                                        url:
                                                            serviceAssuranceBannerData
                                                                    ?.pdfUrl ??
                                                                "",
                                                      ),
                                                    ),
                                                  );
                                                }
                                              : null,
                                      child: RemoteImageHandler(
                                        imageUrl: serviceAssuranceBannerData
                                                ?.bannerImageUrl?.cdn ??
                                            "",
                                        // height: 100.h,
                                        errorWidget: const SizedBox(),
                                      ),
                                    ),
                                  ),

                                const GenericBannerWidget(
                                    placement: BannerPlacement.payout),

                                //Add here the navigation tiles
                                /*
                                View Daily earnings

View Monthly Bonus

View Customer Tips

View Transaction History

Withdraw Early Payout
                                */
                                if (payoutProvider.earnings?.isProcessing !=
                                    true) ...[
                                  if (dailyEarnings != null)
                                    NavigationListTile(
                                      titleKey: "view_daily_earnings",
                                      titleDefaultValue: "View Daily earnings",
                                      icon: assets?.viewDailyEarnings?.icon,
                                      backgroundImage: assets
                                          ?.viewDailyEarnings?.backgroundImage,
                                      onTap: () {
                                        Navigator.pushNamed(context,
                                            DailyEarningsList.routeName);
                                      },
                                    ),
                                  if (monthlyBonus != null)
                                    NavigationListTile(
                                      titleKey: "view_monthly_bonus",
                                      titleDefaultValue: "View Monthly Bonus",
                                      icon: assets?.viewMonthlyBonus?.icon,
                                      backgroundImage: assets
                                          ?.viewMonthlyBonus?.backgroundImage,
                                      onTap: () {
                                        Navigator.pushNamed(
                                            context, BonusHome.routeName);
                                      },
                                    ),
                                  NavigationListTile(
                                    titleKey: "view_customer_tips",
                                    titleDefaultValue: "View Customer Tips",
                                    icon: assets?.viewCustomerTips?.icon,
                                    backgroundImage: assets
                                        ?.viewCustomerTips?.backgroundImage,
                                    onTap: () {
                                      Navigator.pushNamed(
                                          context, TipsInfoScreen.routeName);
                                    },
                                  ),
                                  if ((userProfileProvider
                                          .user
                                          ?.runnerAppConfig
                                          ?.payoutConfig
                                          ?.showTransactionHistory ??
                                      false))
                                    NavigationListTile(
                                      titleKey: "view_transaction_history",
                                      titleDefaultValue:
                                          "View Transaction History",
                                      icon:
                                          assets?.viewTransactionHistory?.icon,
                                      backgroundImage: assets
                                          ?.viewTransactionHistory
                                          ?.backgroundImage,
                                      onTap: () {
                                        Navigator.pushNamed(context,
                                            TransactionHistory.routeName);
                                      },
                                    ),
                                  if ((userProfileProvider.user?.runnerAppConfig
                                          ?.payoutConfig?.showEarlyPayout ??
                                      false))
                                    NavigationListTile(
                                      titleKey: "withdraw_early_payout",
                                      titleDefaultValue:
                                          "Withdraw Early Payout",
                                      icon: assets?.withdrawEarlyPayout?.icon,
                                      backgroundImage: assets
                                          ?.withdrawEarlyPayout
                                          ?.backgroundImage,
                                      onTap: () {
                                        Navigator.pushNamed(context,
                                            EarlyPayoutsScreen.routeName);
                                      },
                                    ),
                                ],
                                Padding(
                                  padding: EdgeInsets.only(top: 20.h),
                                  child: BankAccountWidget(),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 20.h),
                                  child: PanCardWidget(),
                                ),
                                SizedBox(
                                  height: 24.h,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                // Second tab - Referral
                if (_showReferralTab)
                  RefreshIndicator(
                    onRefresh: () async {
                      referralDataProvider.getReferrals(queryParameters: {
                        'from_date': dateFormat
                            .format(currentPeriodProvider.monthStartDate),
                      'to_date':
                          dateFormat.format(currentPeriodProvider.monthEndDate),
                      });
                    },
                    child: const SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: ReferralHeaderView(source: 'payout_page'),
                          ),
                          MonthlyView(canNavigateToReferrals: true),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  String getPayoutDate() {
    return payoutProvider.earnings?.pendingPayment == true
        ? languageProvider.getMessage("salary_due", "To be paid on ")
        : languageProvider.getMessage("salary_paid", "Paid on ") +
            formatDateToDayMonth(payoutProvider.earnings?.payoutDate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
