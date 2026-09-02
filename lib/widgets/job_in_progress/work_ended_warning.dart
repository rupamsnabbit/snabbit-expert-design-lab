import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/main.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/job_in_progress/on_the_job.dart';
import 'package:snabbit_runner/widgets/support_popup.dart';

class WorkEndedWarning extends StatefulWidget {
  const WorkEndedWarning({super.key});

  @override
  State<WorkEndedWarning> createState() =>
      _WorkEndedWarningState();
}

class _WorkEndedWarningState
    extends State<WorkEndedWarning> {
  late LanguageProvider languageProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return CommonBottomSheetSetup(
        child: Column(
          children: [
            SizedBox(height: 8.h,),
            Image.asset(
              AssetConstants.workEndedWarning,
              height: 170.h,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10.w,
                vertical: 17.h,
              ),
              child: Text(
                languageProvider.getMessage("work_ended_while_ago",
                    "Your work ended a while ago."),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16.sp,
                ),
              ),
            ),
            Container(
              width: 1.sw,
              margin: EdgeInsets.symmetric(vertical: 8.h),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return const CommonBottomSheetSetup(
                        child: SupportPopup(
                          type: SupportType.PRIMARY,
                        ),
                      );
                    },
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.r40,
                  side: BorderSide(
                    color: AppColors.r40,
                    width: 2.r,
                  ),
                ),
                child: Text(
                  languageProvider.getMessage("need_help_text", "Need help"),
                ),
              ),
            ),
            Container(
              width: 1.sw,
              margin: EdgeInsets.symmetric(vertical: 8.h),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  languageProvider.getMessage("im_ok", "I'm OK"),
                ),
              ),
            ),
            SizedBox(
              height: 21.h,
            ),
          ],
        ));
  }
}

void showWorkEndedWarning(
    BuildContext context,
    Map<String, dynamic>? data,
    ) async {
  try {
    //checking if auto checkout is required
    if (data?[AppStrings.timeBasedAutoCheckout] == true) {
      //checking if checkout otp popup is open
      if (context.read<OnTheJobStateProvider>().checkoutForRunnerJobId ==
          data?[AppStrings.jobId]) {
        // if checkout otp popup is open we dismiss it
        Navigator.pop(context);
      }
      final prefs = await SharedPreferences.getInstance();
      //retrieving stored job id
      final checkedOutJob = prefs.getInt(AppStrings.jobIdForCheckoutWarning);
      //checking if new job id is not null and different from previous job id
      if (data?[AppStrings.jobId] != null &&
          data?[AppStrings.jobId] != checkedOutJob) {
        //store the current job id in shared preferences
        prefs.setInt(
            AppStrings.jobIdForCheckoutWarning, data?[AppStrings.jobId]);
        //display the auto checkout popup
        showModalBottomSheet(
            context: context,
            barrierColor: Colors.black.withOpacity(0.79),
            builder: (_) {
              return const WorkEndedWarning();
            });
      }
    }
  } catch (_) {}
}