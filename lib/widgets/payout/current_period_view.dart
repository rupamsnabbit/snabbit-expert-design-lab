import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/constants.dart';

import '../../utils/colors.dart';
import '../../utils/enums.dart';

class CurrentPeriodProvider extends ChangeNotifier {
  DateTime monthStartDate = payoutMonthlyDefaultStart;
  DateTime monthEndDate = payoutMonthlyDefaultEnd;
  DateTime currentDate = payoutDefaultStart;
  DateTime? prevSelectedStartDate;
  DateTime? prevSelectedEndDate;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  void updateMonthStart(DateTime dt) {
    monthStartDate = dt;
    notifyListeners();
  }

  void updateMonthEnd(DateTime dt) {
    monthEndDate = dt;
    notifyListeners();
  }

  void updateCurrentDate(DateTime dt, {bool notify = true}) {
    currentDate = dt;

    // Check if currentDate falls within the same month as monthStartDate & monthEndDate
    if (!(isSameMonth(monthStartDate, dt) && isSameMonth(monthEndDate, dt))) {
      // If different month, update monthStartDate & monthEndDate to match currentDate's month
      monthStartDate = DateTime(dt.year, dt.month, 1); // First day of the month
      monthEndDate = DateTime(dt.year, dt.month + 1, 0); // Last day of the month
    }

    if (notify) notifyListeners();
  }

  bool isSameMonth(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month;
  }

  void reset() {
    monthStartDate = payoutMonthlyDefaultStart;
    monthEndDate = payoutMonthlyDefaultEnd;
    currentDate = payoutDefaultStart;
  }
  //
  // void updateCurrentDate(DateTime dt) {
  //   currentDate = dt;
  //   notifyListeners();
  // }
}

class CurrentPeriodView extends StatefulWidget {
  final PayoutPeriod viewType; // 'daily' or 'monthly'
  final Function() onChanged;
  final bool isNextDisabled;
  final bool isPreviousDisabled;
  final DateTime? nextDate;
  final DateTime? previousDate;

  /// Optional intercept for the right-arrow (next) tap. Applies to both
  /// the monthly and daily views. When supplied, it runs first; returning
  /// `true` means the caller handled the tap (e.g. popped back to a
  /// webview) and the default advance is skipped. Returning `false` (or
  /// `null` via absence) falls through to the default behavior.
  final bool Function()? onNextTapOverride;

  const CurrentPeriodView({
    required this.viewType,
    required this.onChanged,
    this.isNextDisabled = false,
    this.isPreviousDisabled = false,
    this.nextDate,
    this.previousDate,
    this.onNextTapOverride,
    super.key,
  });

  @override
  State<CurrentPeriodView> createState() => _CurrentPeriodViewState();
}

class _CurrentPeriodViewState extends State<CurrentPeriodView> {
  late CurrentPeriodProvider currentPeriodProvider;
  bool init = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  void _switchToPrevious() {
    if (widget.isPreviousDisabled) return;
    if (widget.viewType == PayoutPeriod.monthly) {
      currentPeriodProvider.prevSelectedStartDate =
          currentPeriodProvider.monthStartDate;
      currentPeriodProvider.prevSelectedEndDate =
          currentPeriodProvider.monthEndDate;
    }
    setState(() {
      if (widget.viewType == PayoutPeriod.daily) {
        // _currentDate = _currentDate.subtract(const Duration(days: 1));
        DateTime newCurrent =
            widget.previousDate ?? currentPeriodProvider.currentDate.subtract(const Duration(days: 1));
        currentPeriodProvider.updateCurrentDate(newCurrent);
        widget.onChanged();
      } else {
        DateTime newCurrent = DateTime(currentPeriodProvider.monthStartDate.year,
            currentPeriodProvider.monthStartDate.month - 1);
        currentPeriodProvider.updateMonthStart(newCurrent);
        currentPeriodProvider
            .updateMonthEnd(DateTime(newCurrent.year, newCurrent.month + 1, 0));
        widget.onChanged();
      }
    });
  }

  void _switchToNext() {
    if (widget.isNextDisabled) return;
    // Let the parent intercept before we advance — used by the v1
    // earnings screens (monthly PayoutHome / DailyEarningsList, daily
    // DailyEarningState) to pop back to the webview when the runner was
    // drilled here from the webview for a pre-optin period and now tries
    // to step forward into v2 territory.
    if (widget.onNextTapOverride?.call() == true) {
      return;
    }
    if (widget.viewType == PayoutPeriod.monthly) {
      currentPeriodProvider.prevSelectedStartDate =
          currentPeriodProvider.monthStartDate;
      currentPeriodProvider.prevSelectedEndDate =
          currentPeriodProvider.monthEndDate;
    }
    setState(() {
      if (widget.viewType == PayoutPeriod.daily) {
        DateTime newCurrent =
           widget.nextDate ?? currentPeriodProvider.currentDate.add(const Duration(days: 1));
        currentPeriodProvider.updateCurrentDate(newCurrent);
        widget.onChanged();
      } else {
        DateTime newCurrent = DateTime(currentPeriodProvider.monthStartDate.year,
            currentPeriodProvider.monthStartDate.month + 1);
        currentPeriodProvider.updateMonthStart(newCurrent);
        currentPeriodProvider
            .updateMonthEnd(DateTime(newCurrent.year, newCurrent.month + 1, 0));
        widget.onChanged();
      }
    });
  }

  Widget getMiddleText() {
    if (widget.viewType == PayoutPeriod.daily) {
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text:
                  "${DateFormat('EEEE').format(currentPeriodProvider.currentDate)}\n",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextSpan(
              text: DateFormat(' d').format(currentPeriodProvider.currentDate),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            TextSpan(
              text: DateFormat(' MMM yyyy')
                  .format(currentPeriodProvider.currentDate),
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ],
        ),
      ); // e.g., "Sunday 13th Jan 2025"
    } else {
      return Text(
        DateFormat('MMMM yyyy').format(currentPeriodProvider.monthStartDate),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ); // e.g., "January 2025"
    }
    // throw ArgumentError('Invalid viewType: ${widget.viewType}');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      // mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left Chevron
        SizedBox(width: 24.w),
        SizedBox(
          width: 28.r,
          height: 28.r,
          child: OutlinedButton(
            onPressed: _switchToPrevious,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.n90,
              backgroundColor: AppColors.n0,
              side: const BorderSide(color: AppColors.n50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            child: const Icon(Icons.chevron_left),
          ),
        ),

        // Middle Text (Current Date or Month)
        Expanded(
          child: getMiddleText(),
        ),

        // Right Chevron
        SizedBox(
          width: 28.r,
          height: 28.r,
          child: OutlinedButton(
            onPressed: _switchToNext,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.n90,
              backgroundColor: AppColors.n0,
              side: const BorderSide(color: AppColors.n50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            child: const Icon(Icons.chevron_right),
          ),
        ),
        SizedBox(width: 24.w),
      ],
    );
  }
}
