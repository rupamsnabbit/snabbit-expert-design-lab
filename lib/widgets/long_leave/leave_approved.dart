import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../providers/leave_model.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';

class LeaveApproved extends StatefulWidget {
  const LeaveApproved({super.key});

  @override
  State<LeaveApproved> createState() => _LeaveApprovedState();
}

class _LeaveApprovedState extends State<LeaveApproved> {
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
        Container(
          width: 72.r,
          height: 72.r,
          decoration: const BoxDecoration(
            color: AppColors.g40,
            shape: BoxShape.circle,
          ),
          padding: EdgeInsets.all(16.r),
          child: FittedBox(
            child: Icon(
              Icons.check_rounded,
              color: AppColors.n0,
              size: 20.sp,
            ),
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          languageProvider.getMessage(
            "leave_approved",
            "Your leave application is approved",
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
        if ((leaveApplicationData.currentLeaveApplication?.startDate?.toLocal().difference(DateTime.now().toLocal()).inDays ?? 1) > 0)
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
