// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';

class AttendanceReasonDialog extends StatefulWidget {
  const AttendanceReasonDialog({super.key});

  @override
  State<AttendanceReasonDialog> createState() => _AttendanceReasonDialogState();
}

class _AttendanceReasonDialogState extends State<AttendanceReasonDialog> {
  Map<String, String> reasons = {};
  String? selectedReason;

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    reasons = {
      "pa_reason_1": languageProvider.getMessage("pa_reason_1", "reason 1"),
      "pa_reason_2": languageProvider.getMessage("pa_reason_2", "reason 2"),
      "pa_reason_3": languageProvider.getMessage("pa_reason_3", "reason 3"),
      "pa_reason_4": languageProvider.getMessage("pa_reason_4", "reason 4"),
      "pa_reason_5": languageProvider.getMessage("pa_reason_5", "reason 5"),
      "pa_reason_6": languageProvider.getMessage("pa_reason_6", "reason 6"),
      "pa_reason_7": languageProvider.getMessage("pa_reason_7", "reason 7"),
      "pa_reason_8": languageProvider.getMessage("pa_reason_8", "reason 8"),
      "pa_reason_9": languageProvider.getMessage("pa_reason_9", "reason 9"),
      "pa_reason_10": languageProvider.getMessage("pa_reason_10", "reason 10")
    };
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(languageProvider.getMessage(
            "reason_for_marking_absent", "Reason for marking absent")),
        content: SingleChildScrollView(
          child: ListBody(
            children: reasons.entries.map((entry) {
              return entry.value.isNotEmpty
                  ? ListTile(
                      leading:
                          CircularCheckbox(value: selectedReason == entry.key),
                      title: Text(entry.value),
                      onTap: () {
                        setState(() {
                          selectedReason = entry.key;
                        });
                      },
                    )
                  : Container();
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              languageProvider.getMessage("cancel", "Cancel"),
              style: const TextStyle(
                  color: AppColors.n80, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.of(context).pop(null);
            },
          ),
          TextButton(
            onPressed: selectedReason != null
                ? () {
                    Navigator.of(context).pop(selectedReason);
                  }
                : () {},
            child: Text(
              languageProvider.getMessage("confirm", "Confirm"),
              style: TextStyle(
                  color:
                      selectedReason != null ? AppColors.brand : AppColors.n60,
                  fontWeight: selectedReason != null
                      ? FontWeight.bold
                      : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}
