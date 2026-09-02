import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../providers/leave_model.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';

class LeaveSubmitted extends StatefulWidget {
  const LeaveSubmitted({super.key});

  @override
  State<LeaveSubmitted> createState() => _LeaveSubmittedState();
}

class _LeaveSubmittedState extends State<LeaveSubmitted> {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.n90),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        Text(
          languageProvider.getMessage(
              "leave_submitted", "Leave application submitted"),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          formatDateRange(
              leaveApplicationData.startDate, leaveApplicationData.endDate),
          style: Theme.of(context)
              .textTheme
              .headlineLarge
              ?.copyWith(fontSize: 32.sp),
        ),
        SvgPicture.asset(
          "assets/svgs/drawer/long-leave/watch.svg",
        ),
        SizedBox(
          height: 24.h,
        ),
        Text(
          languageProvider.getMessage("leave_application_sent",
              "Your application for a long leave has been sent. Please wait for approval of leave."),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        SizedBox(height: 32.h),
      ],
    );
  }
}
