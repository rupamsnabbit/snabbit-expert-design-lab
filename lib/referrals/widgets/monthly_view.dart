import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/payout/early_payouts/early_payouts_screen.dart';
import 'package:snabbit_runner/pages/payout/transaction_history.dart';
import 'package:snabbit_runner/models/payout_home_assets.dart';
import 'package:snabbit_runner/pages/referral_home.dart';
import 'package:snabbit_runner/payout/widgets/referral_payout_breakdown.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/referrals/pages/wallet.dart';
import 'package:snabbit_runner/referrals/services/referral_http.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/payout/navigation_list_tile.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/referral.dart';
import '../../widgets/referral_progress_steps.dart';
import 'monthly_earnings.dart';
import 'referral_status_view.dart';

class MonthlyView extends StatefulWidget {
  final bool canNavigateToReferrals;
  const MonthlyView({
    super.key,
    this.canNavigateToReferrals = false,
  });

  @override
  State<MonthlyView> createState() => _MonthlyViewState();
}

class _MonthlyViewState extends State<MonthlyView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late ReferralDataProvider referralDataProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  late PayoutProvider payoutProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  bool get isMonthlyEmptyView {
    return referralDataProvider.monthlyData?.referrals?.isEmpty ?? true;
  }

  PayoutHomeAssets? get assets {
    return payoutProvider.earnings?.assets;
  }

  void onTapCurrentReferral(RunnerReferral currentReferral) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: 0.7.sh,
      ),
      builder: (_) {
        return CommonBottomSheetSetup(
          child: ReferralProgressSteps(
            currentReferral: currentReferral,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!referralDataProvider.loading)
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMonthlyEmptyView) ...[
                  if (widget.canNavigateToReferrals) ...[
                    ReferralPayoutBreakdown(),
                    NavigationListTile(
                      titleKey: "view_referral_details",
                      titleDefaultValue: "View Referral Details",
                      icon: assets?.viewReferralDetails?.icon,
                      backgroundImage:
                          assets?.viewReferralDetails?.backgroundImage,
                      onTap: () {
                        Navigator.pushNamed(context, WalletHome.routeName);
                      },
                    ),
                  ] else
                    const MonthlyEarnings(),
                  SizedBox(height: 20.h),
                  Text(
                    languageProvider.getMessage(
                      "your_referrals",
                      "Your Referrals",
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: AppColors.n90, fontSize: 16.sp),
                  ),
                ],
                SizedBox(height: 16.h),
                if (isMonthlyEmptyView)
                  EmptyStateView(
                    languageProvider: languageProvider,
                  )
                else
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    // Prevents independent scrolling
                    shrinkWrap: true,
                    // Ensures the ListView takes only required space
                    itemCount:
                        referralDataProvider.monthlyData!.referrals!.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      RunnerReferral currentReferral =
                          referralDataProvider.monthlyData!.referrals![index];
                      return GestureDetector(
                        onTap: () {
                          onTapCurrentReferral(currentReferral);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.n40),
                            color: AppColors.n0,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          padding: EdgeInsets.all(12.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  RemoteImageHandler(
                                    imageUrl: currentReferral.image ?? "",
                                    height: 36.r,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentReferral.name ?? "",
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: const Color(0xff40515B),
                                              ),
                                        ),
                                        if (currentReferral.phone != null)
                                          Padding(
                                            padding: EdgeInsets.only(top: 4.h),
                                            child: Text(
                                              currentReferral.phone ?? "",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 11.sp,
                                                    color:
                                                        const Color(0xff40515B),
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  RunnerReferralStatusWidget(
                                    currentReferral: currentReferral,
                                  ),
                                  SizedBox(width: 10.w),
                                  Icon(
                                    Icons.chevron_right,
                                    color: const Color(0xFF525871),
                                    size: 24.sp,
                                  ),
                                ],
                              ),
                              ...currentReferral.referralSteps
                                  .where((e) =>
                                      (e.amount ?? 0) > 0 &&
                                      ReferralStepStatus.completed ==
                                          e.referralStepStatus)
                                  .map((e) {
                                return Container(
                                  width: 1.sw,
                                  height: 22.h,
                                  margin: EdgeInsets.only(top: 12.w),
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 6.w),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(1000.r),
                                    color: e.shiftType==ReferralShiftType.shortShift? Color(0xffC25BBE):Color(0xFF656BC6)
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      RemoteImageHandler(
                                        imageUrl:
                                            "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/referrals/rupee_coin.png",
                                        height: 23.h,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: CustomText(
                                          textData: e.earningText,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        "+₹${e.amount}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.n0),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 8.h,
                                ),
                                child: Divider(
                                  color: AppColors.n20,
                                  height: 1.h,
                                ),
                              ),
                              if (![
                                ReferralStatus.completed,
                                ReferralStatus.paid,
                                ReferralStatus.failed,
                                ReferralStatus.didNotJoin,
                                ReferralStatus.droppedOut
                              ].contains(currentReferral.statusData?.status))
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 37.h,
                                        child: OutlinedButton(
                                          onPressed: () async {
                                            final response =
                                                await ReferralHttp.remind(
                                                    data: {
                                                  "referrals": [
                                                    {
                                                      "referral_name":
                                                          currentReferral.name,
                                                      "referral_phone_number":
                                                          currentReferral.phone,
                                                    },
                                                  ]
                                                });
                                            if (context.mounted) {
                                              showSnackbar(
                                                  context, "Reminder sent");
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.n90,
                                            side: const BorderSide(
                                                color: AppColors.n40),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16.w),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons
                                                  .notifications_active_outlined),
                                              SizedBox(width: 4.w),
                                              Text(
                                                languageProvider.getMessage(
                                                  'remind',
                                                  'Remind',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: SizedBox(
                                        height: 37.h,
                                        child: OutlinedButton(
                                          onPressed: () async {
                                            final phone = currentReferral.phone ?? '';
                                            if(phone.trim().isNotEmpty) {
                                              await CallUtils
                                                  .handleCallInitiation(
                                                phoneNumber:
                                                currentReferral.phone ??
                                                    '',
                                                callSourceLabel: "MONTHLY_REFERRAL_VIEW",
                                                context: context,
                                              );
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.n90,
                                            side: const BorderSide(
                                                color: AppColors.n40),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16.w),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.call),
                                              SizedBox(width: 4.w),
                                              Text(
                                                languageProvider.getMessage(
                                                  'call',
                                                  'Call',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => Container(
                      height: 8.h,
                    ),
                  ),
              ],
            ),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          ),
      ],
    );
  }
}

///[EmptyStateView] will return the placeholder to be displayed when there is no data available
///which will show three items by default if [emptyItemsCount] is null
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    this.emptyItemsCount,
    required this.languageProvider,
  });

  ///[emptyItemsCount] is the number of placeholder items that will be displayed
  final int? emptyItemsCount;
  final LanguageProvider languageProvider;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(
            emptyItemsCount ?? 3,
            (index) => Container(
              width: 143.65.w,
              padding: EdgeInsets.all(8.96.r),
              margin: EdgeInsets.only(bottom: 8.94.r),
              decoration: BoxDecoration(
                color: AppColors.n0,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEBEBEB),
                    //corresponding AppColor value not provided
                    spreadRadius: 0,
                    offset: Offset(-3.r, 3.r),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFEBEBEB),
                  //corresponding AppColor value not provided
                  width: 0.56.w,
                ),
                borderRadius: BorderRadius.circular(2.79.r),
              ),
              child: Row(
                children: [
                  Container(
                    height: 21.8.h,
                    width: 19.56.w,
                    margin: EdgeInsets.only(right: 4.47.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBEBEB),
                      //corresponding AppColor value not provided
                      borderRadius: BorderRadius.circular(2.79.r),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 70.98.w,
                        height: 9.5.h,
                        margin: EdgeInsets.only(bottom: 2.79.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBEBEB),
                          //corresponding AppColor value not provided
                          borderRadius: BorderRadius.circular(2.79.r),
                        ),
                      ),
                      Container(
                        width: 38.57.w,
                        height: 9.5.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBEBEB),
                          //corresponding AppColor value not provided
                          borderRadius: BorderRadius.circular(2.79.r),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            languageProvider.getMessage(
              "yet_to_make_a_referral",
              "You are yet to make a referral",
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
