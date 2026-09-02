import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/services/job_http.dart';

/// Rate card v1: emergency logout via [JobHttp.runnerLogout] with
/// `emergency_logout: true` (legacy shift/logout). No gamification overlay.
class EmergencyLogoutConfirmationV1 extends StatefulWidget {
  final int? emergencyLogoutsAvailable;

  const EmergencyLogoutConfirmationV1({
    super.key,
    this.emergencyLogoutsAvailable,
  });

  @override
  State<EmergencyLogoutConfirmationV1> createState() =>
      _EmergencyLogoutConfirmationV1State();
}

class _EmergencyLogoutConfirmationV1State
    extends State<EmergencyLogoutConfirmationV1> {
  bool _init = true;
  bool _loading = false;
  late LanguageProvider _languageProvider;
  late RunnerRtDataProvider _runnerRt;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) {
      _init = false;
      _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      _runnerRt = Provider.of<RunnerRtDataProvider>(context, listen: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? SizedBox(
            height: 0.2.sh,
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    AssetConstants.emergencyBeacon,
                    width: 32.w,
                    height: 32.h,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "${widget.emergencyLogoutsAvailable ?? 0} ${_languageProvider.getMessage(
                      'available',
                      'Available',
                    )}",
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.n90,
                          fontSize: 32.r,
                        ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Text(
                _languageProvider.getMessage(
                  'are_you_sure',
                  'Are you sure?',
                ),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.n90,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.close,
                        size: 20.sp,
                        color: AppColors.r50,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _languageProvider.getMessage(
                          'lose_ming_today',
                          'You will lose MinG today',
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.n80,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.close,
                        size: 20.sp,
                        color: AppColors.r50,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _languageProvider.getMessage(
                          'attendance_marked_absent',
                          'Your attendance will be marked Absent',
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.n80,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.check,
                        size: 20.sp,
                        color: AppColors.n80,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _languageProvider.getMessage(
                          'paid_for_completed_jobs',
                          'You will get paid for the jobs completed',
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.n80,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _loading = true;
                        });
                        final Response? response = await JobHttp.runnerLogout(
                          data: {'emergency_logout': true},
                        );
                        if (!mounted) return;
                        setState(() {
                          _loading = false;
                        });
                        if (response != null && response.statusCode == 200) {
                          setState(() {
                            _error = null;
                          });
                          await _runnerRt.fetchDataNow();
                          unawaited(_runnerRt.refreshEmergencyLogoutAvailability());
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } else {
                          setState(() {
                            _error = 'Something went wrong';
                          });
                          Future.delayed(const Duration(seconds: 2)).then((_) {
                            if (mounted) {
                              setState(() {
                                _error = null;
                              });
                            }
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.g40,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        _languageProvider.getMessage(
                          'yes_logout',
                          'Yes, log me out',
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.n0,
                            ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.n50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        _languageProvider.getMessage(
                          'no',
                          'No',
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.n80,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Text(
                    _error ?? 'Something went wrong',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.r40),
                  ),
                ),
              SizedBox(height: 20.h),
            ],
          );
  }
}

void showEmergencyLogoutConfirmationV1(
  BuildContext context, {
  int? emergencyLogoutsAvailable,
}) {
  showModalBottomSheet<bool?>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16.r),
      ),
    ),
    builder: (context) => CommonBottomSheetSetup(
      child: EmergencyLogoutConfirmationV1(
        emergencyLogoutsAvailable: emergencyLogoutsAvailable,
      ),
    ),
  ).then((value) {
    if (value == true) return;
    if (!context.mounted) return;
    context.read<RunnerRtDataProvider>().fetchDataNow();
  });
}
