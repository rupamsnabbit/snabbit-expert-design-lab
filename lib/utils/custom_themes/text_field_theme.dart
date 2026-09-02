import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/colors.dart';

import 'text_themes.dart';

class AppTextFormFieldTheme {
  AppTextFormFieldTheme._();

  static InputDecorationTheme lightInputDecorationTheme = InputDecorationTheme(
    errorMaxLines: 1,
    prefixIconColor: Colors.grey,
    fillColor: AppColors.n0,
    filled: true,
    suffixIconColor: Colors.grey,
    labelStyle: AppTextTheme.lightTextTheme.bodyLarge,
    hintStyle:
        AppTextTheme.lightTextTheme.bodyLarge?.copyWith(color: AppColors.n50),
    errorStyle:
        AppTextTheme.lightTextTheme.titleSmall?.copyWith(color: AppColors.r50),
    floatingLabelStyle:
        const TextStyle().copyWith(color: Colors.black.withOpacity(0.8)),
    border: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
          width: 1,
          color:
              Color(0xffD8DADC)), // TODO this color is not part of colors list
    ),
    enabledBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
          width: 1,
          color:
              Color(0xffD8DADC)), // TODO this color is not part of colors list
    ),
    disabledBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
          width: 1,
          color:
              Color(0xffD8DADC)), // TODO this color is not part of colors list
    ),
    focusedBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(width: 1, color: AppColors.brand),
    ),
    errorBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(width: 1, color: AppColors.r50),
    ),
  );

  static InputDecorationTheme darkInputDecorationTheme = InputDecorationTheme(
    errorMaxLines: 3,
    prefixIconColor: Colors.grey,
    suffixIconColor: Colors.grey,
// constraints: const BoxConstraints.expand(height: 14.inputFieldHeight),
    labelStyle: const TextStyle().copyWith(fontSize: 14, color: Colors.white),
    hintStyle: const TextStyle()
        .copyWith(fontSize: 14, color: Colors.white.withOpacity(0.5)),
    floatingLabelStyle:
        const TextStyle().copyWith(color: Colors.white.withOpacity(0.8)),
    border: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(width: 1, color: Colors.grey),
    ),
    enabledBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(width: 1, color: Colors.grey),
    ),
    focusedBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(width: 1, color: Colors.white),
    ),
    errorBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(width: 1, color: Colors.red),
    ),
    focusedErrorBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(width: 2, color: Colors.orange),
    ),
  );
}
