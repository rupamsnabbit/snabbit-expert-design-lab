import 'package:action_slider/action_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:vibration/vibration.dart';

enum SOSStep {
  preSOS,
  postSOS,
  falseSOS;

  String get eventState {
    switch (this) {
      case SOSStep.preSOS:
        return "pop_up";
      case SOSStep.postSOS:
        return "sos_triggered";
      case SOSStep.falseSOS:
        return "false_sos";
    }
  }
}

class SOSProvider with ChangeNotifier {
  String? phoneNumber;
  SOSStep sosStep = SOSStep.preSOS;
  bool loading = false;

  VoidCallback? onSOSTriggered;
  VoidCallback? onFalseAlarm;

  SOSProvider();

  void reset() {
    sosStep = SOSStep.preSOS;
    phoneNumber = null;
  }

  void setLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  void setStep(SOSStep val) {
    sosStep = val;
    notifyListeners();
  }

  void setPhoneNumber(String? val) {
    phoneNumber = val;
    notifyListeners();
  }

  String getPhoneNumber(){
    return phoneNumber ??
        RemoteConfigService.instance.getString(
            RemoteConfigKeys.expertSosContactNumber,
            defaultValue: "");
  }

  Future<bool> triggerSOS(BuildContext context) async {
    try {
      setLoading(true);
      final response = await RunnerHttp.runnerSOS();
      setLoading(false);

      if (response?.statusCode == 200) {
        final responseData = response?.data;
        final allowed = responseData?['allowed'];

        if (allowed == false) {
          ClevertapSetup.logEvent(
            TrackingEvents.sosBlocked,
            {"reason": "not_allowed_by_backend"},
          );
          MixpanelSetup.logEvent(
            TrackingEvents.sosTriggerFailed,
            {"reason": "not_allowed_by_backend"},
          );
          return false;
        }

        try {
          setPhoneNumber(responseData?['ph_no']);
        } catch (_) {}
        ClevertapSetup.logEvent(TrackingEvents.sosSuccessStateViewed, {});
        setStep(SOSStep.postSOS);
        Vibration.vibrate(duration: 500);
        onSOSTriggered?.call();
        return true;
      }
      MixpanelSetup.logEvent(
        TrackingEvents.sosTriggerFailed,
        {"reason": "non_200_response"},
      );
      return false;
    } catch (e) {
      setLoading(false);
      MixpanelSetup.logEvent(
        TrackingEvents.sosTriggerFailed,
        {"reason": "exception", "error": e.toString()},
      );
      return false;
    }
  }
}

class SOS extends StatefulWidget {
  const SOS({super.key});

  @override
  State<SOS> createState() => _SOSState();
}

