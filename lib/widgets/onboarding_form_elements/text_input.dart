import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(newValue.text)) {
      return oldValue;
    }

    final parts = newValue.text.split('.');
    if (parts.length > 2) {
      return oldValue;
    }

    if (parts.length == 1) {
      if (parts[0].length > 3) {
        return oldValue;
      }
    } else {
      final beforeDecimal = parts[0];
      final afterDecimal = parts[1];

      if (beforeDecimal.length > 3 || afterDecimal.length > 2) {
        return oldValue;
      }
    }

    return newValue;
  }
}

class TextInputData {
  final String? hintText;
  final String? trailingIcon;
  final bool? enabled;
  final int? maxLimit;
  final int? minLimit;
  final Color? hintTextColor;
  final Color? textColor;
  final Color? borderColor;
  final String? permittedCharacters;

  TextInputData({
    this.hintText,
    this.trailingIcon,
    this.enabled,
    this.maxLimit,
    this.hintTextColor,
    this.textColor,
    this.borderColor,
    this.permittedCharacters,
    this.minLimit,
  });

  factory TextInputData.fromJson(Map<String, dynamic> json) {
    return TextInputData(
      hintText: json['hint_text'],
      trailingIcon: json['trailing_icon'],
      enabled: json['enabled'],
      maxLimit: anyValueToInt(json['max_length']),
      hintTextColor: hexToColor(json['hint_text_color']),
      textColor: hexToColor(json['text_color']),
      borderColor: hexToColor(json['border_color']),
      permittedCharacters: json['permitted_characters'],
      minLimit: json['min_length'],
    );
  }
}

class TextInput extends StatefulWidget {
  final OnboardingQuestionData? data;
  final String? error;
  final Function(String)? onChanged;
  final Function(bool)? onValidationChanged;
  final String? initialValue;
  final TextEditingController? textEditingController;

  const TextInput({
    super.key,
    this.data,
    this.error,
    this.onChanged,
    this.onValidationChanged,
    this.initialValue,
    this.textEditingController,
  });

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  late final TextEditingController _controller;

  bool _validateInput(String value) {
    if (widget.data?.uiConfig == null) {
      // No UI config, consider valid
      return true;
    }

    TextInputData? uiConfigData;
    try {
      uiConfigData = TextInputData.fromJson(widget.data!.uiConfig!);
    } catch (_) {
      return true;
    }

    if (uiConfigData == null) {
      return true;
    }

    final minLimit = uiConfigData.minLimit;
    final maxLimit = uiConfigData.maxLimit;
    final permittedChars = uiConfigData.permittedCharacters;

    if (minLimit != null && value.length < minLimit) {
      return false;
    }

    if (maxLimit != null && value.length > maxLimit) {
      return false;
    }

    if (permittedChars?.isNotEmpty == true) {
      try {
        final regex = RegExp('^$permittedChars+\$');
        if (!regex.hasMatch(value)) {
          return false;
        }
      } catch (e) {
        return true;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.textEditingController ?? TextEditingController();

    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _controller.text = widget.initialValue!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final isValid = _validateInput(widget.initialValue!);
        widget.onValidationChanged?.call(isValid);
      });
    }
  }

  @override
  void dispose() {
    // Only dispose our own controller, not the external one
    if (widget.textEditingController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextInputData? uiConfigData;
    try {
      uiConfigData = TextInputData.fromJson(widget.data?.uiConfig ?? {});
    } catch (_) {}

    final permittedChars = uiConfigData?.permittedCharacters;

    final useDecimalFormatter = permittedChars == '[0-9.]';

    return OnboardingQuestion(
      questionKey: widget.data?.question ?? '',
      questionDefault: widget.data?.question ?? '',
      mandatory: widget.data?.mandatory,
      error: widget.error,
      answer: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              inputFormatters: [
                if (useDecimalFormatter)
                  DecimalInputFormatter() // Custom formatter for decimal constraints
                else if (permittedChars?.isNotEmpty == true)
                  FilteringTextInputFormatter.allow(RegExp(permittedChars!)),
                LengthLimitingTextInputFormatter(uiConfigData?.maxLimit),
              ],
              keyboardType: useDecimalFormatter
                  ? TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(
                hintText: uiConfigData?.hintText,
                hintStyle: AppTextTheme.hintStyle,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                widget.onChanged?.call(value);
                final isValid = _validateInput(value);
                widget.onValidationChanged?.call(isValid);
              },
              enabled: uiConfigData?.enabled ?? true,
            ),
          ),
          if (uiConfigData?.trailingIcon?.isNotEmpty == true)
            Padding(
              padding: EdgeInsets.only(left: 12.w),
              child: RemoteImageHandler(
                imageUrl: uiConfigData?.trailingIcon?.cdn ?? '',
                width: 40.w,
              ),
            )
        ],
      ),
    );
  }
}
