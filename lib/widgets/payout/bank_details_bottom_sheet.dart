import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/payout/expert_bank_details.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

/// Function to show bank details bottom sheet
void showBankDetailsBottomSheet({
  required BuildContext context,
  required ExpertBankDetails bankDetails,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.n0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16.r),
      ),
    ),
    builder: (context) {
      return CommonBottomSheetSetup(
        child: BankDetailsBottomSheetContent(
          bankDetails: bankDetails,
        ),
      );
    },
  );
}

/// Widget to display bank details content in bottom sheet
class BankDetailsBottomSheetContent extends StatelessWidget {
  /// The expert bank details object containing account information
  final ExpertBankDetails bankDetails;

  const BankDetailsBottomSheetContent({
    super.key,
    required this.bankDetails,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.h),
          // Bank account details section
          if (bankDetails.isBankAccount) ...[
            // Account Number
            _buildDetailItem(
              context: context,
              label: languageProvider.getMessage(
                  'account_number', 'Account Number'),
              value: bankDetails.accountNumber ?? 'N/A',
              labelStyle: textTheme.titleMedium,
              valueStyle: textTheme.bodyLarge,
            ),
            SizedBox(height: 16.h),
            // IFSC Code
            _buildDetailItem(
              context: context,
              label: languageProvider.getMessage('ifsc_code', 'IFSC Code'),
              value: bankDetails.ifscCode ?? 'N/A',
              labelStyle: textTheme.titleMedium,
              valueStyle: textTheme.bodyLarge,
            ),
            SizedBox(height: 16.h),
          ],
          // UPI ID (if UPI account)
          if (bankDetails.isUpiAccount) ...[
            _buildDetailItem(
              context: context,
              label: languageProvider.getMessage('upi_id', 'UPI ID'),
              value: bankDetails.upiId ?? 'N/A',
              labelStyle: textTheme.titleMedium,
              valueStyle: textTheme.bodyLarge,
            ),
            SizedBox(height: 16.h),
          ],
          // Beneficiary Name
          _buildDetailItem(
            context: context,
            label: languageProvider.getMessage(
                'beneficiary_name', 'Beneficiary Name'),
            value: bankDetails.beneficiaryName ?? 'N/A',
            labelStyle: textTheme.titleMedium,
            valueStyle: textTheme.bodyLarge,
          ),
          SizedBox(height: 32.h),
          // OK Button
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                languageProvider.getMessage('ok_capital', 'OK'),
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.n0,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Builds a detail item with label and value
  Widget _buildDetailItem({
    required BuildContext context,
    required String label,
    required String value,
    required TextStyle? labelStyle,
    required TextStyle? valueStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: labelStyle,
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: valueStyle,
        ),
      ],
    );
  }
}
