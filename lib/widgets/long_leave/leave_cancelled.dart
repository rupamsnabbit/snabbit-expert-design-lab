import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/leave_model.dart';

import '../../providers/language_provider.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';

class LeaveCancelled extends StatefulWidget {
  const LeaveCancelled({
    super.key,
  });

  @override
  State<LeaveCancelled> createState() => _LeaveCancelledState();
}

class _LeaveCancelledState extends State<LeaveCancelled> {
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
    return leaveApplicationData.currentLeaveApplication == null
        ? const Center(
            child: Text("Leave application is not found"),
          )
        : Column(
            children: [
              SizedBox(height: 26.h),
              SvgPicture.asset(
                "assets/svgs/drawer/long-leave/leaveDenied.svg",
              ),
              SizedBox(
                height: 20.h,
              ),
              Text(
                languageProvider.getMessage(
                  "leave_cancelled",
                  "Leave application cancelled",
                ),
                style: Theme.of(context).textTheme.headlineSmall,
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
              SizedBox(height: 12.h),
            ],
          );
  }
}
