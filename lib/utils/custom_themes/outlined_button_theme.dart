import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';

class AppOutlinedButtonTheme {
  AppOutlinedButtonTheme._(); //To avoid creating instances
/* -- Light Theme -- */
  static OutlinedButtonThemeData lightOutlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      elevation: 0,
      foregroundColor: AppColors.n0,
      side: const BorderSide(color: AppColors.n0),
      textStyle: AppTextTheme.lightTextTheme.labelLarge,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
    ),
  ); // OutlinedButtonThemeData
/* -- Dark Theme -- */
  static OutlinedButtonThemeData darkOutlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.blueAccent),
      textStyle: const TextStyle(
          fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ); // OutlinedButtonThemeData
}

class AppTextButtonTheme {
  AppTextButtonTheme._();
  static TextButtonThemeData lightTextButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.brand,
      // side: const BorderSide(color: Colors.blue),
      textStyle: AppTextTheme.lightTextTheme.labelLarge,
      // padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
