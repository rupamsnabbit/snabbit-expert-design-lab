import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/loan_provider.dart';
import 'package:snabbit_runner/services/loan_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/loan/utils/loan_tracking.dart';

void showLoanUnifiedSheet(
  BuildContext parentContext,
  LanguageProvider languageProvider,
  LoanProvider loanProvider,
  String source,
) {
  // Track the last logged state to prevent duplicate logs on rebuilds
  String? lastLoggedState;

  showModalBottomSheet(
    context: parentContext,
    isDismissible: true,
    backgroundColor: AppColors.n0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
    ),
    builder: (context) {
      return ListenableBuilder(
        listenable: loanProvider,
        builder: (context, _) {
          // Loading state or initial state (when loanDetails is null but not error)
          if (loanProvider.isLoading ||
              loanProvider.loanDetails == null && loanProvider.error == null) {
            return SizedBox(
              height: 250.h,
              width: double.infinity,
              child: const Center(
                child: CupertinoActivityIndicator(),
              ),
            );
          }

          // Error state
          if (loanProvider.error != null) {
            return Padding(
              padding: EdgeInsets.all(24.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.r,
                    color: AppColors.r50,
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    languageProvider.getMessage(
                      'loan_details_error',
                      'Failed to load loan details',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await loanProvider.retryFetchLoanDetails();
                      },
                      child: Text(
                        languageProvider.getMessage('retry', 'Retry'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Success state - show appropriate UI based on loan details
          final loanDetails = loanProvider.loanDetails!;

          // Early payout taken
          if (loanDetails.isEarlyPayoutTaken) {
            // Track view only if not already logged for this state
            if (lastLoggedState != 'early_payout') {
              lastLoggedState = 'early_payout';
              WidgetsBinding.instance.addPostFrameCallback((_) {
                LoanTracking.trackLoanBottomSheetImpression(
                  state: 'early_payout',
                  source: source,
                );
              });
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 28.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AssetConstants.loanMoneyLocked,
                    height: 120.h,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    languageProvider.getMessage(
                      'loan_not_available_early_payout',
                      'Loan not available as you have taken Early payout',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    languageProvider.getMessage(
                      'loan_come_back_next_month',
                      'Come back next month to take loan',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.n80,
                        ),
                  ),
                  SizedBox(height: 56.h),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48.h),
                      backgroundColor: AppColors.p50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onPressed: () {
                      LoanTracking.trackLoanBottomSheetAction(
                        action: 'understood',
                        state: 'early_payout',
                        source: source,
                      );
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      languageProvider.getMessage('understood', 'Understood'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            letterSpacing: -0.24,
                            color: AppColors.p10,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Loan already processed
          if (loanDetails.isLoanProcessed) {
            // Track view only if not already logged for this state
            if (lastLoggedState != 'loan_processed') {
              lastLoggedState = 'loan_processed';
              WidgetsBinding.instance.addPostFrameCallback((_) {
                LoanTracking.trackLoanBottomSheetImpression(
                  state: 'loan_processed',
                  source: source,
                );
              });
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 28.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AssetConstants.loanMoney,
                    height: 120.h,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    languageProvider.getMessage(
                      'loan_already_processed',
                      'Your loan has already been processed',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: 88.h),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48.h),
                      backgroundColor: AppColors.p50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onPressed: () {
                      LoanTracking.trackLoanBottomSheetAction(
                        action: 'view_details',
                        state: 'loan_processed',
                        source: source,
                      );
                      Navigator.of(context).pop();
                      LoanService.openVendorUrl(
                          parentContext, loanDetails.vendorUrl, source);
                    },
                    child: Text(
                      languageProvider.getMessage(
                          'view_details', 'View Details'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            letterSpacing: -0.24,
                            color: AppColors.p10,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Happy path - open vendor URL and close sheet
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
              Navigator.of(context).pop();
              LoanService.openVendorUrl(
                  parentContext, loanDetails.vendorUrl, source);
            }
          });
          return const SizedBox.shrink();
        },
      );
    },
  );
}
