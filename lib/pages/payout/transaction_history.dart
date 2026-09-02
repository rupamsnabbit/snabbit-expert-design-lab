import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/payout_history_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/payout/linked_bank_accounts.dart';
import 'package:snabbit_runner/widgets/payout/payout_history.dart';
import 'package:snabbit_runner/widgets/raise_dispute/raise_dispute_button.dart';

import '../../providers/language_provider.dart';

class TransactionHistory extends StatefulWidget {
  static const String routeName = "/transaction-history";

  const TransactionHistory({super.key});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late PayoutHistoryProvider payoutHistoryProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      payoutHistoryProvider =
          Provider.of<PayoutHistoryProvider>(context, listen: true);
      Future(() {
        if (payoutHistoryProvider.getFilteredTransactions().isEmpty) {
          payoutHistoryProvider.fetchPayoutHistory();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
          elevation: 0,
          title: FittedBox(
            child: Text(
              languageProvider.getMessage(
                  'transaction_history', "Transaction History"),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          centerTitle: true,
          leadingWidth: 120.w,
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
              if (userProfileProvider.user?.id != null)
                Flexible(
                  child: FittedBox(
                    child: Text(
                      '#${userProfileProvider.user!.id}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontSize: 14.sp,
                            color: Color(0xFF1D2129),
                          ),
                    ),
                  ),
                ),
            ],
          ),
          actionsPadding: EdgeInsets.only(left: 16.w),
          actions: const [
            ReportIssueButton(allowOverride: true),
          ]),
      body: init || payoutHistoryProvider.loading
          ? Center(child: const CupertinoActivityIndicator())
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 16.h),
                    LinkedBankAccounts(
                      bankAccounts: payoutHistoryProvider.bankAccounts,
                      upiAccounts: payoutHistoryProvider.upiAccounts,
                      emptyStateBankImage: payoutHistoryProvider
                              .payoutHistoryData
                              ?.assets
                              ?.bankInstitution
                              ?.cdn ??
                          '',
                      loading: payoutHistoryProvider.loading,
                      onBankAccountTap: (p0) {
                      },
                      onUpiAccountTap: (p0) {

                      },
                      showTailWidget: false,
                    ),
                    PayoutHistory(),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    payoutHistoryProvider.reset();
    super.dispose();
  }
}
