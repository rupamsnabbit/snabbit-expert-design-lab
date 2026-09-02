import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_page.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

class RunnerSuspended extends StatefulWidget {
  const RunnerSuspended({
    super.key,
  });

  @override
  State<RunnerSuspended> createState() => _RunnerSuspendedState();
}

class _RunnerSuspendedState extends State<RunnerSuspended> {
  bool init = true;

  bool loading = true;

  late LanguageProvider languageProvider;

  bool _expressInterestButtonTapped = false;
  bool _isLoading = false;

  Future<void> initProcess() async {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    init = false;
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    initProcess().then((_) {
      loading = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _onComeBackToWorkTapped() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await RunnerHttp.unsuspend();

      if (!mounted) return;

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 409)) {
        setState(() {
          _expressInterestButtonTapped = true;
          _isLoading = false;
        });

        ClevertapSetup.logEvent(
          TrackingEvents.expertWantsToJoinBack,
          {
            'action': 'success',
            'status_code': response.statusCode.toString(),
          },
        );

        final runnerRtDataProvider =
            Provider.of<RunnerRtDataProvider>(context, listen: false);
        runnerRtDataProvider.fetchDataNow().catchError((e) {
          MonitoringServiceHelper.logError(
            'unsuspend_refresh_failed',
            {'error': e.toString(), 'step': 'fetchDataNow'},
          );
        });

        final userProfileProvider =
            Provider.of<UserProfileProvider>(context, listen: false);
        userProfileProvider.runnersMeSetup();
      } else if (response != null && response.statusCode == 400) {
        setState(() {
          _expressInterestButtonTapped = true;
          _isLoading = false;
        });

        final data = response.data;
        final String reason = (data is Map)
            ? data['status']?.toString() ?? 'unknown'
            : 'non_json_body';
        final String message = (data is Map)
            ? data['message']?.toString() ?? 'unknown'
            : data?.toString() ?? 'unknown';

        ClevertapSetup.logEvent(
          TrackingEvents.expertWantsToJoinBack,
          {
            'action': 'denied',
            'status_code': '400',
            'reason': reason,
            'message': message,
          },
        );

        MonitoringServiceHelper.logWarning(
          'unsuspend_denied',
          {
            'status_code': 400,
            'reason': reason,
            'message': message,
          },
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        final errorData = response?.data;
        final String errorMessage = (errorData is Map)
            ? errorData['message']?.toString() ??
                errorData['detail']?.toString() ??
                ''
            : '';

        showSnackbar(
          context,
          errorMessage.isNotEmpty
              ? errorMessage
              : languageProvider.getMessage(
                  "something_went_wrong",
                  "Something went wrong. Please try again.",
                ),
        );

        ClevertapSetup.logEvent(
          TrackingEvents.expertWantsToJoinBack,
          {
            'action': 'failed',
            'status_code': response?.statusCode?.toString() ?? 'null',
            'error': 'request_failed',
          },
        );

        MonitoringServiceHelper.logError(
          'unsuspend_failed',
          {
            'status_code': response?.statusCode,
            'error': 'request_failed',
          },
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      showSnackbar(
        context,
        languageProvider.getMessage(
          "something_went_wrong",
          "Something went wrong. Please try again.",
        ),
      );

      ClevertapSetup.logEvent(
        TrackingEvents.expertWantsToJoinBack,
        {
          'action': 'failed',
          'status_code': 'null',
          'error': e.toString(),
        },
      );

      MonitoringServiceHelper.logError(
        'unsuspend_failed',
        {
          'error': e.toString(),
        },
      );
    }
  }

  /// Opens the same self-contained Aadhaar re-KYC flow as the drawer entry
  /// point. Refresh-on-success is owned by the flow itself
  /// (`AadhaarReverificationPage._confirmAndSubmit` → `onVerified` refreshes
  /// current_state + runners/me only on `verified`), so there's no post-return
  /// refresh here.
  void _onUpdateAadhaarTapped() {
    Navigator.of(context).pushNamed(AadhaarReverificationPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final userProfileProvider = context.watch<UserProfileProvider>();
    final isAadhaarRekyc = userProfileProvider.user?.isAadhaarRekyc == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 16.h),
        Icon(Icons.warning_amber_outlined, size: 150.r, color: AppColors.r40),
        SizedBox(height: 16.h),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: Text(
              isAadhaarRekyc
                  ? languageProvider.getMessage("account_suspended_aadhaar",
                      "Your account is suspended as Aadhaar verification is incomplete")
                  : languageProvider.getMessage(
                      "account_suspended", "Your documents are being verified"),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ),
        SizedBox(height: 16.h),
        if (isAadhaarRekyc)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AppColors.g40,
            ),
            onPressed: _isLoading ? null : _onUpdateAadhaarTapped,
            child: Text(
              languageProvider.getMessage("update_aadhaar", "Update Aadhaar"),
            ),
          )
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AppColors.g40,
            ),
            onPressed: (_expressInterestButtonTapped || _isLoading)
                ? null
                : _onComeBackToWorkTapped,
            child: _isLoading
                ? SizedBox(
                    width: 24.r,
                    height: 24.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.n0,
                    ),
                  )
                : _expressInterestButtonTapped
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0,
                                end: _expressInterestButtonTapped ? 1.0 : 0.0),
                            duration: Duration(milliseconds: 500),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Opacity(
                                  opacity: value,
                                  child: Icon(
                                    Icons.check,
                                    size: 24.r,
                                    color: AppColors.n0,
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            languageProvider.getMessage(
                                "request_submitted", "Request submitted"),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: AppColors.n0),
                          ),
                        ],
                      )
                    : Text(
                        languageProvider.getMessage(
                            "come_back_to_work", "Come Back to Work"),
                      ),
          ),
        SizedBox(height: 16.h),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.n80,
              side: BorderSide(
                color: AppColors.n80,
                width: 1.6.r,
              )),
          onPressed: _isLoading ? null : () => navigateToEarningsPage(context),
          child: _isLoading
              ? SizedBox(
                  width: 24.r,
                  height: 24.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.n0,
                  ),
                )
              : Text(
                  languageProvider.getMessage(
                      "go_to_earnings", "Go to Earnings"),
                  // style: ,
                ),
        )
      ],
    );
  }
}
