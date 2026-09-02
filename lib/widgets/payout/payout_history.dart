import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/payout/assets.dart';
import 'package:snabbit_runner/models/payout/transaction.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout_history_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/payout/transaction_card.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Widget to display payout history with filtering tabs and transaction list
class PayoutHistory extends StatefulWidget {
  const PayoutHistory({super.key});

  @override
  State<PayoutHistory> createState() => _PayoutHistoryState();
}

class _PayoutHistoryState extends State<PayoutHistory> {
  bool _init = true;
  late PayoutHistoryProvider _payoutHistoryProvider;
  late LanguageProvider _languageProvider;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Only trigger if we're close to the bottom, not loading more, have more items, and have filtered results
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_payoutHistoryProvider.loadingMore &&
        _payoutHistoryProvider.hasMoreItems &&
        _payoutHistoryProvider.getFilteredTransactions().isNotEmpty &&
        _scrollController.position.maxScrollExtent > 0) {
      _payoutHistoryProvider.fetchMoreTransactions();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) {
      _init = false;
      _payoutHistoryProvider =
          Provider.of<PayoutHistoryProvider>(context, listen: true);
      _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
  }

  Assets? get assets => _payoutHistoryProvider.payoutHistoryData?.assets;

  /// Formats date as "d MMM" (e.g., "3 Apr")
  String _formatDateShort(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      // Format as "d MMM" to match design (e.g., "3 Apr" not "03 Apr")
      return DateFormat('d MMM').format(date);
    } catch (e) {
      return '';
    }
  }

  String _getDay(DateTime? date) {
    if (date == null) return '';
    try {
      return DateFormat('d').format(date);
    } catch (e) {
      return '';
    }
  }

  String _getMonth(DateTime? date) {
    if (date == null) return '';
    try {
      return DateFormat('MMM').format(date);
    } catch (e) {
      return '';
    }
  }

  /// Formats amount with currency symbol and sign
  String _formatAmount(double? amount) {
    if (amount == null) return '';
    final sign = amount >= 0 ? '+' : '-';
    final absAmount = amount.abs();
    final formatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: absAmount % 1 == 0 ? 0 : 1,
    ).format(absAmount);
    return '$sign $formatted';
  }

  Widget _getTransactionDetailsWidget(Transaction transaction) {
    List<InlineSpan> children = [];
    if (transaction.bankAccountId != null) {
      final bankAccount =
          _payoutHistoryProvider.getBankAccount(transaction.bankAccountId);
      if (bankAccount != null) {
        final primaryText = bankAccount.isPrimary == true ? 'Primary • ' : '';
        children.add(
          TextSpan(
            text: primaryText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12.sp,
                  color: AppColors.n70,
                  letterSpacing: -0.02,
                ),
          ),
        );
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          baseline: TextBaseline.alphabetic,
          child: RemoteImageHandler(
            imageUrl: _getBankIconUrl(transaction) ?? '',
            width: 12.w,
            height: 12.h,
            errorWidget: SvgPicture.asset(
              AssetConstants.defaultBankIcon,
              width: 12.w,
              height: 12.h,
            ),
          ),
        ));
        children.add(
          TextSpan(
            text: " xx${bankAccount.accountNumberLast4}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12.sp,
                  color: AppColors.n70,
                  letterSpacing: -0.02,
                ),
          ),
        );
      }
    }
    if (transaction.upiAccountId != null) {
      final upiAccount =
          _payoutHistoryProvider.getUpiAccount(transaction.upiAccountId);
      if (upiAccount != null) {
        children.add(
          TextSpan(
            text: "UPI • ",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12.sp,
                  color: AppColors.n70,
                  letterSpacing: -0.02,
                ),
          ),
        );
        children.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            baseline: TextBaseline.alphabetic,
            child: RemoteImageHandler(
              imageUrl: _getUpiIconUrl(transaction) ?? '',
              width: 12.w,
              height: 12.h,
              errorWidget: Image.asset(
                AssetConstants.defaultUpiIcon,
                width: 12.w,
                height: 12.h,
              ),
            )));
        children.add(
          TextSpan(
            text: " ${upiAccount.upiId}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12.sp,
                  color: AppColors.n70,
                  letterSpacing: -0.02,
                ),
          ),
        );
      }
    }
    // For credited transactions without bank/UPI, show period
    // if (transaction.transactionDate != null) {
    //   children.add(
    //     TextSpan(
    //       text:
    //           " • ${DateFormat('dd MMM yyyy').format(transaction.transactionDate!)}",
    //       style: Theme.of(context).textTheme.bodySmall?.copyWith(
    //             fontSize: 12.sp,
    //             color: AppColors.n70,
    //             letterSpacing: -0.02,
    //           ),
    //     ),
    //   );
    // }

    return RichText(
      text: TextSpan(
        children: children,
      ),
    );
  }

  /// Gets bank icon URL from provider
  String? _getBankIconUrl(Transaction transaction) {
    if (transaction.bankAccountId == null) return null;
    final bankAccount =
        _payoutHistoryProvider.getBankAccount(transaction.bankAccountId);
    return bankAccount?.iconUrl;
  }

  /// Gets UPI icon URL from provider
  String? _getUpiIconUrl(Transaction transaction) {
    if (transaction.upiAccountId == null) return null;
    final upiAccount =
        _payoutHistoryProvider.getUpiAccount(transaction.upiAccountId);
    return upiAccount?.iconUrl;
  }

  bool _isTransactionSuccessful(Transaction transaction) {
    return transaction.transactionTypeId == 1;
  }

  /// Gets transaction type indicator color
  Color _getTransactionTypeColor(Transaction transaction) {
    if (_isTransactionSuccessful(transaction)) {
      return AppColors.g30; // Green for credited
    }
    return AppColors.r40; // Red for withdrawn
  }

  /// Gets transaction type indicator icon
  Widget _getTransactionTypeIcon(Transaction transaction) {
    final isTransactionSuccessful = _isTransactionSuccessful(transaction);
    // Using simple container with border as arrow icon placeholder
    // In production, use actual arrow icons from assets
    String? imageUrl = isTransactionSuccessful ? assets?.credit : assets?.debit;
    String? fallbackImage = isTransactionSuccessful
        ? AssetConstants.defaultWithdrawalSuccessful
        : AssetConstants.defaultWithdrawalFailed;
    return Container(
      // width: 16.w,
      // height: 16.h,
      decoration: BoxDecoration(
        // color: _getTransactionTypeColor(transaction),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.n0, width: 2),
      ),
      child: RemoteImageHandler(
        imageUrl: imageUrl?.cdn ?? '',
        width: 16.w,
        height: 16.h,
        fit: BoxFit.contain,
        errorWidget: SvgPicture.asset(
          fallbackImage,
          width: 16.w,
          height: 16.h,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section label
        Padding(
          padding: EdgeInsets.only(
            // left: 20.w,
            top: 20.h,
            bottom: 16.h,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _languageProvider.getMessage(
                  'payouts_history', 'PAYOUTS HISTORY'),
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.n90.withValues(alpha: 0.5),
                letterSpacing: -0.02,
              ),
            ),
          ),
        ),

        // Filter tabs
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 0.w),
          child: Row(
            children: [
              Expanded(
                child: _FilterTab(
                  label: _languageProvider.getMessage(
                      'all_withdrawals', 'All withdrawals'),
                  isSelected: _payoutHistoryProvider.selectedFilter ==
                      PayoutHistoryFilter.all,
                  onTap: () => _payoutHistoryProvider
                      .onFilterChanged(PayoutHistoryFilter.all),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _FilterTab(
                  label:
                      _languageProvider.getMessage('successful', 'Successful'),
                  isSelected: _payoutHistoryProvider.selectedFilter ==
                      PayoutHistoryFilter.successful,
                  onTap: () => _payoutHistoryProvider
                      .onFilterChanged(PayoutHistoryFilter.successful),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _FilterTab(
                  label: _languageProvider.getMessage('failed', 'Failed'),
                  isSelected: _payoutHistoryProvider.selectedFilter ==
                      PayoutHistoryFilter.failed,
                  onTap: () => _payoutHistoryProvider
                      .onFilterChanged(PayoutHistoryFilter.failed),
                ),
              ),
            ],
          ),
        ),

        // SizedBox(height: 20.h),

        // Transaction list

        _payoutHistoryProvider.error != null && !_payoutHistoryProvider.loading
            ? Container(
                height: 0.4.sh,
                alignment: Alignment.center,
                child: Text(
                  _payoutHistoryProvider.error!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.r40,
                  ),
                ),
              )
            : _buildTransactionList(),
      ],
    );
  }

  /// Builds the transaction list widget
  Widget _buildTransactionList() {
    final transactions = _payoutHistoryProvider.getFilteredTransactions();
    final hasMoreItems = _payoutHistoryProvider.hasMoreItems;
    final isLoadingMore = _payoutHistoryProvider.loadingMore;

    if (_payoutHistoryProvider.loading && transactions.isEmpty) {
      return Container(
        height: 0.4.sh,
        alignment: Alignment.center,
        child: CupertinoActivityIndicator(),
      );
    }

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          children: [
            SizedBox(height: 50.h),
            RemoteImageHandler(
              imageUrl: assets?.payoutsEmptyStateView?.cdn ?? '',
              height: 80.h,
              errorWidget: Image.asset(
                AssetConstants.payoutEmptyStateView,
                height: 80.h,
              ),
            ),
            Text(
              _languageProvider.getMessage('no_payouts_yet', 'No payouts yet'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.n70,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _payoutHistoryProvider.refreshPayoutHistory,
      child: ListView.separated(
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 20.h),
        itemCount: transactions.length + (hasMoreItems ? 1 : 0),
        separatorBuilder: (context, index) {
          if (index == transactions.length) {
            return const SizedBox.shrink();
          }
          return SizedBox(height: 12.h);
        },
        itemBuilder: (context, index) {
          if (index == transactions.length) {
            // Bottom section with loading indicator
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: isLoadingMore
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                      ),
                    )
                  : const SizedBox.shrink(),
            );
          }
          return TransactionCard(
            transaction: transactions[index],
            payoutHistoryProvider: _payoutHistoryProvider,
            formatDateShort: _formatDateShort,
            formatAmount: _formatAmount,
            getTransactionDetailsWidget: _getTransactionDetailsWidget,
            getTransactionTypeColor: _getTransactionTypeColor,
            getTransactionTypeIcon: _getTransactionTypeIcon,
            getTransactionTypeName: (id) =>
                _payoutHistoryProvider.getTransactionTypeName(id),
            getDay: _getDay,
            getMonth: _getMonth,
          );
        },
      ),
    );
  }
}

/// Widget for individual filter tab button
class _FilterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.n90 : AppColors.n0,
          borderRadius: BorderRadius.circular(30.r),
        ),
        child: Center(
          child: FittedBox(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: isSelected ? AppColors.n0 : AppColors.n90,
                letterSpacing: -0.02,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
