import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/lunch_time/lunch_time_request.dart';

class LunchTimeRefusal extends StatefulWidget {
  final VoidCallback? onPositive;
  final VoidCallback? onNegative;

  const LunchTimeRefusal({
    Key? key,
    this.onPositive,
    this.onNegative,
  }) : super(key: key);

  @override
  State<LunchTimeRefusal> createState() => _LunchTimeRefusalState();
}

class _LunchTimeRefusalState extends State<LunchTimeRefusal> {
  late LanguageProvider languageProvider;
  bool _isProcessing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
  }

  void _handleAction({required bool isPositive}) {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    if (isPositive) {
      widget.onPositive?.call();
    } else {
      widget.onNegative?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Container(
        padding: EdgeInsets.symmetric(
          vertical: 48.h,
        ),
        alignment: Alignment.center,
        child: CupertinoActivityIndicator(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 25.h),
        Text(
          languageProvider.getMessage(
            'are_you_sure',
            'Are you sure?',
          ),
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          languageProvider.getMessage(
            'no_more_breaks_today',
            'You may not get another chance to take a break today',
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.n80,
              ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _handleAction(isPositive: false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.n60),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  languageProvider.getMessage(
                    'go_back',
                    'Go back',
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.n60,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleAction(isPositive: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.g40,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  languageProvider.getMessage(
                    'end_my_break',
                    'End my break',
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.n0,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
      ],
    );
  }
}

void showLunchTimeRefusalBottomSheet(
  BuildContext context, {
  VoidCallback? onPositive,
  VoidCallback? onNegative,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16.r),
      ),
    ),
    builder: (context) => CommonBottomSheetSetup(
      child: LunchTimeRefusal(
        onPositive: onPositive ??
            () {
              Navigator.pop(context);
            },
        onNegative: onNegative ??
            () {
              Navigator.pop(context);
              showLunchTimeRequestBottomSheet(context);
            },
      ),
    ),
  );
}
