import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/bank_details/account_confirmation_tnc.dart';
import 'package:snabbit_runner/pages/signup/bank_details/bank_details_qna_review.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';

class UpiDetailsScreen extends StatefulWidget {
  static const String routeName = "/upi_details";
  const UpiDetailsScreen({super.key});

  @override
  State<UpiDetailsScreen> createState() => _UpiDetailsScreenState();
}

class _UpiDetailsScreenState extends State<UpiDetailsScreen> {
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
          Provider.of<OnboardingStepsProvider>(context, listen: false);
    }
    super.didChangeDependencies();
  }

  // Todo: Fix this condition
  bool canContinue() {
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        elevation: 6,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage("upi_details", "UPI Details"),
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
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed(AccountConfirmationTnC.routeName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
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
                      languageProvider.getMessage(
                          'upi_confirmation_primary_cta', "Yes"),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.n0,
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
                      languageProvider.getMessage(
                          'upi_confirmation_secondary_cta', "No"),
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
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40.h),
              Text(
                languageProvider.getMessage('confirm_account_message',
                    "Are you sure this is your account ?"),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                    ),
              ),
              SizedBox(height: 24.h),
              BankDetailsQnaReview(
                question: languageProvider.getMessage(
                    "account_holder_name", "Account holder name"),
                answer: onboardingStepsProvider.bankVerificationResponse
                        ?.validationResults?.registeredName ??
                    "N/A",
              ),
              SizedBox(height: 24.h),
              BankDetailsQnaReview(
                question: languageProvider.getMessage("upi_id", "UPI ID"),
                answer:
                    onboardingStepsProvider.bankVerificationResponse?.upiId ??
                        "N/A",
              ),
              SizedBox(height: 24.h),
              // TODO: Relationship section commented out as per requirements
              /*
              Text(
                languageProvider.getMessage("relationship_with_account_holder",
                    "Please confirm your relationship with the account holder "),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              SizedBox(height: 8.h),
              CustomDropdownV2<String>(
                onSelected: (val) {
                  // Todo: set the relationship in the userProfile
                },
                hintText: languageProvider.getMessage(
                  'select_relationship',
                  'Select Relationship',
                ),
                // Todo: Fetch the relationships from the API
                items: ['Husband', 'Father', 'Mother', 'Son', 'Daughter'],
                selectedItem: 'Husband',
              ),
              */
            ],
          ),
        ),
      ),
    );
  }
}
