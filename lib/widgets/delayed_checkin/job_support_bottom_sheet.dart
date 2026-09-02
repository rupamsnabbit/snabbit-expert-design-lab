import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/job_support/job_support_models.dart';
import '../../providers/language_provider.dart';
import '../../services/globals.dart';
import '../../services/iot/http/delayed_checkin_http.dart';
import '../../services/remote_config/remote_config_keys.dart';
import '../../services/remote_config/remote_config_service.dart';
import '../../services/runner_http.dart';
import '../../services/analytics/job_lifecycle_analytics.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import '../../utils/top_snack_bar.dart';
import '../../utils/tracking_events.dart';

class JobSupportBottomSheet extends StatefulWidget {
  final JobSupportConfig config;
  final LanguageProvider languageProvider;
  final int runnerJobId;
  final int jobId;
  final int runnerId;
  final String? widgetName;

  const JobSupportBottomSheet({
    super.key,
    required this.config,
    required this.languageProvider,
    required this.runnerJobId,
    required this.jobId,
    required this.runnerId,
    this.widgetName,
  });

  @override
  State<JobSupportBottomSheet> createState() => _JobSupportBottomSheetState();

  /// Fetches app config, validates IDs, then shows this sheet.
  /// Callers pass [runnerId] from their UserProfileProvider.
  static Future<void> show(
    BuildContext context, {
    required LanguageProvider languageProvider,
    required Map<String, dynamic>? widgetData,
    String? widgetName,
    required int runnerId,
  }) async {
    JobLifecycleAnalytics.logEvent(
        TrackingEvents.jobSupportCtaClicked, const {});
    // Use app config fetched at startup — no retry (aligns with #421).
    final config = GlobalState().appConfig?.jobSupportConfig;
    if (!context.mounted) return;
    if (config == null) {
      JobLifecycleAnalytics.logEvent(
          TrackingEvents.jobSupportConfigMissing, const {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(languageProvider.getMessage(
          'support_details_not_found',
          'Support details not found',
        )),
      ));
      return;
    }
    final runnerJobId = anyValueToInt(widgetData?['runner_job_id']) ?? -1;
    final jobId = anyValueToInt(widgetData?['job_id']) ?? -1;
    if (runnerJobId <= 0 || jobId <= 0 || runnerId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(languageProvider.getMessage(
          'support_details_not_found',
          'Support details not found',
        )),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => JobSupportBottomSheet(
        config: config,
        languageProvider: languageProvider,
        runnerJobId: runnerJobId,
        jobId: jobId,
        runnerId: runnerId,
        widgetName: widgetName,
      ),
    );
  }
}

class _JobSupportBottomSheetState extends State<JobSupportBottomSheet> {
  String? _selectedOptionId;
  String? _helplineNumber;
  bool _loading = false;
  late final Future<String?> _helplineFuture;
  late final bool _ameyoEnabled;

  @override
  void initState() {
    super.initState();
    _ameyoEnabled = RemoteConfigService.instance.getBool(
      RemoteConfigKeys.ameyoSupport,
      defaultValue: false,
    );
    if (_ameyoEnabled) {
      _helplineFuture = Future.value(null);
    } else {
      _helplineFuture = _fetchHelplineNumber()
        ..then((number) {
          if (mounted && number != null) {
            setState(() => _helplineNumber = number);
          }
        });
    }
  }

  Future<String?> _fetchHelplineNumber() async {
    try {
      final response = await RunnerHttp.runnersMeHelpline(
        queryParameters:
            widget.widgetName != null ? {'type': widget.widgetName} : null,
      );
      if (response != null && response.statusCode == 200) {
        return response.data['ph_no']?.toString();
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'fetchHelplineNumber',
        fatal: false,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lp = widget.languageProvider;
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4.h,
                width: 36.w,
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              lp.getMessage('call_support_partner', 'Call Support Partner'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 4.h),
            Text(
              lp.getMessage(
                'select_option_below',
                'Select an option below and place call',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.n60),
            ),
            SizedBox(height: 20.h),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 1.6,
              children: widget.config.options.map((option) {
                final isSelected = _selectedOptionId == option.id;
                final label = lp.getMessage(
                  option.label.key,
                  option.label.defaultText,
                );
                return GestureDetector(
                  onTap: () => setState(() => _selectedOptionId = option.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.r10 : AppColors.n0,
                      border: Border.all(
                        color: isSelected ? AppColors.r50 : AppColors.n30,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.all(10.r),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (option.iconUrl != null &&
                            option.iconUrl!.isNotEmpty)
                          SizedBox(
                            width: 28.w,
                            height: 28.w,
                            child: CachedNetworkImage(
                              imageUrl: option.iconUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) =>
                                  Icon(Icons.support_agent, size: 24.r),
                            ),
                          ),
                        SizedBox(height: 6.h),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.n90,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedOptionId != null ? AppColors.n90 : AppColors.n30,
                  disabledBackgroundColor: AppColors.n30,
                ),
                onPressed:
                    _selectedOptionId == null || _loading ? null : _onSubmit,
                child: _loading
                    ? SizedBox(
                        height: 20.r,
                        width: 20.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.n0,
                        ),
                      )
                    : Text(
                        lp.getMessage('submit', 'Submit'),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: AppColors.n0),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (_selectedOptionId == null) return;
    final matches =
        widget.config.options.where((o) => o.id == _selectedOptionId);
    if (matches.isEmpty) return;
    final selectedOption = matches.first;

    JobLifecycleAnalytics.logEvent(TrackingEvents.jobSupportSubmitted, {
      'disposition_tag': _selectedOptionId,
      'runner_job_id': widget.runnerJobId,
    });

    setState(() => _loading = true);
    final response = await DelayedCheckinHttp.submitSupportDisposition(
      runnerJobId: widget.runnerJobId,
      jobId: widget.jobId,
      runnerId: widget.runnerId,
      dispositionTag: _selectedOptionId!,
      dispositionMessage: selectedOption.label.defaultText,
    );
    if (!mounted) return;

    final isSuccess = response?.statusCode == 200;
    JobLifecycleAnalytics.logEvent(
      isSuccess
          ? TrackingEvents.jobSupportSubmissionSuccess
          : TrackingEvents.jobSupportSubmissionFailed,
      {'disposition_tag': _selectedOptionId, 'status_code': response?.statusCode},
    );

    if (_ameyoEnabled) {
      final message = response?.data?['message'] as String? ??
          (isSuccess
              ? widget.languageProvider.getMessage(
                  'call_will_be_connected', 'Your call will be connected shortly')
              : widget.languageProvider.getMessage(
                  'could_not_process_request', 'Could not process your request'));
      Navigator.pop(context);
      showTopSnackBar(
        message: message,
        isSuccess: isSuccess,
      );
      return;
    }

    // Non-ameyo: launch the dialler using the pre-fetched helpline number.
    String? phone = _helplineNumber;
    if (phone == null || phone.isEmpty) {
      phone = await _helplineFuture;
      if (!mounted) return;
    }

    Navigator.pop(context);
    if (phone != null && phone.isNotEmpty) {
      JobLifecycleAnalytics.logEvent(
          TrackingEvents.jobSupportCallInitiated, {'phone': phone});
      launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
    } else {
      showTopSnackBar(
        message: widget.languageProvider
            .getMessage('helpline_unavailable', 'Helpline number not available'),
        isSuccess: false,
      );
    }
  }
}
