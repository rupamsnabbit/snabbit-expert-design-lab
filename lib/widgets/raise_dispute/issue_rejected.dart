import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/issue_data.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_text_highlighter.dart';
import 'package:snabbit_runner/widgets/raise_dispute/bottom_sheet.dart';

// Main Popup Widget
class IssueRejected extends StatefulWidget {
  final IssueData issueData;

  const IssueRejected({super.key, required this.issueData});

  @override
  State<IssueRejected> createState() => _IssueRejectedState();
}

class _IssueRejectedState extends State<IssueRejected> {

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
    String? subMessage;
    bool eligibleForReview = (widget.issueData.reviewCount??0) < 1;
    Color backgroundColor = eligibleForReview ? AppColors.brand : AppColors.n40;
    Color foregroundColor = eligibleForReview ? AppColors.n0 : AppColors.n60;
    final textTheme = Theme.of(context).textTheme;

    // Set UI based on status
        iconColor = const Color(0xFFFF3141);
        iconData = Icons.close;
        title = languageProvider.getMessage('issue_rejected_for','Issue is rejected for');
        buttonText = languageProvider.getMessage('request_review','Request Review');
        subMessage = widget.issueData.resolutionComment;


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
              Padding(
                padding: EdgeInsets.only(top: 20.h),
                child: Column(
                  children: [
                    Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, size: 40.w, color: Colors.white),
                    ),
                    SizedBox(height: 12.h),
                    FittedBox(
                      child: CustomTextHighlighter(
                        text:
                        '$title\n{{${widget.issueData.issueDate!=null?formatDayWithSuffix(widget.issueData.issueDate!):''} for ${widget.issueData.issueType ?? ''}}}',
                        textAlign: TextAlign.center,
                        textStyle: textTheme.headlineSmall?.copyWith(
                          fontSize: 18.sp,
                          color: const Color(0xFF333333),
                          fontWeight: FontWeight.w400,
                        ),
                        customHighlighter: (text) => Text(text,
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: 18.sp,
                              color: const Color(0xFF333333),
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                    if (subMessage != null) ...[
                      SizedBox(height: 16.h),
                      Container(
                        width: 337.w,
                        padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9DADA),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          subMessage,
                          textScaler: TextScaler.noScaling,
                          softWrap: true,
                          style: textTheme.titleSmall?.copyWith(
                            fontSize: 13.sp,
                            color: const Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              // Primary Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: ElevatedButton(
                  onPressed: () {
                    if (eligibleForReview) {
                      context
                          .read<BottomSheetViewProvider>()
                          .updateState(BottomSheetState.requestReview);
                    } else {
                      Navigator.of(context).pop();
                      showSnackbar(
                        context,
                        languageProvider.getMessage('review_already_requested',
                            'You have already requested a review for this issue.'),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(1.sw, 48.h),
                    backgroundColor: backgroundColor,
                    foregroundColor: foregroundColor,
                  ),
                  child: FittedBox(
                    child: Text(
                      buttonText,
                      style: textTheme.labelLarge?.copyWith(
                        color: foregroundColor,
                      ),
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
