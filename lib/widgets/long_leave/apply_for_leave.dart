import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';

import '../../providers/language_provider.dart';
import '../../providers/leave_model.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../drawer/long_leave.dart';

class ApplyForLeave extends StatefulWidget {
  const ApplyForLeave({super.key});

  @override
  State<ApplyForLeave> createState() => _ApplyForLeaveState();
}

class _ApplyForLeaveState extends State<ApplyForLeave> {
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 24.h),
        Text(
          languageProvider.getMessage(
            "apply_leave",
            "Apply leave",
          ),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 28.sp,
                color: AppColors.n90,
                fontStyle: FontStyle.normal,
              ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 16.h,
          ),
          child: const Divider(
            color: AppColors.n30,
          ),
        ),
        SizedBox(height: 20.h),
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              leaveApplicationData.updateStartDate(picked);
              leaveApplicationData.updateErrorWhileApplyingLeave(null);
              // setState(() {
              //   startDate =
              //   "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
              //   errorWhileApplyingLeave = null;
              // });
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              controller: TextEditingController(
                text: leaveApplicationData.startDate != null
                    ? dateFormatVisual2.format(leaveApplicationData.startDate!)
                    : "",
              ),
              decoration: InputDecoration(
                labelText: "From (DD/MM/YYYY)",
                labelStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.n70,
                      fontSize: 15.sp,
                    ),
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        GestureDetector(
          onTap: () async {
            if (leaveApplicationData.startDate != null) {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: leaveApplicationData.startDate ?? DateTime.now(),
                firstDate: leaveApplicationData.startDate ?? DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                leaveApplicationData.updateEndDate(picked);
                // setModalState(() {
                //   endDate =
                //   "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                // });
              }
            } else {
              leaveApplicationData
                  .updateErrorWhileApplyingLeave(languageProvider.getMessage(
                "select_start_date_first",
                "Select start date first",
              ));
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              controller: TextEditingController(
                text: leaveApplicationData.endDate != null
                    ? dateFormatVisual2.format(leaveApplicationData.endDate!)
                    : "",
              ),
              decoration: InputDecoration(
                labelText: "To (DD/MM/YYYY)",
                labelStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.n70,
                      fontSize: 15.sp,
                    ),
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
            ),
          ),
        ),
        if (leaveApplicationData.startDate != null &&
            leaveApplicationData.endDate != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: RichText(
                text: TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: const Icon(Icons.info_outline_rounded),
                      ),
                    ),
                    TextSpan(
                      text:
                          "${languageProvider.getMessage("number_of_leave_days", "Number of days")} ",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    TextSpan(
                      text: "${getLeaveDuration(
                            leaveApplicationData.startDate,
                            leaveApplicationData.endDate,
                          ) ?? "-"}",
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
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
            onPressed: leaveApplicationData.startDate != null &&
                    leaveApplicationData.endDate != null
                ? () {
                    leaveApplicationData.updateLeaveApplicationStep(
                      LeaveApplicationStep.leaveReason,
                    );
                  }
                : null,
            child: Text(
              languageProvider.getMessage(
                "continue",
                "Continue",
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
      ],
    );
  }
}
