import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../providers/leave_model.dart';
import '../../services/runner_leave_http.dart';
import '../../utils/app_strings.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../circular_checkbox.dart';
import '../drawer/long_leave.dart';

class LeaveReason extends StatefulWidget {
  const LeaveReason({super.key});

  @override
  State<LeaveReason> createState() => _LeaveReasonState();
}

class _LeaveReasonState extends State<LeaveReason> {
  bool init = true;
  late LanguageProvider languageProvider;
  late LeaveApplicationData leaveApplicationData;
  List<String> fallBackReasons = [
    "something_urgent_came_up",
    "health_related_issues",
    "personal_or_family_emergency",
    "religious_or_cultural_matter",
    "other",
  ];
  TextEditingController otherReasonTextController = TextEditingController();

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      leaveApplicationData =
          Provider.of<LeaveApplicationData>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    otherReasonTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 32.h),
        Text(
          languageProvider.getMessage("reason_leave", "Reason for leave"),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 24.h),
        Column(
          children: fallBackReasons.map((e) {
            return Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: GestureDetector(
                onTap: () async {
                  leaveApplicationData.updateReason(e);
                },
                child: Row(
                  children: [
                    CircularCheckbox(
                      value: leaveApplicationData.reason == e,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        languageProvider.getMessage(e, e),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (leaveApplicationData.reason == AppStrings.otherReasonString)
          TextField(
            controller: otherReasonTextController,
            onChanged: (val) {
              if (val.isEmpty) {
                leaveApplicationData.updateOtherReason(null);
              } else {
                leaveApplicationData.updateOtherReason(val);
              }
            },
            maxLines: 3,
            maxLength: 250,
            decoration: InputDecoration(
              counterText: "",
              hintText: "Please let us know the reason here",
              labelStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.n70,
                    fontSize: 15.sp,
                  ),
              border: const OutlineInputBorder(),
            ),
          ),
        SizedBox(height: 8.h),
        if (leaveApplicationData.errorWhileApplyingLeave != null)
          Text(
            "${leaveApplicationData.errorWhileApplyingLeave}",
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.r50),
          ),
        SizedBox(height: 8.h),
        SizedBox(
          width: double.infinity,
          height: 54.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
            ),
            onPressed: leaveApplicationData.reason == null ||
                    (leaveApplicationData.reason ==
                            AppStrings.otherReasonString &&
                        leaveApplicationData.otherReason == null)
                ? null
                : () async {
                    try {
                      Response? res = await RunnerLeaveHTTP.createLeave(data: {
                        "start_date":
                            dateFormat.format(leaveApplicationData.startDate!),
                        "end_date":
                            dateFormat.format(leaveApplicationData.endDate!),
                        "reason": leaveApplicationData.reason,
                        "other_reason": leaveApplicationData.reason ==
                                AppStrings.otherReasonString
                            ? leaveApplicationData.otherReason
                            : null,
                      });
                      if (res != null && res.statusCode == 200) {
                        leaveApplicationData.updateLeaveApplicationStep(
                            LeaveApplicationStep.leaveSubmitted);
                        leaveApplicationData.getAllLeaveApplications();
                      } else if (res?.statusCode == 409) {
                        leaveApplicationData.updateErrorWhileApplyingLeave(
                          languageProvider.getMessage(
                            "leave_conflict_error_message",
                            "Your leave application is conflicting with another one.",
                          ),
                        );
                      } else {
                        leaveApplicationData.updateErrorWhileApplyingLeave(
                            "Leave submission failed");
                      }
                    } catch (e) {
                      leaveApplicationData.updateErrorWhileApplyingLeave(
                          "Error creating leave - $e");
                    }
                  },
            child: Text(
              languageProvider.getMessage(
                "finish",
                "Finish",
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
      ],
    );
  }
}
