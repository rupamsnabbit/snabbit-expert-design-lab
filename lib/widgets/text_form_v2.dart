import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';

class TextFormSnabbitV2 extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String)? onChanged;
  final String Function(String?)? validator;
  final bool isLoading;
  final bool readOnly;
  final bool obscureText;
  final bool isFieldValidAndVerified;
  final TextInputType keyboardType;
  final int? maxLength;
  final Color? fillColor;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final Widget? suffixIcon;

  const TextFormSnabbitV2({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.validator,
    this.readOnly = false,
    this.obscureText = false,
    this.isLoading = false,
    this.isFieldValidAndVerified = false,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.fillColor,
    this.inputFormatters,
    this.enabled = true,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      keyboardType: keyboardType,
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      validator: validator,
      onChanged: onChanged,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
          filled: fillColor != null,
          fillColor: fillColor,
          suffixIcon: isLoading
              ? const CupertinoActivityIndicator(color: Colors.green)
              : isFieldValidAndVerified
                  ? suffixIcon
                  : null,
          border: const OutlineInputBorder(),
          hintText: hintText,
          hintStyle: AppTextTheme.hintStyle,
          counter: const SizedBox(),
          enabled: enabled),
    );
  }
}
