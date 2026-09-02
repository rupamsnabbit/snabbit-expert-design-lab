import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/documents_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/bank_details/bank_details_uploader.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

class BankDetailsViewer extends StatefulWidget {
  final bool? allowEdit;
  final VoidCallback? onUpdate;

  /// When non-null, render bank fields from this snapshot instead of
  /// looking them up via [UserProfileProvider]. Lets callers (e.g. the
  /// webview navigate-handler) inject the runner profile they already
  /// hold, instead of relying on the modal route's inherited Provider
  /// chain.
  final UserProfile? user;

  const BankDetailsViewer({
    super.key,
    this.allowEdit = true,
    this.onUpdate,
    this.user,
  });

  @override
  State<BankDetailsViewer> createState() => _BankDetailsViewerState();
}

class _BankDetailsViewerState extends State<BankDetailsViewer> {
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  bool init = true;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      init = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? userProfileProvider.user;
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 8.h,
          ),
          Text(
            languageProvider.getMessage("bank_details", "Bank Details"),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.left,
          ),
          SizedBox(
            height: 8.h,
          ),
          if ((user?.bankAccountNumber ?? '').isNotEmpty)
            OnboardingQuestion(
              questionKey: "bank_account_number",
              questionDefault: "Bank account number",
              answer: Text(
                maskAccountNumber(user!.bankAccountNumber!),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  height: 20 / 15,
                  letterSpacing: -0.24,
                ),
              ),
              questionTextStyle:
              Theme.of(context).textTheme.labelMedium?.copyWith(
                height: 18 / 13,
                letterSpacing: -0.24,
                color: AppColors.n60,
              ),
              padding: EdgeInsets.symmetric(
                vertical: 10.h,
                horizontal: 0.w,
              ),
            ),
          if ((user?.bankAccountName ?? '').isNotEmpty)
            OnboardingQuestion(
              questionKey: "account_holder_name",
              questionDefault: "Account holder name",
              answer: Text(
                user!.bankAccountName!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  height: 20 / 15,
                  letterSpacing: -0.24,
                ),
              ),
              questionTextStyle:
              Theme.of(context).textTheme.labelMedium?.copyWith(
                height: 18 / 13,
                letterSpacing: -0.24,
                color: AppColors.n60,
              ),
              padding: EdgeInsets.symmetric(
                vertical: 10.h,
                horizontal: 0.w,
              ),
            ),
          if ((user?.bankIfscCode ?? '').isNotEmpty)
            OnboardingQuestion(
              questionKey: "ifsc_code",
              questionDefault: "IFSC Code",
              answer: Text(
                user!.bankIfscCode!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  height: 20 / 15,
                  letterSpacing: -0.24,
                ),
              ),
              questionTextStyle:
              Theme.of(context).textTheme.labelMedium?.copyWith(
                height: 18 / 13,
                letterSpacing: -0.24,
                color: AppColors.n60,
              ),
              padding: EdgeInsets.symmetric(
                vertical: 10.h,
                horizontal: 0.w,
              ),
            ),
          SizedBox(
            height: 14.h,
          ),
          if (widget.allowEdit == true)
            Container(
              width: 1.sw,
              margin: EdgeInsets.only(bottom: 16.h),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    side: BorderSide(
                      color: AppColors.brand,
                      width: 1.r,
                    ),
                  ),
                  side: BorderSide(
                    color: AppColors.brand,
                    width: 1.r,
                  ),
                ),
                onPressed:widget.onUpdate,
                child: Text(
                  languageProvider.getMessage(
                    'update_details',
                    "Update details",
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                languageProvider.getMessage(
                  'ok',
                  "OK",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