class _SOSState extends State<SOS> {
  String? error;
  bool init = true;
  late LanguageProvider languageProvider;
  late SOSProvider sosProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      sosProvider = Provider.of<SOSProvider>(context, listen: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSlider.standard(
      actionThreshold: 1,
      actionThresholdType: ThresholdType.release,
      backgroundColor: AppColors.r50,
      toggleColor: AppColors.n0,
      action: (controller) async {
        await ClevertapSetup.logEvent(TrackingEvents.sosTriggered, {
          "sos": "SOS slider used",
          "source": "slider",
        });
        await sos();
      },
      icon: Icon(
        Icons.double_arrow,
        size: 25.sp,
        color: AppColors.r50,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 36.w),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                languageProvider.getMessage(
                    "slide_incase_emergency", "Slide to trigger SOS"),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: AppColors.r10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> sos() async {
    final success = await sosProvider.triggerSOS(context);
    if (!success && mounted) {
      showSnackbar(context, error ?? "An unexpected error has occurred.");
    }
  }
}

class SOSPopup extends StatefulWidget {
  const SOSPopup({
    super.key,
    this.autoTrigger = false,
  });

  /// When true, the SOS API will be triggered automatically once
  /// on first build instead of waiting for the user to use the slider.
  /// This flag preserves existing behaviour by default (false).
  final bool autoTrigger;

  @override
  State<SOSPopup> createState() => _SOSPopupState();
}

class _SOSPopupState extends State<SOSPopup> {
  bool init = true;
  late LanguageProvider languageProvider;
  late SOSProvider sosProvider;
  bool _autoTriggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      sosProvider = Provider.of<SOSProvider>(context, listen: true);
      sosProvider.reset();
      MixpanelSetup.logEvent(
        TrackingEvents.sosPopupViewed,
        {},
      );
    }

    // If autoTrigger is enabled, trigger SOS once when the popup is shown.
    if (widget.autoTrigger && !_autoTriggered) {
      _autoTriggered = true;
      // Schedule after current frame to avoid calling async work directly
      // in didChangeDependencies.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await sosProvider.triggerSOS(context);
      });
    }
  }

  Future<void> _launchDialer() async {
      final String phone = sosProvider.getPhoneNumber();
      await CallUtils.handleCallInitiation(phoneNumber: phone,callSourceLabel: "SOS",onFailure: (
          {e, st}) {
        MonitoringServiceHelper.logError("SOS_CALL_FAILED", {
          "error": e?.toString(),
          "stack_trace": st?.toString(),
        });
        ClevertapSetup.logEvent(
          TrackingEvents.failedToInitiateCallFromSOS,
          {},
        );
      });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 37.h),
        Container(
          // height: 59.r,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xffC72514),
              border: Border.all(
                color: AppColors.r20,
                width: 10.r,
              )),
          padding: EdgeInsets.all(20.r),
          child: Text(
            languageProvider.getMessage(
              'sos',
              'SOS',
            ),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 18.sp,
                  color: AppColors.n0,
                ),
          ),
        ),
        SizedBox(height: 31.h),
        if (sosProvider.loading == true)
          const Center(child: CupertinoActivityIndicator())
        else if (sosProvider.sosStep == SOSStep.preSOS)
          const SOS()
        else if (sosProvider.sosStep == SOSStep.postSOS)
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                languageProvider.getMessage(
                  'sos_triggered',
                  'SOS triggered',
                ),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 23.sp,
                      color: AppColors.n90,
                    ),
              ),
              SizedBox(height: 12.h),
              Text(
                languageProvider.getMessage(
                  'support_field_team_notified',
                  'Our Support & Field Operations team has been notified successfully',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontSize: 18.sp),
              ),
              SizedBox(height: 30.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: () {
                    ClevertapSetup.logEvent(
                      TrackingEvents.sosCallSupportClicked,
                      {
                        "phone_number_available":
                            sosProvider.phoneNumber != null,
                      },
                    );

                    _launchDialer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.g40,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.call,
                        color: AppColors.n0,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        languageProvider.getMessage(
                          'call_support',
                          'Call support',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 1.sw,
                child: OutlinedButton(
                  onPressed: () {
                    ClevertapSetup.logEvent(
                      TrackingEvents.sosFalseAlarmClicked,
                      {},
                    );

                    sosProvider.setStep(SOSStep.falseSOS);
                    ClevertapSetup.logEvent(
                      TrackingEvents.sosFalseAlarmConfirmationViewed,
                      {},
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.n60),
                    foregroundColor: AppColors.n80,
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      'false_alarm',
                      'False Alarm - No SOS',
                    ),
                  ),
                ),
              )
            ],
          )
        else if (sosProvider.sosStep == SOSStep.falseSOS)
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                languageProvider.getMessage(
                  'are_you_okay',
                  'Are you okay?',
                ),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 23.sp,
                      color: AppColors.n90,
                    ),
              ),
              SizedBox(height: 12.h),
              Text(
                languageProvider.getMessage(
                  'confirm_not_in_danger',
                  'Please confirm that you are not in danger.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontSize: 18.sp),
              ),
              SizedBox(height: 30.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: () {
                    ClevertapSetup.logEvent(
                      TrackingEvents.sosFalseAlarmConfirmed,
                      {},
                    );
                    sosProvider.onFalseAlarm?.call();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.g40,
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      'not_in_danger',
                      'I am not in danger',
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 1.sw,
                child: OutlinedButton(
                  onPressed: () {
                    ClevertapSetup.logEvent(
                      TrackingEvents.sosReturnedToPostSOS,
                      {},
                    );
                    sosProvider.setStep(SOSStep.postSOS);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.n60),
                    foregroundColor: AppColors.n80,
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      'go_back',
                      'Go back',
                    ),
                  ),
                ),
              )
            ],
          )
        else
          SizedBox(),
        SizedBox(height: 20.h),
      ],
    );
  }
}
