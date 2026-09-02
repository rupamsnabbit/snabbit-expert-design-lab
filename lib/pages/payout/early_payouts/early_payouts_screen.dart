import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/early_payouts_model.dart';
import 'package:snabbit_runner/providers/early_payouts_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_bank_or_upi_details_screen.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/bottom_action_row.dart';
import 'package:snabbit_runner/widgets/payout/early_payout_requirements.dart';
import 'package:snabbit_runner/widgets/payout/payout_withdrawer.dart';
import 'package:snabbit_runner/widgets/raise_dispute/raise_dispute_button.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/pages/payout/early_payouts/early_payout_benefit_item.dart';
import 'package:flutter/cupertino.dart';

class EarlyPayoutsScreen extends StatefulWidget {
  static const String routeName = "/early-payouts";

  const EarlyPayoutsScreen({super.key});

  @override
  State<EarlyPayoutsScreen> createState() => _EarlyPayoutsScreenState();
}

class _EarlyPayoutsScreenState extends State<EarlyPayoutsScreen> {
  bool init = true;
  late EarlyPayoutsProvider _earlyPayoutsProvider;
  late LanguageProvider _languageProvider;
  late UserProfileProvider _userProfileProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      _earlyPayoutsProvider =
          Provider.of<EarlyPayoutsProvider>(context, listen: true);
      _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      _userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _earlyPayoutsProvider.fetchEarlyPayoutsData();
      });
      ClevertapSetup.logEvent(TrackingEvents.earlyPayout, {
        "pan_status": _userProfileProvider.user?.panCardUnavailable == null
            ? "null"
            : _userProfileProvider.user?.panAadharLinked == false
                ? "inoperative"
                : "operative",
        "bank_status": _userProfileProvider.user?.bankVerified == null
            ? "absent"
            : "present",
        "withdraw_amount":
            _earlyPayoutsProvider.earlyPayoutsData?.maxWithdrawableAmount,
        "withdraw_enabled": _earlyPayoutsProvider.isEligible,
      });
    }
    super.didChangeDependencies();
  }

  Widget _getIneligibilityWidget(IneligibilityReason reason) {
    switch (reason) {
      case IneligibilityReason.locked:
        return BottomActionRow(
          iconUrl: 'payouts/early_payouts/payout_lock.svg',
          text: _languageProvider.getMessage(
              'withdrawal_locked', 'Locked for you'),
          textColor: AppColors.n90,
        );

      case IneligibilityReason.addBankAccount:
        return BottomActionRow(
          text: _languageProvider.getMessage(
              'add_upi_bank_account_to_enable_withdrawal',
              '+ Add UPI / bank account to enable withdrawal'),
          onTap: () {
            Navigator.pushNamed(context, AddBankOrUpiDetailsScreen.routeName);
          },
        );

      case IneligibilityReason.inProgress:
        return BottomActionRow(
          text: _languageProvider.getFormattedMessage(
            'withdrawal_of_x_in_progress',
            'Withdrawal of {{amount}} in progress',
            {
              'amount': formatIndianCurrency(
                anyValueToInt(_earlyPayoutsProvider
                    .earlyPayoutsData?.currentWithdrawalAmount),
              )
            },
          ),
          textColor: const Color(0xFFD18700),
        );

      case IneligibilityReason.amountIneligible:
        return BottomActionRow(
          iconUrl: 'payouts/early_payouts/payout_lock.svg',
          text: _languageProvider.getMessage(
              'no_eligible_amount', 'No eligible amount to withdraw'),
          textColor: AppColors.n90,
        );

      case IneligibilityReason.addPan:
        return BottomActionRow(
          iconUrl: 'payouts/early_payouts/payout_lock.svg',
          text: _languageProvider.getMessage('upload_pan_to_enable_withdrawal',
              'Upload a valid PAN to enable withdrawal'),
          textColor: AppColors.n90,
        );

      case IneligibilityReason.dailyLimitReached:
        return BottomActionRow(
          iconUrl: 'payouts/early_payouts/payout_lock.svg',
          text: _languageProvider.getMessage('no_more_withdrawals_today',
              'No more withdrawals are allowed today'),
          textColor: AppColors.n90,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      persistentFooterButtons: _earlyPayoutsProvider.payoutDataError == null
          ? [
              SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_earlyPayoutsProvider.isEligible &&
                        _earlyPayoutsProvider.ineligibilityReason != null)
                      _getIneligibilityWidget(
                          _earlyPayoutsProvider.ineligibilityReason!),
                    SizedBox(
                      width: 1.sw,
                      child: ElevatedButton(
                        onPressed: _earlyPayoutsProvider.isEligible
                            ? () {
                                ClevertapSetup.logEvent(
                                    TrackingEvents.earlyPayoutWithdrawClicked, {
                                  "info": "Early Payout Withdraw Clicked",
                                });
                                showPayoutWithdrawer(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _earlyPayoutsProvider.isEligible
                              ? AppColors.brand
                              : AppColors.n40,
                          foregroundColor: _earlyPayoutsProvider.isEligible
                              ? AppColors.n0
                              : AppColors.n60,
                        ),
                        child: Text(_languageProvider.getMessage(
                            'withdraw', 'Withdraw')),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          : null,
      appBar: AppBar(
        elevation: 2,
        centerTitle: true,
        title: Text(
          _languageProvider.getMessage('early_payout', 'Early Payout'),
          style:
              Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14.sp),
        ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
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
            if (_userProfileProvider.user?.id != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  '#${_userProfileProvider.user!.id}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 14.sp,
                        color: Color(0xFF1D2129),
                      ),
                ),
              ),
          ],
        ),
        leadingWidth: _userProfileProvider.user?.id != null ? 100.0 : null,
        actions: [
          ReportIssueButton(allowOverride: true),
        ],
      ),
      body: SafeArea(
        child: Consumer<EarlyPayoutsProvider>(
          builder: (context, provider, child) {
            if (provider.loading) {
              return const Center(
                child: CupertinoActivityIndicator(),
              );
            }
            if (provider.payoutDataError != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: ${provider.payoutDataError}',
                      style: TextStyle(
                        color: AppColors.r50,
                        fontSize: 16.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () {
                        provider.fetchEarlyPayoutsData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: AppColors.n0,
                      ),
                      child:
                          Text(_languageProvider.getMessage('retry', 'Retry')),
                    ),
                  ],
                ),
              );
            }

            final payoutsData = provider.earlyPayoutsData;
            if (payoutsData == null) {
              return Center(
                child: Text(_languageProvider.getMessage(
                    'no_data_available', 'No data available')),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      RemoteImageHandler(
                        imageUrl: payoutsData.eligible ?? false
                            ? "payouts/early_payouts/enabled_payout_bg.png".cdn
                            : "payouts/early_payouts/disabled_payout_bg.png"
                                .cdn,
                        height: 148.h,
                        width: double.infinity,
                      ),
                      SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 40.h),
                                Text(
                                  _languageProvider.getMessage(
                                      'early_payout_title', 'Get Paid Early'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.n90),
                                ),
                                SizedBox(height: 8.h),
                                // Description
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 0.59.sw,
                                  ),
                                  child: Text(
                                    _languageProvider.getMessage(
                                        'early_payout_subtitle',
                                        'Withdraw part of your earnings anytime before payday.'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontSize: 14.sp,
                                          color: AppColors.n70,
                                        ),
                                  ),
                                ),
                                SizedBox(height: 24.h),
                                // Withdraw up-to section
                                if (payoutsData.maxWithdrawableAmount !=
                                    null) ...[
                                  Text(
                                    _languageProvider.getMessage(
                                        'withdraw_upto', 'Withdraw up-to'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
                                        ?.copyWith(color: AppColors.n90),
                                  ),
                                  Text(
                                    formatIndianCurrency(
                                        payoutsData.maxWithdrawableAmount),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
                                        ?.copyWith(
                                          fontSize: 40.sp,
                                          color: (_earlyPayoutsProvider
                                                          .ineligibilityReason ==
                                                      IneligibilityReason
                                                          .locked ||
                                                  _earlyPayoutsProvider
                                                          .ineligibilityReason ==
                                                      IneligibilityReason
                                                          .addBankAccount)
                                              ? AppColors.n60
                                              : AppColors.g40,
                                        ),
                                  ),
                                ],
                                SizedBox(height: 18.h),
                                Container(
                                  height: 1.h,
                                  color: AppColors.n40,
                                ),
                                SizedBox(height: 20.h),
                                // Benefits Section
                                if (payoutsData.benefits != null) ...[
                                  Text(
                                    _languageProvider.getMessage(
                                        'early_payout_benefits',
                                        'Early Payout Benefits'),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.n90,
                                      letterSpacing: -0.28,
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  // Benefits Cards
                                  GridView.count(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 4.h,
                                    crossAxisSpacing: 4.w,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children:
                                        payoutsData.benefits!.map((benefit) {
                                      return EarlyPayoutBenefitItem(
                                          benefit: benefit);
                                    }).toList(),
                                  ),
                                ],
                                Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 32.5.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xffFFFEFA),
                                      borderRadius: BorderRadius.circular(12.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          spreadRadius: 0,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _languageProvider.getMessage(
                                          'early_payout_info_message',
                                          'Amount will be auto deducted from next payout'),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: AppColors.n80,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),

                                SizedBox(height: 24.h),

                                // View details button
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      showEarlyPayoutRequirements(context);
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        border:
                                            Border.all(color: AppColors.brand),
                                        borderRadius:
                                            BorderRadius.circular(12.r),
                                      ),
                                      child: Text(
                                        _languageProvider.getMessage(
                                            'view_details', 'View details'),
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: AppColors.brand,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 32.h),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom spacing for home indicator
                SizedBox(height: 21.h),
              ],
            );
          },
        ),
      ),
    );
  }
}
