import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/job_start_flow/final_deallocation_warning_v1.dart';
import 'package:snabbit_runner/widgets/job_start_flow/first_deallocation_warning_v1.dart';

/// Displays [JobRejectionWarningV1] in a modal bottom sheet.
void showJobRejectionWarningBottomSheetV1({
  required BuildContext context,
  VoidCallback? onAcceptJobTap,
  VoidCallback? onRejectJobTap,
}) {
  showModalBottomSheet<JobRejectionWarningActionV1>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.n0,
    builder: (_) {
      return SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
          child: const CommonBottomSheetSetup(
            horizontalPadding: 0,
            bgColor: Colors.transparent,
            showDragHandle: false,
            bottomPadding: 0,
            child: JobRejectionWarningV1(),
          ),
        ),
      );
    },
  ).then((value) {
    if (value == JobRejectionWarningActionV1.acceptJob) {
      onAcceptJobTap?.call();
      ClevertapSetup.logEvent(TrackingEvents.requestToRejectJobAccepted, {});
    } else if (value == JobRejectionWarningActionV1.rejectJob) {
      onRejectJobTap?.call();
      ClevertapSetup.logEvent(TrackingEvents.requestToRejectJobRejected, {});
    }
  });
}

enum JobRejectionWarningActionV1 {
  acceptJob,
  rejectJob,
}

/// Bottom-sheet UI warning a runner before rejecting a job.
class JobRejectionWarningV1 extends StatefulWidget {
  const JobRejectionWarningV1({
    super.key,
  });

  @override
  State<JobRejectionWarningV1> createState() => _JobRejectionWarningV1State();
}

class _JobRejectionWarningV1State extends State<JobRejectionWarningV1> {
  bool init = true;

  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFF9999),
            Color(0xFFFFE1E0),
            Color(0xFFFFFFFF),
          ],
          stops: [0, 0.20745, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            languageProvider: languageProvider,
            runnerRtDataProvider: runnerRtDataProvider,
          ),
          _ActionSection(
            languageProvider: languageProvider,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final LanguageProvider languageProvider;
  final RunnerRtDataProvider runnerRtDataProvider;
  const _Header({
    required this.languageProvider,
    required this.runnerRtDataProvider,
  });

  @override
  Widget build(BuildContext context) {
    int deallocationCount;
    DeallocationWarningType warningType;
    try {
      deallocationCount =
          runnerRtDataProvider.widgetInfo?.data?['deallocation_count'] ?? 0;
      warningType = DeallocationWarningType.fromKey(
          runnerRtDataProvider.widgetInfo?.data?['deallocation_warning_type']);
    } catch (e) {
      deallocationCount = 0;
      warningType = DeallocationWarningType.none;
    }
    return deallocationCount < 1
        ? FirstDeallocationWarningV1(
            languageProvider: languageProvider,
            warningType: warningType,
          )
        : FinalDeallocationWarningV1(
            languageProvider: languageProvider,
            warningType: warningType,
          );
  }
}

class _ActionSection extends StatelessWidget {
  final LanguageProvider languageProvider;
  const _ActionSection({
    required this.languageProvider,
  });

  String get _acceptJobCta {
    return languageProvider.getMessage(
      'accept_job',
      'Accept Job',
    );
  }

  String get _rejectJobCta {
    return languageProvider.getMessage(
      'deny_job',
      'Deny Job',
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 1.sw,
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 47.h,
            width: 1.sw,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, JobRejectionWarningActionV1.acceptJob);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.g40,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: Text(
                _acceptJobCta,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.n0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          InkWell(
            onTap: () {
              Navigator.pop(context, JobRejectionWarningActionV1.rejectJob);
            },
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16.r,
                    color: AppColors.r50,
                  ),
                  SizedBox(width: 4.w),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _rejectJobCta,
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.r50,
                          decoration: TextDecoration.underline,
                          decorationThickness: 1.5.r,
                          decorationColor: AppColors.r50,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
