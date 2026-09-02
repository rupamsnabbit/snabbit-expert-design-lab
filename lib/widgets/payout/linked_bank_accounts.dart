import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/payout/bank_account.dart';
import 'package:snabbit_runner/models/payout/upi_account.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_bank_or_upi_details_screen.dart';
import 'package:snabbit_runner/pages/signup/bank_details/bank_account_details_screen.dart';
import 'package:snabbit_runner/pages/signup/bank_details/upi_details_screen.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/payout/add_bank_banner.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Widget to display linked bank accounts with different UI states
class LinkedBankAccounts extends StatelessWidget {
  /// Callback when add bank account button is tapped
  final VoidCallback? onAddBankAccount;

  /// Callback when bank account card is tapped
  final void Function(BankAccount)? onBankAccountTap;
  final void Function(UpiAccount)? onUpiAccountTap;

  final List<BankAccount>? bankAccounts;
  final List<UpiAccount>? upiAccounts;
  final String? emptyStateBankImage;
  final bool showOnlyCards;
  final bool loading;
  final bool showTailWidget;

  const LinkedBankAccounts({
    super.key,
    this.onAddBankAccount,
    this.onBankAccountTap,
    this.bankAccounts,
    this.upiAccounts,
    this.emptyStateBankImage,
    this.onUpiAccountTap,
    this.showOnlyCards = false,
    required this.loading,
    this.showTailWidget = true,
  });

  /// Gets the list of bank accounts from provider
  List<BankAccount> _getBankAccounts() {
    return bankAccounts ?? [];
  }

  List<UpiAccount> _getUpiAccounts() {
    return upiAccounts ?? [];
  }

  /// Checks if bank account has issues
  /// Note: This would ideally come from API response. For now, checking if account number is null or empty
  bool _hasBankAccountIssues(BankAccount bankAccount) {
    // Placeholder logic - adjust based on actual API response
    // You might want to add a status field to BankAccount model
    return bankAccount.accountNumberLast4 == null ||
        bankAccount.accountNumberLast4!.isEmpty;
  }

  bool _hasUpiAccountIssues(UpiAccount upiAccount) {
    return upiAccount.upiId == null || upiAccount.upiId!.isEmpty;
  }

