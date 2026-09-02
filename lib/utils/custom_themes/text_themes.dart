import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class AppTextTheme {
  AppTextTheme._();

  static TextStyle errStyle = TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w500,
    color: AppColors.r40,
    letterSpacing: 0.24,
  );

  static TextStyle hintStyle = TextStyle(
    fontSize: 15.sp,
    fontWeight: FontWeight.w500,
    color: AppColors.n50,
  );

  static TextTheme lightTextTheme = TextTheme(
    /// title 1
    headlineLarge: const TextStyle().copyWith(
      fontSize: 22.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.n90,
    ),

    /// title 2
    headlineMedium: const TextStyle().copyWith(
      fontSize: 20.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.n90,
    ),

    /// title 3
    headlineSmall: const TextStyle().copyWith(
      fontSize: 17.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.n90,
      letterSpacing: 0.24,
    ),

    /// button 1
    labelLarge: const TextStyle().copyWith(
      fontSize: 15.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.n90,
      letterSpacing: 0.5,
    ),

    /// button 2, sub heading
    labelMedium: const TextStyle().copyWith(
      fontSize: 13.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.n90,
      letterSpacing: 0.24,
    ),

    /// body 1
    bodyLarge: const TextStyle().copyWith(
      fontSize: 15.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.n90,
      letterSpacing: 0.24,
    ),

    /// body 2
    bodyMedium: const TextStyle().copyWith(
      fontSize: 13.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.n90,
    ),

    /// body 3
    bodySmall: const TextStyle().copyWith(
      fontSize: 12.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.n90,
    ),

    /// caption 1
    titleSmall: const TextStyle().copyWith(
      fontSize: 13.sp,
      fontWeight: FontWeight.w400,
      color: AppColors.n90,
    ),

    /// caption 2
    titleMedium: const TextStyle().copyWith(
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      color: AppColors.n70,
    ),

    /// overline
    titleLarge: const TextStyle().copyWith(
      fontSize: 10.sp,
      fontWeight: FontWeight.w600,
      color: AppColors.n90,
    ),

    /// Payout display theme
    displayLarge: const TextStyle().copyWith(
      fontSize: 24.sp,
      fontWeight: FontWeight.w800,
      color: const Color(0xff40515B),
      // fontStyle: FontStyle.italic,
      // fontFamily: "MetropolisBlack",
    ),
    displayMedium: const TextStyle().copyWith(
      fontSize: 14.sp,
      fontWeight: FontWeight.w700,
      color: const Color(0xff40515B),
      // fontFamily: "MetropolisBlack",
    ),
    displaySmall: const TextStyle().copyWith(
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
      color: const Color(0xffA0A7AE),
      // fontFamily: "MetropolisBlack",
    ),
  );
  static TextTheme darkTextTheme = TextTheme(
    headlineLarge: const TextStyle().copyWith(
        fontSize: 32.sp, fontWeight: FontWeight.bold, color: Colors.white),
    headlineMedium: const TextStyle().copyWith(
        fontSize: 24.sp, fontWeight: FontWeight.w600, color: Colors.white),
    headlineSmall: const TextStyle().copyWith(
        fontSize: 18.sp, fontWeight: FontWeight.w600, color: Colors.white),
    titleLarge: const TextStyle().copyWith(
        fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.white),
    titleMedium: const TextStyle().copyWith(
        fontSize: 16.sp, fontWeight: FontWeight.w500, color: Colors.white),
    titleSmall: const TextStyle().copyWith(
        fontSize: 16.sp, fontWeight: FontWeight.w400, color: Colors.white),
    bodyLarge: const TextStyle().copyWith(
        fontSize: 14.sp, fontWeight: FontWeight.w500, color: Colors.white),
    bodyMedium: const TextStyle().copyWith(
        fontSize: 14.sp, fontWeight: FontWeight.normal, color: Colors.white),
    bodySmall: const TextStyle().copyWith(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: Colors.white.withOpacity(0.5)),
    labelLarge: const TextStyle().copyWith(
        fontSize: 12.sp, fontWeight: FontWeight.normal, color: Colors.white),
    labelMedium: const TextStyle().copyWith(
        fontSize: 12.sp,
        fontWeight: FontWeight.normal,
        color: Colors.white.withOpacity(0.5)),
  );
}
