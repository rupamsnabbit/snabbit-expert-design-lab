import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class TimeRangeSelectionData {
  final String? startHintText;
  final String? endHintText;
  final bool? mandatory;
  final Color? hintTextColor;
  final Color? textColor;
  final Color? borderColor;
  final bool? enabled;
  final String? separatorIcon;
  final int? selectedDurationInHours;
  final bool? autoCalculateEndTime;

  TimeRangeSelectionData({
    this.startHintText,
    this.endHintText,
    this.mandatory,
    this.hintTextColor,
    this.textColor,
    this.borderColor,
    this.enabled,
    this.separatorIcon,
    this.selectedDurationInHours,
    this.autoCalculateEndTime,
  });

  factory TimeRangeSelectionData.fromJson(Map<String, dynamic> json) {
    return TimeRangeSelectionData(
      startHintText: json['start_hint_text'],
      endHintText: json['end_hint_text'],
      hintTextColor: hexToColor(json['hint_text_color']),
      textColor: hexToColor(json['text_color']),
      borderColor: hexToColor(json['border_color']),
      separatorIcon: json['separator_icon'],
      mandatory: json['mandatory'],
      enabled: json['enabled'],
      selectedDurationInHours: json['selected_duration_in_hours'],
      autoCalculateEndTime: json['auto_calculate_end_time'],
    );
  }
}

class TimeRangeSelector extends StatefulWidget {
  final OnboardingQuestionData? data;
  final String? error;
  final Function(String? start, String? end)? onChanged;
  final String? initialValue;
  final int? selectedDurationInHours;

  const TimeRangeSelector({
    super.key,
    this.data,
    this.error,
    this.onChanged,
    this.initialValue,
    this.selectedDurationInHours,
  });

  @override
  State<TimeRangeSelector> createState() => _TimeRangeSelectorState();
}

class _TimeRangeSelectorState extends State<TimeRangeSelector> {
  String? startTime;
  String? endTime;
  TimeRangeSelectionData? uiConfigData;

  @override
  void initState() {
    super.initState();
    try {
      uiConfigData =
          TimeRangeSelectionData.fromJson(widget.data?.uiConfig ?? {});
    } catch (_) {}

    // selectedDurationInHours is now accessed directly from widget

    // Parse initial value like "10:30-18:00"
    if (widget.initialValue?.isNotEmpty == true) {
      final parts = widget.initialValue!.split('-');
      startTime = parts.isNotEmpty ? parts[0].trim() : null;
      endTime = parts.length > 1 ? parts[1].trim() : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-recalculate end time if duration changes and we have a start time (only when auto-calculate is enabled)
    final shouldAutoCalculate = uiConfigData?.autoCalculateEndTime ?? false;

    if (shouldAutoCalculate &&
        startTime != null &&
        widget.selectedDurationInHours != null &&
        widget.selectedDurationInHours! > 0) {
      final startParts = startTime!.split(':');
      if (startParts.length == 2) {
        final startHour = int.tryParse(startParts[0]);
        final startMinute = int.tryParse(startParts[1]);
        if (startHour != null && startMinute != null) {
          final startDateTime = DateTime(0, 1, 1, startHour, startMinute);
          final endDateTime = startDateTime
              .add(Duration(hours: widget.selectedDurationInHours!));
          final newEndTime = DateFormat('HH:mm').format(endDateTime);

          if (endTime != newEndTime) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  endTime = newEndTime;
                });
                widget.onChanged?.call(startTime, newEndTime);
              }
            });
          }
        }
      }
    }

    return OnboardingQuestion(
      mandatory: widget.data?.mandatory,
      questionKey: widget.data?.question ?? '',
      questionDefault: widget.data?.question ?? '',
      answer: Row(
        children: [
          // START TIME
          Expanded(
            child: GestureDetector(
              onTap: shouldAutoCalculate
                  ? (widget.selectedDurationInHours != null &&
                          widget.selectedDurationInHours! > 0
                      ? () async {
                          await _pickStartTime(context);
                        }
                      : null)
                  : () async {
                      await _pickStartTime(context);
                    },
              child: ShowTimingsString(
                time: startTime ?? uiConfigData?.startHintText ?? '-- : --',
                isDisabled: shouldAutoCalculate
                    ? (widget.selectedDurationInHours == null ||
                        widget.selectedDurationInHours! <= 0)
                    : false,
              ),
            ),
          ),

          SizedBox(
            width: 40.w,
            child: Center(
              child: uiConfigData?.separatorIcon?.isNotEmpty == true
                  ? RemoteImageHandler(imageUrl: uiConfigData!.separatorIcon!)
                  : const Icon(Icons.arrow_forward,
                      size: 24, color: Color(0xff9E9E9E)),
            ),
          ),

          Expanded(
            child: GestureDetector(
              onTap: shouldAutoCalculate
                  ? null
                  : () async {
                      await _pickEndTime(context);
                    },
              child: ShowTimingsString(
                time: endTime ?? uiConfigData?.endHintText ?? '-- : --',
                isDisabled:
                    shouldAutoCalculate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final now = DateTime.now();
      final pickedDateTime =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);

      final formattedEnd = DateFormat('HH:mm').format(pickedDateTime);
      setState(() => endTime = formattedEnd);

      widget.onChanged?.call(startTime, formattedEnd);
    }
  }

  Future<void> _pickStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final now = DateTime.now();
      final pickedDateTime =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);

      final formattedStart = DateFormat('HH:mm').format(pickedDateTime);
      String? formattedEnd;

      // Auto-calculate end if duration is defined and auto-calculate is enabled
      if (uiConfigData?.autoCalculateEndTime == true &&
          widget.selectedDurationInHours != null &&
          widget.selectedDurationInHours! > 0) {
        final updated = pickedDateTime
            .add(Duration(hours: widget.selectedDurationInHours!));
        formattedEnd = DateFormat('HH:mm').format(updated);
      }

      setState(() {
        startTime = formattedStart;
        if (formattedEnd != null) endTime = formattedEnd;
      });

      widget.onChanged?.call(formattedStart, formattedEnd ?? endTime);
    }
  }
}

class ShowTimingsString extends StatelessWidget {
  final String? time;
  final bool isDisabled;
  const ShowTimingsString({super.key, this.time, this.isDisabled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 62.h,
      decoration: BoxDecoration(
        border: Border.all(color: isDisabled ? AppColors.n30 : AppColors.n40),
        borderRadius: BorderRadius.circular(10.r),
        color: isDisabled ? AppColors.n10 : null,
      ),
      child: Center(
        child: Text(
          time ?? '-- : --',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isDisabled ? AppColors.n50 : AppColors.n80,
              ),
        ),
      ),
    );
  }
}
