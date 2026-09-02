import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

class RiskRewardConfirmationV1 extends StatelessWidget {
  const RiskRewardConfirmationV1({
    super.key,
    required this.animationController,
    required this.animation,
  });

  final AnimationController animationController;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, languageProvider, _) {
      return Consumer<RunnerRtDataProvider>(
          builder: (context, runnerRtDataProvider, child) {
        return Column(
          children: [
            SizedBox(height: 24.h),
            Text(
              "Are you sure?",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: 12.h),
            RichText(
              text: TextSpan(
                text: "${languageProvider.getMessage(
                  'you_will_be_marked',
                  'You will be marked',
                )} ",
                children: [
                  TextSpan(
                    text: languageProvider.getMessage(
                      'early_logout',
                      'Early logout',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 16.sp,
                    ),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: 1.sw,
              child: ElevatedButton(
                onPressed: () async {
                  runnerRtDataProvider.setWaitForFetchData(true);
                  Response? response = await JobHttp.denyJob(data: {
                    "job_id": runnerRtDataProvider.jobId ?? -1,
                  });
                  if (response != null && response.statusCode == 200) {
                    stopAudio();
                  } else {
                    if (context.mounted) {
                      showSnackbar(
                        context,
                        "${response?.data ?? "Something went wrong. Please try again!"}",
                      );
                    }
                  }
                  ClevertapSetup.logEvent(TrackingEvents.denyJobButtonClicked, {
                    "action": "accept job button click",
                  });
                  runnerRtDataProvider.fetchDataNow();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.r40,
                ),
                child: Text(
                    "${languageProvider.getMessage("lose", "Lose")} ${formatIndianCurrency(anyValueToInt(runnerRtDataProvider.widgetInfo?.data?['deny_rate']))}"),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: 1.sw,
              child: OutlinedButton(
                onPressed: () {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.n80,
                  side: const BorderSide(color: AppColors.n50),
                ),
                child: Text(
                  languageProvider.getMessage(
                    'go_back',
                    'Go Back',
                  ),
                ),
              ),
            ),
            SizedBox(height: 44.h),
          ],
        );
      });
    });
  }
}
