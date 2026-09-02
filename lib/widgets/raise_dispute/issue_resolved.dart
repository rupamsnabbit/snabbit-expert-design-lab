import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/issue_data.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/raise_dispute/bottom_sheet.dart';
import 'package:snabbit_runner/widgets/raise_dispute/issue_status_header.dart';

// Main Popup Widget
class IssueResolved extends StatefulWidget {
  final IssueData issueData;

  const IssueResolved({super.key, required this.issueData});

  @override
  State<IssueResolved> createState() => _IssueResolvedState();
}

class _IssueResolvedState extends State<IssueResolved> {
  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Consumer<LanguageProvider>(
          builder: (context,languageProvider,_) {
            Color iconColor;
            IconData iconData;
            String title;
            String buttonText;
            final textTheme = Theme.of(context).textTheme;

            iconColor = const Color(0xFF107C41);
            iconData = Icons.check_sharp;
            title = languageProvider.getMessage('issue_already_resolved_for','Issue is already resolved for');
            buttonText = languageProvider.getMessage('okay', 'Okay');
            return SingleChildScrollView(
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
                  SizedBox(height: 20.h),
                ],
              ),
            );
          }
        ),
      ),
    );
  }
}
