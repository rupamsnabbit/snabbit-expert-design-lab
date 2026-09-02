import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/job_start_flow/job_rejection_warning_v1.dart';

import '../../utils/colors.dart';

class RequestToRejectV1 extends StatefulWidget {
  final VoidCallback? onAcceptJobTap;
  final VoidCallback? onRejectJobTap;

  const RequestToRejectV1({
    super.key,
    this.onAcceptJobTap,
    this.onRejectJobTap,
  });

  @override
  State<RequestToRejectV1> createState() => _RequestToRejectV1State();
}

class _RequestToRejectV1State extends State<RequestToRejectV1> {

  @override
  void initState() {
    super.initState();
    ClevertapSetup.logEvent(TrackingEvents.requestToRejectJobViewed, {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, provider, child) {
      return GestureDetector(
        onTap: () {
          ClevertapSetup.logEvent(
              TrackingEvents.requestToRejectJobButtonClicked, {});
          showJobRejectionWarningBottomSheetV1(
            context: context,
            onAcceptJobTap: widget.onAcceptJobTap,
            onRejectJobTap: widget.onRejectJobTap,
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38.h,
          margin: EdgeInsets.only(top: 10.h),
          alignment: Alignment.center,
          child: Text(
            provider.getMessage("request_to_deny", "Request To Deny"),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 18 / 13,
                  color: AppColors.r50,
                  decoration: TextDecoration.underline,
                  decorationThickness: 1.5.r,
                  decorationColor: AppColors.r50,
                ),
          ),
        ),
      );
    });
  }
}
