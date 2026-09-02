import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_payout_option.dart';
import 'package:snabbit_runner/pages/signup/bank_details/enter_bank_details.dart';
import 'package:snabbit_runner/pages/signup/bank_details/enter_upi_details.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';

class AddBankOrUpiDetailsScreen extends StatefulWidget {
  static const String routeName = "/add_bank_or_upi_details";
  const AddBankOrUpiDetailsScreen({super.key});

  @override
  State<AddBankOrUpiDetailsScreen> createState() =>
      _AddBankOrUpiDetailsScreenState();
}

class _AddBankOrUpiDetailsScreenState extends State<AddBankOrUpiDetailsScreen> {
  bool init = true;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  bool canContinue() {
    // User can continue only when a payout option is selected
    return onboardingStepsProvider.selectedPayoutOption != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        elevation: 6,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage(
              "add_bank_or_upi_details", "Adding Bank/UPI Details"),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 16.sp,
              ),
        ),
      ),
      persistentFooterButtons: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 48.h,
                  maxWidth: 1.sw,
                ),
                child: ElevatedButton(
                  onPressed: canContinue()
                      ? () {
                          if (onboardingStepsProvider.selectedPayoutOption ==
                              PayoutOption.upi) {
                            Navigator.pushNamed(
                                context, EnterUpiDetails.routeName);
                          } else {
                            Navigator.pushNamed(
                                context, EnterBankDetails.routeName);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canContinue() ? AppColors.brand : AppColors.n20,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    minimumSize:
                        Size.fromHeight(48.h), // Ensures button stretches
                  ),
                  // Todo: Configure the CTA text
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      languageProvider.getMessage('confirm', "Confirm"),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: canContinue() ? AppColors.n0 : AppColors.n60,
                          ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1.sw,
                  maxHeight: 48.h,
                ),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.brand,
                      width: 1.r,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    minimumSize:
                        Size.fromHeight(48.h), // Ensures button stretches
                  ),
                  // Todo: Configure the CTA text
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Go Back',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: AppColors.brand),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40.h),
              Text(
                languageProvider.getMessage(
                    'choose_one_option', "Choose one option"),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 17.sp,
                    ),
              ),
              SizedBox(height: 24.h),
              GestureDetector(
                onTap: () {
                  onboardingStepsProvider.selectedPayoutOption =
                      PayoutOption.upi;
                },
                child: AddPayoutOption(
                  label:
                      languageProvider.getMessage("add_upi_id_payout", "Add UPI ID"),
                  isSelected: onboardingStepsProvider.selectedPayoutOption ==
                      PayoutOption.upi,
                  imageUrl: "onboarding/upi_icon.png".cdn,
                ),
              ),
              SizedBox(height: 16.h),
              GestureDetector(
                onTap: () {
                  onboardingStepsProvider.selectedPayoutOption =
                      PayoutOption.bankDetails;
                },
                child: AddPayoutOption(
                  label: languageProvider.getMessage(
                      "add_bank_details_payout", "Add bank details"),
                  isSelected: onboardingStepsProvider.selectedPayoutOption ==
                      PayoutOption.bankDetails,
                  imageUrl: "onboarding/bank_details_icon.png".cdn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
