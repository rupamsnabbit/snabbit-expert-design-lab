import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../providers/leave_model.dart';
import '../../services/runner_leave_http.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import '../drawer/long_leave.dart';
import '../elevated_button_with_loader.dart';

class LeavePending extends StatefulWidget {
  const LeavePending({super.key});

  @override
  State<LeavePending> createState() => _LeavePendingState();
}

class _LeavePendingState extends State<LeavePending> {
  bool init = true;
  late LeaveApplicationData leaveApplicationData;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      leaveApplicationData =
          Provider.of<LeaveApplicationData>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 20.h),
        SvgPicture.asset("assets/svgs/drawer/long-leave/underReview.svg"),
        SizedBox(height: 20.h),
        Text(
          languageProvider.getMessage(
            "leave_under_review",
            "Your application is under review",
          ),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (leaveApplicationData.currentLeaveApplication?.createdAt != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Text(
              "${languageProvider.getMessage("leave_submitted_on", "Application Submitted on")} ${formatSingleDate(leaveApplicationData.currentLeaveApplication?.createdAt)}",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.n60),
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Text(
            languageProvider.getMessage("leave_application_sent",
                "Your application for a long leave has been sent. Please wait for approval of leave."),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.n80),
          ),
        ),
        SizedBox(
          width: 1.sw,
          child: OutlinedButton(
            onPressed: () {
              leaveApplicationData.updateLeaveApplicationStep(
                  LeaveApplicationStep.cancelConfirmation);
            },
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.r50,
                side: const BorderSide(color: AppColors.n50),
                padding: EdgeInsets.symmetric(
                  vertical: 14.h,
                  horizontal: 20.w,
                )),
            child: Text(
              languageProvider.getMessage(
                "cancel_application",
                "Cancel application",
              ),
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }
}

class LeaveCancelConfirmation extends StatefulWidget {
  const LeaveCancelConfirmation({super.key});

  @override
  State<LeaveCancelConfirmation> createState() =>
      _LeaveCancelConfirmationState();
}

class _LeaveCancelConfirmationState extends State<LeaveCancelConfirmation> {
  bool init = true;
  bool loading = false;
  late LeaveApplicationData leaveApplicationData;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      leaveApplicationData =
          Provider.of<LeaveApplicationData>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return leaveApplicationData.currentLeaveApplication == null
        ? const Center(
            child: Text("Leave application not found"),
          )
        : loading
            ? SizedBox(
                height: 0.2.sh,
                child: const Center(child: CupertinoActivityIndicator()),
              )
            : leaveApplicationData.errorWhileApplyingLeave != null
                ? SizedBox(
                    height: 0.2.sh,
                    child: Center(
                      child: Text(
                        "${leaveApplicationData.errorWhileApplyingLeave}",
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20.h),
                      Text(
                        languageProvider.getMessage(
                            "are_you_sure_want_cancel_leave",
                            "Are you sure you want to cancel your application?"),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: 21.h),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.g40),
                              child: Text(
                                languageProvider.getMessage("no", "No"),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  Response? res;
                                  if (leaveApplicationData
                                          .currentLeaveApplication?.id !=
                                      null) {
                                    setState(() {
                                      loading = true;
                                    });
                                    res = await RunnerLeaveHTTP.cancelLeave(
                                        id: leaveApplicationData
                                            .currentLeaveApplication!.id);
                                  }
                                  setState(() {
                                    loading = false;
                                  });

                                  if (res != null && res.statusCode == 200) {
                                    if (mounted) {
                                      leaveApplicationData
                                          .getAllLeaveApplications();
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    }
                                  } else {
                                    if (mounted) {
                                      leaveApplicationData
                                          .updateErrorWhileApplyingLeave(
                                              languageProvider.getMessage("${res?.data?["errors"]?[0]?["message"]}", "Server error - ${res?.statusCode}"));
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    leaveApplicationData
                                        .updateErrorWhileApplyingLeave(
                                            "Something went wrong - $e");
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandInverted,
                                foregroundColor: AppColors.r50,
                              ),
                              child: Text(
                                languageProvider.getMessage("yes", "Yes"),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 20.h,
                      )
                    ],
                  );
  }
}
