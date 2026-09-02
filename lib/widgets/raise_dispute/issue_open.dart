import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/issue_data.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/raise_dispute/bottom_sheet.dart';

import 'issue_status_header.dart';

// Main Popup Widget
class IssueOpen extends StatefulWidget {
  final IssueData issueData;

  const IssueOpen({super.key, required this.issueData});

  @override
  State<IssueOpen> createState() => _IssueOpenState();
}

class _IssueOpenState extends State<IssueOpen> {

  bool init=true;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if(init){
      init=false;
      languageProvider=Provider.of<LanguageProvider>(context,listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;
    String title;
    String buttonText;
    final textTheme = Theme.of(context).textTheme;

    // Set UI based on status
        iconColor = const Color(0xFFFF8F1F);
        iconData = Icons.priority_high;
        title = languageProvider.getFormattedMessage('issue_already_status_for','Issue is already {{status}} for',{
          "status":widget.issueData.status?.displayText.toLowerCase(),
        });
        buttonText = languageProvider.getMessage('okay','Okay');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section
              IssueStatusHeader(
                iconColor: iconColor,
                iconData: iconData,
                title: title,
                buttonText: buttonText,
                date: widget.issueData.issueDate,
                issueType: widget.issueData.issueType,
              ),
              SizedBox(height: 20.h),
              // Primary Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(1.sw, 48.h),
                  ),
                  child: FittedBox(
                    child: Text(
                      buttonText,
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.n0,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: ElevatedButton(
                  onPressed: (){
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(1.sw, 48.h),
                    backgroundColor: AppColors.brandInverted,
                  ),
                  child: FittedBox(
                    child: Text(
                      languageProvider.getMessage('report_another_issue','Report another issue'),
                      style: textTheme.labelLarge,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
