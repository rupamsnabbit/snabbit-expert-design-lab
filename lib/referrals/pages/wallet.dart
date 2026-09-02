import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/referrals/services/referral_http.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/constants.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

import '../models/wallet_data.dart';
import '../models/wallet_item.dart';
import '../providers/wallet_provider.dart';
import '../widgets/common_container.dart';

class WalletHome extends StatefulWidget {
  static const String routeName = "/wallet-home";

  const WalletHome({super.key});

  @override
  State<WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<WalletHome>
    with SingleTickerProviderStateMixin {
  bool init = true;
  late LanguageProvider languageProvider;
  late WalletProvider walletProvider;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      walletProvider = Provider.of<WalletProvider>(context, listen: true);
      Future(() {
        initProcess();
      });
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> initProcess() async {
    walletProvider.getWalletData();
  }

  WalletData? get data => walletProvider.walletData;

  List<WalletItem> get allItems => data?.items ?? [];

  List<WalletItem> get creditItems =>
      allItems.where((item) => item.type == WalletItemType.credit).toList();

  List<WalletItem> get debitItems =>
      allItems.where((item) => item.type == WalletItemType.debit).toList();

  Widget buildWalletItemsList(List<WalletItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40.r),
          child: Text(
            languageProvider.getMessage(
              'no_transactions',
              'No transactions found',
            ),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xff6D7783),
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, index) {
        final current = items[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9.r),
            border: Border.all(color: AppColors.n40),
          ),
          padding: EdgeInsets.all(12.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      languageProvider.getMessage(
                        current.type?.presentationKey ?? "",
                        current.type?.presentationKey ?? "",
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "${current.type == WalletItemType.debit ? "- " : ""}${formatIndianCurrency(
                      current.amount,
                    )}",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: current.type == WalletItemType.debit
                              ? AppColors.r40
                              : AppColors.g40,
                        ),
                  ),
                ],
              ),
              if (current.date != null)
                Padding(
                  padding: EdgeInsets.only(top: 5.h),
                  child: Text(
                    dateFormatVisual5.format(current.date!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xff6D7783),
                        ),
                  ),
                ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 16.h),
      itemCount: items.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
      backgroundColor: const Color(0xffF5F6F8),
      body: walletProvider.loading == true
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : data == null
              ? const Center(child: Text("Try again after some time"))
              : Padding(
                  padding: EdgeInsets.all(20.r),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ReferralCommonContainer(
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9.r),
                                  border: Border.all(color: AppColors.n40),
                                ),
                                padding: EdgeInsets.symmetric(
                                    vertical: 16.h, horizontal: 10.w),
                                child: Column(
                                  children: [
                                    Text(
                                      languageProvider.getMessage(
                                        'referral_payout',
                                        'Referral Payout',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xff40515B)),
                                    ),
                                    SizedBox(
                                      height: 12.h,
                                      width: 1.sw,
                                    ),
                                    Text(
                                      formatIndianCurrency(data!.amount),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayLarge
                                          ?.copyWith(
                                              fontSize: 32.sp,
                                              color: AppColors.g40),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(top: 8.h),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8.r),
                                          color: AppColors.y0,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 4.h,
                                          horizontal: 12.w,
                                        ),
                                        child: CustomText(
                                          textData: data?.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16.h),
                              SizedBox(
                                width: 1.sw,
                                child: GestureDetector(
                                  onTap: data?.canWithdraw != true
                                      ? () {
                                          showModalBottomSheet(
                                              context: context,
                                              builder: (_) {
                                                return CommonBottomSheetSetup(
                                                  child: Column(
                                                    children: [
                                                      SizedBox(height: 20.h),
                                                      Icon(
                                                        Icons.warning_rounded,
                                                        size: 50.sp,
                                                      ),
                                                      CustomText(
                                                        textData:
                                                            data?.denialMessage,
                                                      ),
                                                      SizedBox(height: 20.h),
                                                      SizedBox(
                                                        width: 1.sw,
                                                        child: ElevatedButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                          child: Text(
                                                            languageProvider
                                                                .getMessage(
                                                              'ok_got_it',
                                                              'Okay, got it',
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                );
                                              });
                                        }
                                      : null,
                                  child: ElevatedButton(
                                    onPressed: data?.canWithdraw == true
                                        ? () {
                                            showModalBottomSheet(
                                                context: context,
                                                builder: (_) {
                                                  return CommonBottomSheetSetup(
                                                    child: WithdrawalProgress(
                                                      amount: data?.amount,
                                                    ),
                                                  );
                                                }).then((_) {
                                              walletProvider.getWalletData();
                                            });
                                          }
                                        : null,
                                    child: Text(
                                      languageProvider.getMessage(
                                        'withdraw',
                                        'Withdraw',
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        ReferralCommonContainer(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      languageProvider.getMessage(
                                        'payout_history',
                                        'Payout History',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xff40515B)),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20.h),
                              if (allItems.isNotEmpty) ...[
                                TabBar(
                                  controller: _tabController,
                                  labelColor: AppColors.brand,
                                  unselectedLabelColor: AppColors.n60,
                                  labelStyle: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                  unselectedLabelStyle:
                                      Theme.of(context).textTheme.labelLarge,
                                  indicatorColor: AppColors.brand,
                                  indicatorWeight: 2.h,
                                  tabs: [
                                    Tab(
                                      text: languageProvider.getMessage(
                                        'all',
                                        'All',
                                      ),
                                    ),
                                    Tab(
                                      text: languageProvider.getMessage(
                                        'credited',
                                        'Credit',
                                      ),
                                    ),
                                    Tab(
                                      text: languageProvider.getMessage(
                                        'withdrawal',
                                        'Debit',
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20.h),
                                SizedBox(
                                  height: 400.h, // Fixed height for TabBarView
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      buildWalletItemsList(allItems),
                                      buildWalletItemsList(creditItems),
                                      buildWalletItemsList(debitItems),
                                    ],
                                  ),
                                ),
                              ] else
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(40.r),
                                    child: Text(
                                      languageProvider.getMessage(
                                        'no_transactions',
                                        'No transactions found',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: const Color(0xff6D7783),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class WithdrawalProgress extends StatefulWidget {
  final int? amount;

  const WithdrawalProgress({
    super.key,
    this.amount,
  });

  @override
  State<WithdrawalProgress> createState() => _WithdrawalProgressState();
}

class _WithdrawalProgressState extends State<WithdrawalProgress> {
  bool init = true;
  bool loading = false;
  late LanguageProvider languageProvider;
  bool isSuccess = false;
  bool isFailed = false;
  String? error;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  Future<void> withdraw() async {
    try {
      isFailed = false;
      final response = await ReferralHttp.withdrawWallet();
      if (response != null && response.statusCode == 200) {
        isSuccess = true;
        ClevertapSetup.logEvent(TrackingEvents.withdrawSuccess, {
          "type": "referral",
          "amount": widget.amount,
        });
      } else {
        isFailed = true;
        try {
          error =
              ResponseError.fromMap(response?.data).getFirstError()?.message;
        } catch (__) {}
        ClevertapSetup.logEvent(TrackingEvents.withdrawFailed, {
          "type": "referral",
          "amount": widget.amount,
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? SizedBox(
            height: 0.25.sh,
            child: const CupertinoActivityIndicator(),
          )
        : isSuccess
            ? Column(
                children: [
                  SizedBox(height: 43.h),
                  Container(
                    width: 81.r,
                    height: 81.r,
                    padding: EdgeInsets.all(15.r),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.g40,
                    ),
                    child: FittedBox(
                        child: Icon(
                      Icons.check_rounded,
                      size: 60.sp,
                      color: AppColors.n0,
                    )),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    languageProvider.getMessage(
                      'withdrawal_successful',
                      'Withdrawal Successful',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    languageProvider.getMessage(
                      'payout_processing',
                      'Your payout is being processed',
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: AppColors.n80, fontSize: 16.sp),
                  ),
                ],
              )
            : isFailed
                ? Column(
                    children: [
                      SizedBox(height: 43.h),
                      Container(
                        width: 81.r,
                        height: 81.r,
                        padding: EdgeInsets.all(15.r),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.r40,
                        ),
                        child: FittedBox(
                            child: Icon(
                          Icons.close_rounded,
                          size: 60.sp,
                          color: AppColors.n0,
                        )),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        languageProvider.getMessage(
                          'withdrawal_failed',
                          'Withdrawal Failed',
                        ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (error != null)
                        Text(
                          languageProvider.getMessage(
                            error!,
                            error!,
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(color: AppColors.n80, fontSize: 16.sp),
                        ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: 1.sw,
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              loading = true;
                            });
                            await withdraw();
                            setState(() {
                              loading = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.r40),
                          child: Text(
                            languageProvider.getMessage(
                              'try_again',
                              'Try Again',
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(height: 22.h),
                      Text(
                        languageProvider.getMessage(
                          'are_you_sure',
                          'Are you sure?',
                        ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      SizedBox(height: 20.h),
                      SizedBox(
                        width: 1.sw,
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              loading = true;
                            });
                            await withdraw();
                            setState(() {
                              loading = false;
                            });
                          },
                          child: Text(
                            languageProvider.getFormattedMessage(
                                'withdraw_amount', 'Withdraw ₹{{amount}}', {
                              'amount': widget.amount,
                            }),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      SizedBox(
                        width: 1.sw,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brand,
                            side: const BorderSide(color: AppColors.brand),
                          ),
                          child: Text(
                            languageProvider.getMessage(
                              'go_back',
                              'Go Back',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  );
  }
}
