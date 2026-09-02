import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';

class AppElevatedButtonTheme {
  AppElevatedButtonTheme._();

  static ElevatedButtonThemeData lightTextTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: AppColors.brand,
      overlayColor: Colors.white,
      disabledForegroundColor: Color(0xffBCBCCD), // TODO color doesn't exist
      disabledBackgroundColor: Color(0xffEAEAF1), // TODO color doesn't exist
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      textStyle: AppTextTheme.lightTextTheme.labelLarge?.copyWith(color: AppColors.n0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
      ),
    ),
  );
  static ElevatedButtonThemeData darkTextTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 3,
      foregroundColor: Colors.white,
      backgroundColor: Colors.blue,
      disabledForegroundColor: Colors.white,
      disabledBackgroundColor: Colors.grey,
      // side: const BorderSide(color: Colors.blue),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      textStyle: const TextStyle(
          fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
