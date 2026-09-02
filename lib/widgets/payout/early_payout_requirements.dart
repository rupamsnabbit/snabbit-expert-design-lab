import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/early_payouts_model.dart';
import 'package:snabbit_runner/providers/early_payouts_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

void showEarlyPayoutRequirements(BuildContext context) {
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
        horizontalPadding: 0,
        bottomPadding: 0,
        child: const EarlyPayoutRequirements(),
      );
    },
  );
}

/// Widget to display early payout requirements in a modal sheet
class EarlyPayoutRequirements extends StatelessWidget {
  const EarlyPayoutRequirements({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<EarlyPayoutsProvider, LanguageProvider>(
      builder: (context, earlyPayoutsProvider, languageProvider, child) {
        final textTheme = Theme.of(context).textTheme;
        final requirements =
            earlyPayoutsProvider.earlyPayoutsData?.requirements ?? [];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      languageProvider.getMessage(
                        'early_payout_requirements',
                        'Early payout requirements',
                      ),
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.24,
                        color: AppColors.n90,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Requirements list
                    if (requirements.isNotEmpty)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: requirements.asMap().entries.map((entry) {
                          final index = entry.key;
                          final requirement = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index < requirements.length - 1 ? 8.h : 0,
                            ),
                            child: _RequirementItem(
                              requirement: requirement,
                              languageProvider: languageProvider,
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 40.h),

              // Button area
              Container(
                width: double.infinity,
                height: 72.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.brand,
                          width: 1.5.w,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                      ),
                      child: Text(
                        languageProvider.getMessage(
                          'understood',
                          'Understood',
                        ),
                        style: textTheme.labelLarge?.copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.24,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final EarlyPayoutRequirement requirement;
  final LanguageProvider languageProvider;

  const _RequirementItem({
    required this.requirement,
    required this.languageProvider,
  });

  /// Determines if requirement is met (for now, always returns true for UI)
  /// This can be updated when API provides status information
  // bool _isRequirementMet() {
  //   // TODO: Update this logic when API provides requirement status
  //   // For now, showing all as met (green checkmark) for UI purposes
  //   return true;
  // }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // final isMet = _isRequirementMet();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 8.w),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.n70,
           ),
          height: 4.r,
          width: 4.r,
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: Text(
            languageProvider.getMessage(
              requirement.label ?? '',
              requirement.label ?? '',
            ),
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              height: 18 / 14,
              letterSpacing: -0.24,
              color: AppColors.n70,
            ),
          ),
        ),
      ],
    );
  }
}
