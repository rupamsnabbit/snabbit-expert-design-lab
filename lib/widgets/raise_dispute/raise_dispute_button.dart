import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/raise_dispute/issue_history.dart';
import 'package:snabbit_runner/pages/raise_dispute/new_issue_reporter.dart';
import 'package:snabbit_runner/providers/daily_earnings_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_widgets/popup_menu_divider.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

// This is the Report Issue button with a dropdown menu.
class ReportIssueButton extends StatefulWidget {
  final bool allowOverride;
  const ReportIssueButton({Key? key, this.allowOverride = false})
      : super(key: key);

  @override
  State<ReportIssueButton> createState() => _ReportIssueButtonState();
}

class _ReportIssueButtonState extends State<ReportIssueButton> {
  final GlobalKey _buttonKey = GlobalKey();
  late LanguageProvider languageProvider;
  bool init = true;
  late DailyEarningsProvider earningsProvider;
  late CurrentPeriodProvider periodProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      earningsProvider =
          Provider.of<DailyEarningsProvider>(context, listen: true);
      periodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  // A helper method to display the dropdown menu using a pop-up.
  void _showDropdown() {
    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height + 10,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      color: AppColors.n0,
      menuPadding: EdgeInsets.symmetric(horizontal: 12.w),
      items: <PopupMenuEntry<String>>[
        // View issue history option.
        PopupMenuItem<String>(
          value: languageProvider.getMessage(
              'view_issue_history', 'View issue history'),
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              // Icon for "View issue history".
              // Using a simple icon for the example, as custom SVG is more complex.
              Icon(
                Icons.remove_red_eye_outlined,
                size: 20.w,
                color: const Color(0xFF4E5969),
              ),
              SizedBox(width: 8.w),
              Text(
                languageProvider.getMessage(
                    'view_issue_history', 'View issue history'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      height: 1.38,
                      letterSpacing: -0.24,
                      color: const Color(0xFF4E5969),
                    ),
              ),
            ],
          ),
          onTap: () {
            Navigator.pushNamed(context, IssueHistory.routeName);
          },
        ),
        // Separator.
        CustomPopupMenuDivider(
          height: 1.r,
          color: AppColors.n40,
        ),
        // Report new issue option.
        PopupMenuItem<String>(
          value: 'Report new issue',
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              // Icon for "Report new issue".
              Icon(
                Icons.add,
                size: 20.w,
                color: const Color(0xFF4E5969),
              ),
              SizedBox(width: 8.w),
              Text(
                languageProvider.getMessage(
                    'report_new_issue', 'Report new issue'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      height: 1.38,
                      letterSpacing: -0.24,
                      color: const Color(0xFF4E5969),
                    ),
              ),
            ],
          ),
          onTap: () {
            Navigator.pushNamed(context, NewIssueReporter.routeName);
          },
        ),
      ],
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
    );
  }

  bool _directlyReportIssue() {
    return earningsProvider.dailyEarningsData?.allowReportIssue == true &&
        earningsProvider.dailyEarningsData?.allowIssueHistory != true;
  }

  void goToReportIssue() {
    Navigator.pushNamed(context, NewIssueReporter.routeName).then(
      (value) {
        if (_directlyReportIssue()) {
          earningsProvider.fetchDailyEarnings(periodProvider.currentDate);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allowOverride ||
        earningsProvider.dailyEarningsData?.allowReportIssue == true ||
        earningsProvider.dailyEarningsData?.allowIssueHistory == true) {
      return Padding(
        padding: EdgeInsets.only(right: 16.w),
        child: GestureDetector(
          key: _buttonKey,
          onTap: () {
            if (_directlyReportIssue()) {
              goToReportIssue();
            } else {
              _showDropdown();
            }
          },
          child: Container(
            padding: EdgeInsets.only(
                left: 8.12.w, right: 12.17.w, top: 4.42.h, bottom: 4.42.h),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF4E5969),
                width: 0.858.w,
              ),
              borderRadius: BorderRadius.circular(84.98.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Using a simple icon here, as the complex SVG from Figma is not a standard Flutter icon.
                // You can replace this with a custom SVG widget if you have one.
                Container(
                  height: 17.17.r,
                  width: 17.17.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF4E5969), width: 1.3.r),
                      borderRadius: BorderRadius.circular(3.r)),
                  child: const Icon(
                    Icons.priority_high_rounded,
                    color: Color(0xFF4E5969),
                    size: 13,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  languageProvider.getMessage('report_issue', 'Report issue'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11.16.sp,
                        height: 1.94,
                        color: const Color(0xFF4E5969),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
