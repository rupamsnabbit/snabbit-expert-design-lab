import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:snabbit_runner/models/issue_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

// Stateful Widget for a single issue card.
class IssueCard extends StatefulWidget {
  final IssueData data;

  const IssueCard({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  State<IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<IssueCard> {
  // A helper method to get the correct color for the status pill.
  Color getStatusColor() {
    switch (widget.data.status) {
      case IssueStatus.rejected:
        return const Color(0xFFC50F1F);
      case IssueStatus.resolved:
        return const Color(0xFF107C41);
      case IssueStatus.open:
        return const Color(0xFFCC9213);
      case IssueStatus.underReview:
        return const Color(0xFFF7630C);
      default:
        return Colors.grey;
    }
  }

  // A helper method to get the correct background color for the status pill.
  Color getStatusBackgroundColor() {
    switch (widget.data.status) {
      case IssueStatus.rejected:
        return const Color(0xFFF9DADA);
      case IssueStatus.resolved:
        return const Color(0xFFCAEAD8);
      case IssueStatus.open:
        return const Color(0xFFFFEFD2);
      case IssueStatus.underReview:
        return const Color(0xFFFFF9F5);
      default:
        return Colors.grey.shade200;
    }
  }

  // Helper method to get the background color for the body.
  Color getBodyBackgroundColor() {
    switch (widget.data.status) {
      case IssueStatus.rejected:
        return const Color(0xFFF9DADA);
      case IssueStatus.resolved:
        return const Color(0xFFCAEAD8);
      case IssueStatus.open:
        return const Color(0xFFFFE0B2);
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 361.w,
      decoration: BoxDecoration(
        color: AppColors.n0,
        border: Border.all(
          color: AppColors.n40,
          width: 1.w,
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header Section
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Issue Number
                Row(
                  children: [
                    Expanded(child: _FieldRow(label: "Issue Number: ", value: "#${widget.data.id ?? ''}"),),
                    // Status Pill
                    if(widget.data.status?.displayText.trim().isNotEmpty==true)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: getStatusBackgroundColor(),
                        borderRadius: BorderRadius.circular(99.r),
                      ),
                      height: 25.h,
                      child: Center(
                        child: FittedBox(
                          child: Text(
                            widget.data.status?.displayText ?? '',
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                              color: getStatusColor(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // Issue Type
                _FieldRow(label: "Issue Type: ", value:  widget.data.issueType ?? ''),
                SizedBox(height: 8.h),
                // Issue Date
                _FieldRow(label: "Issue date: ", value: widget.data.issueDate != null ? formatDayWithSuffix(widget.data.issueDate!) : ''),
                if(widget.data.comment?.trim().isNotEmpty==true)
                  ...[
                    SizedBox(height: 8.h),
                    // Comment
                    _FieldRow(label: "Your comment: ", value:  widget.data.comment ?? ''),
                  ],
                if( widget.data.status==IssueStatus.underReview && widget.data.appealComment?.trim().isNotEmpty==true)
                  ...[
                    SizedBox(height: 8.h),
                    // Comment
                    _FieldRow(label: "Review comment: ", value:  widget.data.appealComment ?? ''),
                  ]
              ],
            ),
          ),
          if(widget.data.status!=IssueStatus.underReview && widget.data.resolutionComment?.isNotEmpty==true)
          ...[
            SizedBox(height: 12.h),
          // Card Body Section
          Container(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
            decoration: BoxDecoration(
              color: getBodyBackgroundColor(),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.data.resolutionComment ?? '',
                    style: textTheme.titleSmall?.copyWith(
                      height: 1.4,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ),
          )],
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

}

// Private stateless widget for displaying a label-value pair.
// This widget was added based on the user's request to refactor a similar method.
class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  const _FieldRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return  Row(
      children: [
        Text(
          label,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: const Color(0xFF333333),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }
}
