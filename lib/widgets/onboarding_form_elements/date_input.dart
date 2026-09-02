import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/dob_selector.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

class DateInputData {
  final String? dayHintText;
  final String? monthHintText;
  final String? yearHintText;

  final String?
      dateRangeType; // "adult", "child", "custom", or null for any date
  final int?
      dateRangeYearsBack;

  // Color properties
  final Color? hintTextColor;
  final Color? textColor;
  final Color? borderColor;

  final bool? enabled;
  final String? trailingIcon;
  final int? selectedYear;
  final DateTime? selectedDate;

  DateInputData({
    this.dayHintText,
    this.monthHintText,
    this.yearHintText,
    this.dateRangeType,
    this.dateRangeYearsBack,
    this.hintTextColor,
    this.textColor,
    this.borderColor,
    this.enabled,
    this.trailingIcon,
    this.selectedYear,
    this.selectedDate,
  });

  /// Factory constructor to create a DateInputData instance from a JSON map.
  /// NOTE: This implementation relies on the JSON map providing the exact
  /// expected types for each key, as there is no type casting or validation.
  factory DateInputData.fromJson(Map<String, dynamic> json) {
    return DateInputData(
      // String fields
      dayHintText: json['day_hint_text'],
      monthHintText: json['month_hint_text'],
      yearHintText: json['year_hint_text'],
      dateRangeType: json['date_range_type'],
      dateRangeYearsBack: json['date_range_years_back'] != null
          ? anyValueToInt(json['date_range_years_back'])
          : null,
      hintTextColor: hexToColor(json['hint_text_color']),
      textColor: hexToColor(json['text_color']),
      borderColor: hexToColor(json['border_color']),
      trailingIcon: json['trailing_icon'],

      // Boolean fields
      enabled: json['enabled'],
      selectedYear: json['selected_year'],
    );
  }
}

class DateInput extends StatefulWidget {
  final OnboardingQuestionData? data;
  final String? error;
  final Function(DateTime)? onSelected;
  final String? initialValue;

  const DateInput({
    super.key,
    this.data,
    this.error,
    this.onSelected,
    this.initialValue,
  });

  @override
  State<DateInput> createState() => _DateInputState();
}

class _DateInputState extends State<DateInput> {
  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  DateInputData? uiConfigData;

  @override
  void initState() {
    try {
      uiConfigData = DateInputData.fromJson(widget.data?.uiConfig ?? {});
    } catch (e) {
      debugPrint(e.toString());
    }

    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      final parsed = DateTime.tryParse(widget.initialValue!);
      if (parsed != null) {
        _setDateControllers(parsed);
        return;
      }
    }
    final selectedDate = uiConfigData?.selectedDate;
    final selectedYear = uiConfigData?.selectedYear;
    if (selectedDate != null) {
      _setDateControllers(selectedDate);
    } else if (selectedYear != null) {
      yearController.text = selectedYear.toString();
    }
    super.initState();
  }

  void _setDateControllers(DateTime date) {
    dayController.text = date.day.toString().padLeft(2, '0');
    monthController.text = date.month.toString().padLeft(2, '0');
    yearController.text = date.year.toString();
  }

  // Calculate dynamic date range based on UI config
  (DateTime, DateTime) _calculateDateRange() {
    final currentDate = DateTime.now();
    final rangeType = uiConfigData?.dateRangeType;
    final yearsBack = uiConfigData?.dateRangeYearsBack ?? 18;

    // Calculate date X years ago (accounting for leap years)
    DateTime yearsAgo(int years) {
      return DateTime(
          currentDate.year - years, currentDate.month, currentDate.day);
    }

    // Dynamic ranges based on type
    switch (rangeType) {
      case 'adult':
        // Adults: minimum age 18 years (so max birth date is 18 years ago)
        return (DateTime(1900), yearsAgo(yearsBack));

      case 'child':
        // Children: from 18 years ago to today
        return (yearsAgo(yearsBack), currentDate);

      case 'custom':
        // Use years_back for both directions if specified
        if (uiConfigData?.dateRangeYearsBack != null) {
          final targetDate = yearsAgo(yearsBack);
          return (targetDate, targetDate);
        }
        break;

      default:
        // No restrictions - allow any date
        return (DateTime(1900), currentDate);
    }

    // Default fallback
    return (DateTime(1900), currentDate);
  }

  void _selectDate(BuildContext context) async {
    final (firstDate, lastDate) = _calculateDateRange();

    // Any value already typed into the fields, else default to the latest
    // allowed day (e.g. the 18th birthday for an "adult" range).
    final parsed = DateTime.tryParse(
      '${yearController.text}-${monthController.text}-${dayController.text}',
    );

    // showDatePicker asserts firstDate <= initialDate <= lastDate. Clamp so a
    // stale/out-of-range field value, or a range that excludes the fallback,
    // can't trip the assertion: previously it threw and the silent catch
    // swallowed it, so the calendar never opened — notably for "adult"/DOB,
    // where `365 * 18` days lands a few days past the exact 18-year boundary.
    var initialDate = parsed ?? lastDate;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
      );

      if (!mounted || picked == null) return;
      setState(() => _setDateControllers(picked));
      widget.onSelected?.call(picked);
    } catch (e, stack) {
      MonitoringServiceHelper.logError('date_input_picker_failed', {
        'error': e.toString(),
        'stackTrace': stack.toString(),
        'firstDate': firstDate.toIso8601String(),
        'lastDate': lastDate.toIso8601String(),
        'initialDate': initialDate.toIso8601String(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingQuestion(
      mandatory: widget.data?.mandatory,
      error: widget.error,
      questionKey: widget.data?.question ?? '',
      questionDefault: widget.data?.question ?? '',
      answer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 8.h,
          ),
          DobSelector(
            onTap: () {
              _selectDate(context);
            },
            dobDay: dayController,
            dobMonth: monthController,
            dobYear: yearController,
            enabled: uiConfigData?.enabled ?? true,
          ),
        ],
      ),
    );
  }
}
