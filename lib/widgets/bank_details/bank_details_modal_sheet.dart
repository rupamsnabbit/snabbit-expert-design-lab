import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/bank_details/bank_details_uploader.dart';
import 'package:snabbit_runner/widgets/bank_details/bank_details_viewer.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

class BankDetailsModalSheet extends StatefulWidget {
  final bool? allowEdit;

  /// Optional injected runner profile. Forwarded to [BankDetailsViewer]
  /// so the view-mode renders even when Provider lookup inside the modal
  /// route returns null (e.g. when opened from the webview navigate
  /// handler via the global navigator key).
  final UserProfile? user;

  const BankDetailsModalSheet({super.key, this.allowEdit = true, this.user});

  @override
  State<BankDetailsModalSheet> createState() => _BankDetailsModalSheetState();
}

class _BankDetailsModalSheetState extends State<BankDetailsModalSheet> {
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  bool init = true;
  bool loading = false;
  String? error;
  bool isEditing = false;

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

  bool canContinue() {
    if (userProfileProvider.user?.bankAccountNumber?.isNotEmpty == true &&
        userProfileProvider.user?.bankIfscCode?.length == 11 &&
        userProfileProvider.user?.bankVerified == true &&
        userProfileProvider.user?.otherDetails!.filledItrLast2Years != null) {
      return true;
    } else {
      return false;
    }
  }

  void onContinue() async {
    await userProfileProvider.runnerRegistrationAndErrorHandler(
      context: context,
      navigateNext: false,
      onSuccess: () {
        userProfileProvider.runnersMeSetup();
        Navigator.pop(context);
      },
      onError: (errorMessage) {
        userProfileProvider.error = errorMessage;
        // showSnackbar(context, errorMessage ?? "Something went wrong");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonBottomSheetSetup(
      horizontalPadding: 0,
      child: !isEditing
          ? BankDetailsViewer(
              allowEdit: widget.allowEdit,
              user: widget.user,
              onUpdate: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                    context, '/add_bank_or_upi_details');
              },
            )
          : Column(
              children: [
                SizedBox(
                  height: 24.h,
                ),
                Text(
                  languageProvider.getMessage(
                    "bank_details",
                    "Enter Bank details",
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(
                  height: 18.h,
                ),
                const BankDetailsUploader(),
                SizedBox(
                  height: 20.h,
                ),
                if (userProfileProvider.user?.bankVerified == true)
                  Container(
                    width: 1.sw,
                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand),
                      onPressed:
                          canContinue() && userProfileProvider.loading != true
                              ? onContinue
                              : null,
                      child: loading
                          ? const CupertinoActivityIndicator()
                          : Text(
                              languageProvider.getMessage(
                                'continue',
                                "Continue",
                              ),
                            ),
                    ),
                  ),
                SizedBox(
                  height: 16.h,
                ),
              ],
            ),
    );
  }
}
