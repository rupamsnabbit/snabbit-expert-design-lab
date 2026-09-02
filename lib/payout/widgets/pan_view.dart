import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/upload_documents/upload_pan_modal_sheet_v2.dart';

class PayoutPanView extends StatefulWidget {
  const PayoutPanView({super.key});

  @override
  State<PayoutPanView> createState() => _PayoutPanViewState();
}

class _PayoutPanViewState extends State<PayoutPanView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider = Provider.of<UserProfileProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.sw,
      padding: EdgeInsets.only(top: 20.h),
      child: OutlinedButton(
        onPressed: () {
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              constraints: BoxConstraints(
                maxHeight: 0.7.sh,
              ),
              builder: (ctx) {
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom),
                  child: const UploadPanModalSheetV2(),
                );
              });
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          backgroundColor: AppColors.n0,
          side: const BorderSide(color: AppColors.n40),
        ),
        child: userProfileProvider.user?.isPanVerified ==
            true ? Text(
          languageProvider.getMessage(
            'view_pan_details',
            'View PAN details',
          ),
        ) : Text(
            languageProvider.getMessage(
              'upload_pan_details',
              'Upload PAN Details',
            )
        ),
      ),
    );
  }
}
