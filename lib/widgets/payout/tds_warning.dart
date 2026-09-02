import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/upload_documents/upload_pan_modal_sheet_v2.dart';

class TdsWarning extends StatefulWidget {
  const TdsWarning({
    super.key,
  });

  @override
  State<TdsWarning> createState() => _TdsWarningState();
}

class _TdsWarningState extends State<TdsWarning> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;

  //message may be in RichText in the future
  late Widget message;
  late Widget actionItems;

  @override
  void didChangeDependencies() {
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: true);
    _initializeUI();
    super.didChangeDependencies();
  }

  void _initializeUI() {
    if (userProfileProvider.user?.panCardUnavailable == true) {
      message = Text(
        languageProvider.getMessage(
          "tds_warning_pan_missing",
          "20% of TDS will be deducted from your earnings if you fail to provide PAN card before the 31st of March 2025",
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.n80,
              fontSize: 16.sp,
            ),
      );
      actionItems = Row(
        children: [
          Expanded(
            child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppColors.brand,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r))),
                onPressed: () {},
                child: Text(
                  languageProvider.getMessage(
                    "cancel",
                    "Cancel",
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.brand,
                      ),
                )),
          ),
          SizedBox(
            width: 8.w,
          ),
          Expanded(
            child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) {
                      return const UploadPanModalSheetV2();
                    },
                  );
                },
                child: Text(
                  languageProvider.getMessage(
                    "upload_pan",
                    "Upload Pan",
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.n0,
                      ),
                )),
          ),
        ],
      );
    } else if (userProfileProvider.user?.panAadharLinked == false) {
      message = Text(
        languageProvider.getMessage(
          "tds_warning_pan_aadhaar_not_linked",
          "20% TDS is applicable on your earnings since your PAN and Aadhar are not linked",
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.n80,
              fontSize: 16.sp,
            ),
      );

      actionItems = SizedBox(
        width: 1.sw,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            languageProvider.getMessage(
              "i_understand",
              "I understand",
            ),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.n0,
                ),
          ),
        ),
      );
    } else {
      message = Text(
        languageProvider.getMessage(
          "tds_normal_message",
          "1% TDS is applicable on every job done, according to government regulations.",
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.n80,
              fontSize: 16.sp,
            ),
      );

      actionItems = SizedBox(
        width: 1.sw,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            languageProvider.getMessage(
              "i_understand",
              "I understand",
            ),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.n0),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 24.h),
        Text(
          languageProvider.getMessage(
            "payout_tds_warning",
            "Tax Deductible at Source (TDS)",
          ),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(
          height: 18.h,
        ),
        message,
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: actionItems,
        ),
      ],
    );
  }
}
