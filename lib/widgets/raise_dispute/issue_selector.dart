import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_text_highlighter.dart';


class IssueSelector extends StatelessWidget {
  final String? selectedItem;
  final ValueChanged<String> onSelectionChanged;
  // List of issue types to display in the grid.
  final List<String> issueTypes;
  final LanguageProvider languageProvider;
  final DateTime issueDate;

  IssueSelector({
    Key? key,
    this.selectedItem,
    required this.onSelectionChanged,
    required this.issueTypes,
    required this.languageProvider,
    required this.issueDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Section
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title: "Dear Expert, how can Snabbit Seva help you?"
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 38.5.w),
                  child: CustomTextHighlighter(
                    text:languageProvider.getMessage('how_snabbit_helps_you','Dear {{Expert}}, how can Snabbit Seva help you?',),
                    textAlign: TextAlign.center,
                    textStyle: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 23 / 20, // Line height: 23px
                      color: Colors.black,
                    ), customHighlighter: (String text) {
                      return Text(
                        text,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 23 / 20, // Line height: 23px
                            color: AppColors.brand,
                          )
                      );
                  },
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Subtitle: "Please select an issue from the options below."
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  languageProvider.getMessage('please_select_issue_from_options','Please select an issue from the options below.'),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    height: 18 / 15, // Line height: 18px
                    letterSpacing: 0,
                    color: const Color(0xFF4E5969),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        // GridView for Issue Types
        Flexible(
          flex: 2,
          child: GridView.builder(
            shrinkWrap: true, // Important for wrapping content in a Column
            physics: const NeverScrollableScrollPhysics(), // Disable scrolling as it's inside a Column
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 174.w / 56.h, // Calculated from Figma frame dimensions
            ),
            itemCount: issueTypes.length,
            itemBuilder: (context, index) {
              final String item = issueTypes[index];
              final bool isSelected = selectedItem == item;

              return GestureDetector(
                onTap: () => onSelectionChanged(item),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.brand // Selected border color
                          : const Color(0xFFD8DAE5), // Default border color
                      width: isSelected ? 2.w : 1.w, // Border width changes on selection
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, // Bold for selected
                          height: 24 / 20, // Line height: 24px
                          letterSpacing: -1.sp,
                          color: isSelected
                              ? AppColors.brand // Selected text color
                              : const Color(0xFF1D2129), // Default text color
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16.h),
        // Footer Section (You are reporting an issue for...)
        if (selectedItem != null)
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${languageProvider.getMessage('you_reporting_issue_for',"You are reporting an issue for")}: ',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                      height: 1.4, // Line height: 140%
                      color: const Color(0xFF4E5969),
                    ),
                  ),
                ),
              ),
              // This part would dynamically show the date, e.g., "5th July"
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatDayWithSuffix(issueDate), // Placeholder for dynamic date
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.4, // Line height: 140%
                      color: const Color(0xFF1D2129),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
