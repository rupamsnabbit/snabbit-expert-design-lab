import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/early_payouts_model.dart';
import 'package:snabbit_runner/models/payout/bank_account.dart';
import 'package:snabbit_runner/models/payout/upi_account.dart';
import 'package:snabbit_runner/providers/early_payouts_provider.dart';
import 'package:snabbit_runner/providers/loan_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/payout/linked_bank_accounts.dart';

enum PayoutWithdrawerState {
  neutral,
  enabled,
  restricted,
  processing,
  success,
}

void showPayoutWithdrawer(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.n0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16.r),
      ),
    ),
    isDismissible: true,
    enableDrag: false,
    useRootNavigator: true,
    builder: (context) {
      return Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: CommonBottomSheetSetup(
          horizontalPadding: 0,
          bottomPadding: 0,
          child: SafeArea(child: const PayoutWithdrawer()),
        ),
      );
    },
  );
}

class PayoutWithdrawer extends StatefulWidget {
  const PayoutWithdrawer({super.key});

  @override
  State<PayoutWithdrawer> createState() => _PayoutWithdrawerState();
}

class _PayoutWithdrawerState extends State<PayoutWithdrawer> {
  bool _init = false;
  late EarlyPayoutsProvider _earlyPayoutsProvider;
  late LanguageProvider _languageProvider;
  PayoutWithdrawerState _currentState = PayoutWithdrawerState.neutral;
  String _amountText = '';
  String? _transactionId;
  double? _withdrawalAmount;
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      _earlyPayoutsProvider =
          Provider.of<EarlyPayoutsProvider>(context, listen: true);
      _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
  }

  void _onAmountChanged() {
    setState(() {
      _amountText = _amountController.text;
      _updateState();
    });
  }

  EarlyPayoutsData? get _earlyPayoutsData =>
      _earlyPayoutsProvider.earlyPayoutsData;

  int get _minAmount => _earlyPayoutsData?.minWithdrawalAmount ?? 100;

  int get _maxAmount => _earlyPayoutsData?.maxWithdrawalAmount ?? 6000;

  double? get _currentAmount {
    if (_amountText.isEmpty) return null;
    return double.tryParse(_amountText);
  }

  bool get _meetsMinimum =>
      _currentAmount != null && _currentAmount! >= _minAmount;

  bool get _meetsMaximum =>
      _currentAmount != null && _currentAmount! <= _maxAmount;

  bool get _isAmountValid => _meetsMinimum && _meetsMaximum;

  void _updateState() {
    if (_currentState == PayoutWithdrawerState.processing ||
        _currentState == PayoutWithdrawerState.success) {
      return; // Don't change state if processing or success
    }

    if (_amountText.isEmpty) {
      setState(() {
        _currentState = PayoutWithdrawerState.neutral;
      });
    } else if (_isAmountValid) {
      setState(() {
        _currentState = PayoutWithdrawerState.enabled;
      });
    } else {
      setState(() {
        _currentState = PayoutWithdrawerState.restricted;
      });
    }
  }

  /// Formats amount as double with currency symbol
  String _formatAmountDouble(double? amount) {
    if (amount == null) return '';
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  Future<void> _handleConfirm() async {
    if (_currentAmount == null || !_isAmountValid) return;

    setState(() {
      _currentState = PayoutWithdrawerState.processing;
      _withdrawalAmount = _currentAmount;
    });

    try {
      final result = await _earlyPayoutsProvider.requestManualWithdraw(
        requestedAmount: _currentAmount!,
      );

      if (result.success) {
        // Reset loan details so they are refetched next time
        // (early payout makes the user ineligible for loans)
        if (mounted) {
          context.read<LoanProvider>().reset();
        }

        setState(() {
          _currentState = PayoutWithdrawerState.success;
          _transactionId = result.transactionId;
        });

        // Auto-close the success screen after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      } else {
        // Close the modal sheet first so user can see the error snackbar
        Navigator.of(context).pop();
        ClevertapSetup.logEvent(TrackingEvents.withdrawFailed, {
          "type": "early_payout",
          "amount": _withdrawalAmount,
        });
        showSnackbar(
            context,
            result.error ??
                _languageProvider.getMessage('withdrawal_error_occurred',
                    'An error occurred during withdrawal'));
      }
    } catch (e) {
      // Close the modal sheet first so user can see the error snackbar
      Navigator.of(context).pop();
      showSnackbar(
          context,
          _languageProvider.getMessage('unexpected_error_try_again',
              'An unexpected error occurred. Please try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<EarlyPayoutsProvider, LanguageProvider>(
      builder: (context, earlyPayoutsProvider, languageProvider, child) {
        _earlyPayoutsProvider = earlyPayoutsProvider;
        _languageProvider = languageProvider;

        return _buildContent();
      },
    );
  }

  Widget _buildContent() {
    switch (_currentState) {
      case PayoutWithdrawerState.processing:
        return _buildProcessingState();
      case PayoutWithdrawerState.success:
        return _buildSuccessState();
      default:
        return _buildInputState();
    }
  }

  Widget _buildInputState() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 24.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                _languageProvider.getMessage('withdraw', 'Withdraw'),
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.24,
                  color: AppColors.n90,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              // Input section
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _languageProvider.getMessage(
                      'amount_will_be_credited_to',
                      'Amount will be credited to',
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.24,
                      color: AppColors.n90,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // Display bank or upi details card
                  LinkedBankAccounts(
                    bankAccounts: _earlyPayoutsData?.bankAccounts,
                    upiAccounts: _earlyPayoutsData?.upiAccounts,
                    showOnlyCards: true,
                    loading: _earlyPayoutsProvider.loading,
                  ),
                  if (_earlyPayoutsData?.upiAccounts != null)
                    SizedBox(
                        height: _earlyPayoutsData?.upiAccounts!.isEmpty ?? true
                            ? 24.h
                            : 8.h),
                  Text(
                    _languageProvider.getMessage(
                      'enter_amount_to_withdraw',
                      'Enter amount to withdraw',
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.24,
                      color: AppColors.n90,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // Input field
                  Container(
                    width: double.infinity,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: AppColors.n0,
                      border: Border.all(
                        color: const Color(0xFFD8DADC),
                        width: 1.w,
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.24,
                        color: AppColors.n90,
                      ),
                      decoration: InputDecoration(
                        hintText: _languageProvider.getMessage(
                          'enter_amount',
                          'Enter amount',
                        ),
                        hintStyle: textTheme.bodyLarge?.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.24,
                          color: AppColors.n50,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 15.h,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _buildValidationMessages(),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        // Withdraw button
        Container(
          width: double.infinity,
          height: 72.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Center(
            child: SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: _isAmountValid ? _handleConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAmountValid
                      ? AppColors.brand
                      : AppColors.brandInverted,
                  disabledBackgroundColor: AppColors.brandInverted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                ),
                child: Text(
                  _languageProvider.getMessage('confirm', 'Confirm'),
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.24,
                    color: _isAmountValid ? AppColors.n0 : AppColors.n60,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds validation messages with status indicators
  Widget _buildValidationMessages() {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidationItem(
          text: _languageProvider.getFormattedMessage(
            'min_withdrawal_amount_is_x',
            'Minimum withdrawal amount is ₹{{amount}}',
            {'amount': _minAmount.toString()},
          ),
          isValid: _meetsMinimum,
        ),
        SizedBox(height: 4.h),
        _buildValidationItem(
          text: _languageProvider.getFormattedMessage(
            'max_withdrawal_amount_is_x',
            'Maximum withdrawal amount is ₹{{amount}}',
            {'amount': _maxAmount.toString()},
          ),
          isValid: _meetsMaximum,
        ),
        SizedBox(height: 4.h),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.n70,
              ),
              height: 4.r,
              width: 4.r,
            ),
            SizedBox(width: 8.w),
            Text(
              _languageProvider.getMessage(
                'withdrawal_may_take_few_days_to_process',
                'Withdrawal may take few days to process',
              ),
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                height: 18 / 12,
                letterSpacing: -0.24,
                color: AppColors.n60,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValidationItem({
    required String text,
    required bool isValid,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.n70,
          ),
          height: 4.r,
          width: 4.r,
        ),
        SizedBox(width: 8.w),
        Text(
          text,
          style: textTheme.bodySmall?.copyWith(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            height: 18 / 12,
            letterSpacing: -0.24,
            color: AppColors.n60,
          ),
        ),
        SizedBox(width: 4.w),
        if (_amountText.isNotEmpty)
          Container(
            width: 14.w,
            height: 14.h,
            decoration: BoxDecoration(
              color: isValid ? AppColors.g40 : AppColors.r40,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isValid ? Icons.check : Icons.close,
                size: 10.sp,
                color: AppColors.n0,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds processing state
  Widget _buildProcessingState() {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle area
        SizedBox(height: 12.h),

        // Content area
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading indicator
              SizedBox(
                width: 72.w,
                height: 72.h,
                child: CircularProgressIndicator(
                  strokeWidth: 4.w,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
              ),
              SizedBox(height: 24.h),

              // Title
              Text(
                _languageProvider.getMessage(
                  'processing_withdrawal',
                  'Processing Withdrawal',
                ),
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.24,
                  color: AppColors.n90,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),

              // Transaction ID
              if (_transactionId != null)
                Text(
                  'Transaction ID : $_transactionId',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.24,
                    color: AppColors.n60,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds success state
  Widget _buildSuccessState() {
    final textTheme = Theme.of(context).textTheme;
    ClevertapSetup.logEvent(TrackingEvents.withdrawSuccess, {
      "type": "early_payout",
      "amount": _withdrawalAmount,
    });
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 38.h),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 72.w,
              height: 72.h,
              decoration: BoxDecoration(
                color: AppColors.g40,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                size: 23.14.sp,
                color: AppColors.n0,
              ),
            ),
            SizedBox(height: 24.h),

            // Title
            Text(
              _languageProvider.getMessage(
                'successfully_processed',
                'Successfully Processed',
              ),
              style: textTheme.headlineMedium?.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.24,
                color: AppColors.n90,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            if (_withdrawalAmount != null)
              Text(
                _languageProvider.getFormattedMessage(
                  'amount_will_be_transferred_to_primary_bank',
                  '{{amount}} will be transferred to your primary bank account',
                  {'amount': _formatAmountDouble(_withdrawalAmount)},
                ),
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.24,
                  color: AppColors.n80,
                ),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 12.h),

            // Transaction ID
            if (_transactionId != null)
              Text(
                'Transaction ID : $_transactionId',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.24,
                  color: AppColors.n60,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ],
    );
  }
}
