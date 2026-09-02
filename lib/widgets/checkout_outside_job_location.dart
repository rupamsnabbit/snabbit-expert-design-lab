import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/main.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/job_in_progress/on_the_job.dart';

class CheckoutOutsideJobLocation extends StatefulWidget {
  const CheckoutOutsideJobLocation({super.key});

  @override
  State<CheckoutOutsideJobLocation> createState() =>
      _CheckoutOutsideJobLocationState();
}

class _CheckoutOutsideJobLocationState
    extends State<CheckoutOutsideJobLocation> {
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
        child: Padding(
      padding: EdgeInsets.symmetric(vertical: 21.h),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: 16.h,
            ),
            child: Image.asset(
              AssetConstants.checkoutOutsideJobLocation,
              height: 170.h,
            ),
          ),
          Text(
            "${languageProvider.getMessage("warning", "Warning")}!",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10.w,
              vertical: 12.h,
            ),
            child: Text(
              languageProvider.getMessage("checkout_otp_warning_1",
                  "You are away from the job location.\nYou have been checked out."),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 18.sp,
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
                languageProvider.getMessage("understood", "Understood"),
              ),
            ),
          )
        ],
      ),
    ));
  }
}

void showCheckoutWarning(
  BuildContext context,
  Map<String, dynamic>? data,
) async {
  try {
    //checking if auto checkout is required
    if (data?[AppStrings.autoCheckout] == true) {
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
              return const CheckoutOutsideJobLocation();
            });
      }
    }
  } catch (_) {}
}