  /// Builds the account cards content (common for both modes)
  Widget _buildAccountCardsContent(
      LanguageProvider languageProvider, BuildContext context) {
    final bankAccounts = _getBankAccounts();
    final upiAccounts = _getUpiAccounts();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bankAccounts.isEmpty && upiAccounts.isEmpty)
          // Empty state
          _buildEmptyState(context)
        else ...[
          // Bank account list
          ...bankAccounts
              .where((bankAccount) => bankAccount.isPrimary == true)
              .map((bankAccount) {
            final hasIssues = _hasBankAccountIssues(bankAccount);
            return Padding(
              padding:
                  EdgeInsets.only(bottom: upiAccounts.isEmpty ? 0.h : 16.h),
              child: _buildBankAccountCard(
                bankAccount: bankAccount,
                hasIssues: hasIssues,
                languageProvider: languageProvider,
                context: context,
              ),
            );
          }),
          ...upiAccounts
              .where((upiAccount) => upiAccount.isPrimary == true)
              .map((upiAccount) {
            final hasIssues = _hasUpiAccountIssues(upiAccount);
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: _buildUpiAccountCard(
                upiAccount: upiAccount,
                hasIssues: hasIssues,
                languageProvider: languageProvider,
                context: context,
              ),
            );
          }),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox();
    }
    // If showOnlyCards is true, return just the account cards without container and title
    if (showOnlyCards) {
      return Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return _buildAccountCardsContent(languageProvider, context);
        },
      );
    }

    // Default behavior with container and title
    return Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 0.w),
        child: Column(
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
                  languageProvider.getMessage(
                      'linked_bank_accounts', 'LINKED BANK ACCOUNTS'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.n90.withValues(alpha: 0.5),
                        letterSpacing: -0.02,
                      ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.n0,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: Offset(0, 1.h),
                    blurRadius: 4.r,
                  ),
                ],
              ),
              child: _buildAccountCardsContent(languageProvider, context),
            ),
          ],
        ),
      );
    });
  }

  /// Builds the empty state widget
  Widget _buildEmptyState(BuildContext context) {
    // final textTheme = Theme.of(context).textTheme;

    return AddBankBanner(
      onTap: () {
        Navigator.of(context).pushNamed(AddBankOrUpiDetailsScreen.routeName);
      },
      image: emptyStateBankImage ?? '',
    );
  }

  /// Builds a bank account card widget
  Widget _buildBankAccountCard({
    required BankAccount bankAccount,
    required bool hasIssues,
    required LanguageProvider languageProvider,
    required BuildContext context,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final isPrimary = bankAccount.isPrimary == true;

    String bankName = bankAccount.bankName ?? '';
    if (bankName.trim().isEmpty) {
      bankName = languageProvider.getMessage('bank', 'Bank');
    }

    return GestureDetector(
      onTap: onBankAccountTap != null
          ? () {
              onBankAccountTap!(bankAccount);
            }
          : () {
              Navigator.of(context)
                  .pushNamed(BankAccountDetailsScreen.routeName);
            },
      child: Container(
        width: double.infinity,
        // padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: hasIssues ? AppColors.n20 : AppColors.n0,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.n30,
            width: 1.r,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 18.81.h, 14.w, 21.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Bank icon with status indicator
                  _buildBankIcon(
                      bankAccount: bankAccount, hasIssues: hasIssues),
                  SizedBox(width: 13.w),
                  // Bank details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bank name
                        Text(
                          bankName,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.02,
                            color: hasIssues
                                ? AppColors.n90.withValues(alpha: 0.4)
                                : AppColors.n90,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        // Account number
                        Text(
                          'A/C no: ${_formatAccountNumber(bankAccount.accountNumberLast4)}',
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.02,
                            color: hasIssues
                                ? const Color(0xFF6D7783).withOpacity(0.4)
                                : const Color(0xFF6D7783),
                          ),
                        ),
                        if (hasIssues) ...[
                          SizedBox(height: 2.h),
                          // Issue message
                          Text(
                            languageProvider.getMessage(
                              'account_facing_issues',
                              'Account facing issues',
                            ),
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.02,
                              color: AppColors.r40,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Chevron button
                  if (showTailWidget)
                    Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.n30,
                          width: 1.5.w,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20.r,
                        color: AppColors.n90,
                      ),
                    ),
                ],
              ),
            ),
            // Primary Bank tag
            if (isPrimary)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.g10,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12.r),
                      bottomLeft: Radius.circular(4.r),
                    ),
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      'primary_bank',
                      'Primary Bank',
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.02,
                      color: AppColors.g50,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the bank icon with status indicator
  Widget _buildBankIcon({
    required BankAccount bankAccount,
    required bool hasIssues,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bank icon container
        Container(
          width: 40.76.w,
          height: 40.76.h,
          decoration: BoxDecoration(
            color: AppColors.n20,
            shape: BoxShape.circle,
          ),
          child: bankAccount.iconUrl != null && bankAccount.iconUrl!.isNotEmpty
              ? ClipOval(
                  child: RemoteImageHandler(
                    imageUrl: bankAccount.iconUrl!,
                    width: 24.r,
                    height: 24.r,
                    fit: BoxFit.cover,
                    errorWidget: SvgPicture.asset(
                      AssetConstants.defaultBankIcon,
                      width: 24.r,
                      height: 24.r,
                    ),
                  ),
                )
              : SvgPicture.asset(
                  AssetConstants.defaultBankIcon,
                  width: 24.r,
                  height: 24.r,
                ),
        ),
        // Status indicator overlay
        if (hasIssues)
          // Warning icon overlay
          Positioned(
            right: -1.71.w,
            top: -2.78.h,
            child: SvgPicture.asset(
              AssetConstants.bankWarning,
              width: 16.w,
              // height: 14.12.h,
            ),
          )
        else
          // Success checkmark overlay
          Positioned(
            right: -3.71.w,
            top: -2.78.h,
            child: SvgPicture.asset(
              AssetConstants.assuredCheck,
              width: 20.38.w,
              height: 20.38.h,
            ),
          ),
      ],
    );
  }

  Widget _buildUpiAccountCard({
    required UpiAccount upiAccount,
    required bool hasIssues,
    required LanguageProvider languageProvider,
    required BuildContext context,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final isPrimary = upiAccount.isPrimary == true;

    String name = upiAccount.providerName ?? '';
    if (name.trim().isEmpty) {
      name = languageProvider.getMessage('upi', "UPI");
    }

    return GestureDetector(
      onTap: onUpiAccountTap != null
          ? () {
              onUpiAccountTap!(upiAccount);
            }
          : () {
              Navigator.of(context).pushNamed(UpiDetailsScreen.routeName);
            },
      child: Container(
        width: double.infinity,
        // padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: hasIssues ? AppColors.n20 : AppColors.n0,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppColors.n30,
            width: 1.r,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 18.81.h, 14.w, 21.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Bank icon with status indicator
                  _buildUpiIcon(upiAccount: upiAccount, hasIssues: hasIssues),
                  SizedBox(width: 13.w),
                  // Bank details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bank name
                        Text(
                          name,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.02,
                            color: hasIssues
                                ? AppColors.n90.withValues(alpha: 0.4)
                                : AppColors.n90,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        // Account number
                        Text(
                          'ID: ${upiAccount.upiId}',
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.02,
                            color: hasIssues
                                ? const Color(0xFF6D7783).withOpacity(0.4)
                                : const Color(0xFF6D7783),
                          ),
                        ),
                        if (hasIssues) ...[
                          SizedBox(height: 2.h),
                          // Issue message
                          Text(
                            languageProvider.getMessage(
                              'account_facing_issues',
                              'Account facing issues',
                            ),
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.02,
                              color: AppColors.r40,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Chevron button
                  if (showTailWidget)
                    Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.n30,
                          width: 1.5.w,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20.r,
                        color: AppColors.n90,
                      ),
                    ),
                ],
              ),
            ),
            // Primary Bank tag
            if (isPrimary)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.g10,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12.r),
                      bottomLeft: Radius.circular(4.r),
                    ),
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      'primary_upi',
                      'Primary UPI',
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.02,
                      color: AppColors.g50,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the bank icon with status indicator
  Widget _buildUpiIcon({
    required UpiAccount upiAccount,
    required bool hasIssues,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bank icon container
        Container(
          width: 40.76.w,
          height: 40.76.h,
          decoration: BoxDecoration(
            color: AppColors.n20,
            shape: BoxShape.circle,
          ),
          child: upiAccount.iconUrl != null && upiAccount.iconUrl!.isNotEmpty
              ? ClipOval(
                  child: RemoteImageHandler(
                    imageUrl: upiAccount.iconUrl!,
                    width: 24.r,
                    height: 24.r,
                    fit: BoxFit.cover,
                    errorWidget: Image.asset(
                      AssetConstants.defaultUpiIcon,
                      width: 24.r,
                      height: 24.r,
                    ),
                  ),
                )
              : Image.asset(
                  AssetConstants.defaultUpiIcon,
                  width: 24.r,
                  height: 24.r,
                ),
        ),
        // Status indicator overlay
        if (hasIssues)
          // Warning icon overlay
          Positioned(
            right: -1.71.w,
            top: -2.78.h,
            child: SvgPicture.asset(
              AssetConstants.bankWarning,
              width: 16.w,
              // height: 14.12.h,
            ),
          )
        else
          // Success checkmark overlay
          Positioned(
            right: -3.71.w,
            top: -2.78.h,
            child: SvgPicture.asset(
              AssetConstants.assuredCheck,
              width: 20.38.w,
              height: 20.38.h,
            ),
          ),
      ],
    );
  }

  /// Formats account number with masking
  String _formatAccountNumber(String? accountNumberLast4) {
    if (accountNumberLast4 == null || accountNumberLast4.isEmpty) {
      return 'xxxx xxxx';
    }
    // Format as "xxxx xxxx 6288" if we have last 4 digits
    return 'xxxx xxxx $accountNumberLast4';
  }

  /// Builds the add bank account button for future use
  Widget _buildAddBankAccountButton({
    required LanguageProvider languageProvider,
    required BuildContext context,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onAddBankAccount,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.n0,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: AppColors.brand,
            width: 1.w,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              languageProvider.getMessage(
                'add_upi_id_bank_account',
                'Add UPI ID/ bank account',
              ),
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.02,
                color: AppColors.n90,
              ),
              textAlign: TextAlign.center,
            ),
            // Flexible(
            //   child: Column(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Text(
            //         _languageProvider.getMessage(
            //           'add_upi_id_bank_account',
            //           'Add UPI ID/ bank account',
            //         ),
            //         style: textTheme.bodyMedium?.copyWith(
            //           fontSize: 14.sp,
            //           fontWeight: FontWeight.w600,
            //           letterSpacing: -0.02,
            //           color: AppColors.n90,
            //         ),
            //         textAlign: TextAlign.center,
            //       ),
            //       SizedBox(height: 12.h),
            //       // Plus icon
            //       Container(
            //         width: 36.w,
            //         height: 36.h,
            //         decoration: BoxDecoration(
            //           color: AppColors.brand,
            //           shape: BoxShape.circle,
            //         ),
            //         child: Center(
            //           child: SvgPicture.asset(
            //             AssetConstants.add,
            //             width: 14.w,
            //             height: 14.h,
            //             colorFilter: const ColorFilter.mode(
            //               AppColors.n0,
            //               BlendMode.srcIn,
            //             ),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),

            // ),
            SvgPicture.asset(
              AssetConstants.add,
            ),
          ],
        ),
      ),
    );
  }
}
