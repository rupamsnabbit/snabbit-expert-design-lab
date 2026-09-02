import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_text_highlighter.dart';

class IssueStatusHeader extends StatelessWidget {
  final Color iconColor;
  final IconData iconData;
  final String title;
  final String buttonText;
  final String? subMessage;
  final DateTime? date;
  final String? issueType;

  const IssueStatusHeader({
    super.key,
    required this.iconColor,
    required this.iconData,
    required this.title,
    required this.buttonText,
    this.subMessage,
    this.date,
    this.issueType,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
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
                  '$title\n{{${date != null ? formatDayWithSuffix(date!) : ''} for ${issueType ?? ''}}}',
              textAlign: TextAlign.center,
              textStyle: textTheme.headlineSmall?.copyWith(
                fontSize: 18.sp,
                color: const Color(0xFF333333),
                fontWeight: FontWeight.w400,
              ),
              customHighlighter: (text) => Text(
                text,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 18.sp,
                  color: const Color(0xFF333333),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (subMessage != null) ...[
            SizedBox(height: 16.h),
            Container(
              width: 337.w,
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF9DADA),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subMessage!,
                  textScaler: TextScaler.noScaling,
                  style: textTheme.titleSmall?.copyWith(
                    fontSize: 13.sp,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
