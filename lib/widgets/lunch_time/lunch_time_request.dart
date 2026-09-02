import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/lunch_time/lunch_time_refusal.dart';
import 'package:snabbit_runner/services/lunch_http.dart';

import '../../utils/common_methods.dart';

class LunchTimeRequest extends StatefulWidget {
  final VoidCallback? onPositive;
  final VoidCallback? onNegative;

  const LunchTimeRequest({
    Key? key,
    this.onPositive,
    this.onNegative,
  }) : super(key: key);

  @override
  State<LunchTimeRequest> createState() => _LunchTimeRequestState();
}

class _LunchTimeRequestState extends State<LunchTimeRequest> {
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    runnerRtDataProvider =
        Provider.of<RunnerRtDataProvider>(context, listen: true);
  }

  Future<void> executeDecision(bool takeBreak) async {
    //enable loading view
    runnerRtDataProvider.setWaitForFetchData(true);

    try {
      //1) call an api to communicate users willingness to take a lunch break
      Response? response;
      if (takeBreak) {
        response = await LunchHttp.acceptLunch();
      } else {
        response = await LunchHttp.denyLunch();
      }

      if (response != null && response.statusCode == 200) {
        // Success case
        // debugPrint("Successfully communicated lunch decision: ${response.data}");
      } else {
        if (takeBreak) {
          if (mounted) {
            showSnackbar(context, 'Break acceptance failed. Please try again');
          }
        } else {
          if (mounted) {
            showSnackbar(context, 'Break denial failed. Please try again');
          }
        }
          // debugPrint("Error in lunch decision: ${response?.statusCode}");
      }
    } catch (e) {
      if (takeBreak) {
        if (mounted) {
          showSnackbar(context, 'Break acceptance failed. Please try again');
        }
      } else {
        if (mounted) {
          showSnackbar(context, 'Break denial failed. Please try again');
        }
      }
      // debugPrint("Exception in lunch decision: $e");
    } finally {
      //2) call fetchDataNow()
      runnerRtDataProvider.fetchDataNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return runnerRtDataProvider.waitForFetchData
        ? const Center(
            child: CupertinoActivityIndicator(),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 24.h),
              // Lunch time image
              Image.asset(
                AssetConstants.lunchTime,
                width: 106.w,
                height: 106.h,
              ),
              SizedBox(height: 24.h),
              // LUNCH TIME text
              Text(
                languageProvider.getMessage(
                  'lunch_time',
                  'LUNCH TIME',
                ),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              // Action buttons
              Row(
                children: [
                  // "I don't need a break" button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (widget.onNegative != null) {
                          widget.onNegative!();
                        } else {
                          showLunchTimeRefusalBottomSheet(
                            context,
                            onPositive: () async {
                              executeDecision(false);
                              Navigator.pop(context);
                            },
                            onNegative: () {
                              Navigator.pop(context);
                            },
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.r50),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        languageProvider.getMessage(
                          'i_dont_need_a_break',
                          "I don't need a break",
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.r50,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // "Take break" button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (widget.onPositive != null) {
                          widget.onPositive!();
                        } else {
                          executeDecision(true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.g40,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        languageProvider.getMessage(
                          'take_break',
                          'Take break',
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.n0,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
  }
}

void showLunchTimeRequestBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16.r),
      ),
    ),
    builder: (context) => CommonBottomSheetSetup(
      child: LunchTimeRequest(
        onPositive: () {},
        onNegative: () {
          Navigator.pop(context);
          showLunchTimeRefusalBottomSheet(context);
        },
      ),
    ),
  );
}
