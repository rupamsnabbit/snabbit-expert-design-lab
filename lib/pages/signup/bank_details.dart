import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/bank_details/bank_details_uploader.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import '../../widgets/common_app_bar.dart';
import '../../utils/common_methods.dart';

class BankDetails extends StatefulWidget {
  static const String routeName = "bank_details";

  const BankDetails({super.key});

  @override
  State<BankDetails> createState() => _BankDetailsState();
}

class _BankDetailsState extends State<BankDetails> {
  bool init = true;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      init = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: userProfileProvider.loading == true ? const SizedBox() : Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onContinue,
            child: Text(
              languageProvider.getMessage(
                'skip',
                'Skip',
              ),
            ),
          ),
        ),
      ),
      persistentFooterButtons: [
        if (userProfileProvider.user?.bankVerified == true)
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: canContinue() && !userProfileProvider.loading
                ? onContinue
                : null,
            child: userProfileProvider.loading
                ? const CupertinoActivityIndicator()
                : Text(
                    languageProvider.getMessage(
                      "continue",
                      "Continue",
                    ),
                  ),
          ),
        ),
      ],
      body: userProfileProvider.loading ? Center(child: CupertinoActivityIndicator(),) : SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProgressIndicatorAtTop(value: 7),
              Gap.gap32h,
              const OnboardingPageHeader(
                titleKey: 'bank_details_title',
                titleDefault: 'Bank details',
                subtitleKey: 'bank_details_subtitle',
                subtitleDefault: 'Please share your ID information',
              ),
              Gap.gap32h,
              const BankDetailsUploader(),
            ],
          ),
        ),
      ),
    );
  }

  bool canContinue() {
    if (userProfileProvider.user?.bankAccountNumber?.isNotEmpty == true &&
        userProfileProvider.user?.bankIfscCode?.length == 11 &&
        userProfileProvider.user?.bankVerified == true &&
        userProfileProvider.user?.otherDetails!.filledItrLast2Years?.value != null
  ) {
      return true;
    } else {
      return false;
    }
  }

  void onContinue() async {
    await userProfileProvider.runnerRegistrationAndErrorHandler(
      context: context,
      onError: (errorMessage) {
        showSnackbar(context, errorMessage ?? "Something went wrong");
      },
    );
  }
}
