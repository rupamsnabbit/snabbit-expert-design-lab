import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

/// Function to show PAN details bottom sheet
void showPanDetailsBottomSheet({
  required BuildContext context,
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
        child: PanDetailsBottomSheetContent(),
      );
    },
  );
}

/// Widget to display PAN details content in bottom sheet
class PanDetailsBottomSheetContent extends StatelessWidget {
  const PanDetailsBottomSheetContent({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final userProfileProvider = Provider.of<UserProfileProvider>(context);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final panNumber = userProfileProvider.user?.pan ?? 'N/A';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            // PAN Number
            _buildDetailItem(
              context: context,
              label: languageProvider.getMessage('pan_number', 'PAN Number'),
              value: panNumber,
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
      },
    );
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
