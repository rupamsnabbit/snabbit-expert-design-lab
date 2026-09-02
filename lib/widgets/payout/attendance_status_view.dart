import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../providers/daily_earnings.dart';
import '../../providers/language_provider.dart';
import '../../utils/app_strings.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
class PresentWidget extends StatelessWidget {
  final DailyEarningListItem item;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;

  const PresentWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.n40),
        ),
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Row(
            children: [
              // Date container
              Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAF1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                padding: EdgeInsets.all(12.r),
                child: FittedBox(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.date.day.toString(),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: AppColors.n90,
                          fontStyle: FontStyle.normal,
                          fontSize: 22.sp,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(item.date).toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: AppColors.n70),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // Middle section with status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getMessage('present', 'Present'),
                      style:
                      Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 16.sp,
                        color: AppColors.g50,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),

              // Amount and chevron
              Row(
                children: [
                  Text(
                    formatIndianCurrency(item.amount ?? 0),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 16.sp,
                      color: (item.amount ?? 0) < 0
                          ? AppColors.r50
                          : AppColors.n90,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.n90,
                  ),
                  SizedBox(width: 10.w),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AbsentWidget extends StatelessWidget {
  final DailyEarningListItem item;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;

  const AbsentWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.n40),
        ),
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Row(
            children: [
              // Date container
              Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAF1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                padding: EdgeInsets.all(12.r),
                child: FittedBox(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.date.day.toString(),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: AppColors.n90,
                          fontStyle: FontStyle.normal,
                          fontSize: 22.sp,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(item.date).toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: AppColors.n70),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // Middle section with status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getMessage('absent', 'Absent'),
                      style:
                      Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 16.sp,
                        color: AppColors.r50,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),

              // Amount and chevron
              Row(
                children: [
                  Text(
                    formatIndianCurrency(item.amount ?? 0),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 16.sp,
                      color: (item.amount ?? 0) < 0
                          ? AppColors.r50
                          : AppColors.n90,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.n90,
                  ),
                  SizedBox(width: 10.w),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FalseAttendanceWidget extends StatelessWidget {
  final DailyEarningListItem item;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;

  const FalseAttendanceWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.r0,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.r50),
        ),
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Row(
            children: [
              // Date container
              Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  color: AppColors.r10,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                padding: EdgeInsets.all(12.r),
                child: FittedBox(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.date.day.toString(),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: AppColors.n90,
                          fontStyle: FontStyle.normal,
                          fontSize: 22.sp,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(item.date).toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: AppColors.n70),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // Amount and chevron
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            languageProvider.getMessage(
                              'false_attendance',
                              'False Attendance',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                              fontSize: 16.sp,
                              color: AppColors.r50,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            SizedBox(width: 16.w),
                            Text(
                              formatIndianCurrency(item.amount ?? 0),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                fontSize: 16.sp,
                                color: AppColors.r50,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.n90,
                            ),
                            SizedBox(width: 10.w),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        ...[
                          AppStrings.provisional,
                          AppStrings.morning,
                        ].asMap().entries.map((entry) {
                          final tag = entry.value;
                          final isSuccessTag = tag != AppStrings.morning;

                          return Row(
                            children: [
                              if (entry.key > 0)
                                Container(
                                  height: 14.h,
                                  width: 1,
                                  margin: EdgeInsets.symmetric(horizontal: 8.w),
                                  color: AppColors.r10,
                                ),
                              Row(
                                children: [
                                  Container(
                                    width: 16.r,
                                    height: 16.r,
                                    decoration: BoxDecoration(
                                      color: isSuccessTag
                                          ? AppColors.g40
                                          : AppColors.r50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSuccessTag ? Icons.check : Icons.close,
                                      size: 10.r,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    languageProvider.getMessage(
                                      tag.toLowerCase(),
                                      tag.toUpperCase(),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                      color: AppColors.n70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FalseAttendanceWarningWidget extends StatelessWidget {
  final DailyEarningListItem item;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;

  const FalseAttendanceWarningWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.n40),
        ),
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Column(
            children: [
              Row(
                children: [
                  // Date container
                  Container(
                    width: 64.r,
                    height: 64.r,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEAF1),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.all(12.r),
                    child: FittedBox(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.date.day.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                              color: AppColors.n90,
                              fontStyle: FontStyle.normal,
                              fontSize: 22.sp,
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(item.date).toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: AppColors.n70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Middle section with status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.getMessage(
                              'false_attendance', 'False Attendance'),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                            fontSize: 16.sp,
                            color: AppColors.r50,
                          ),
                        ),
                        SizedBox(height: 5.5.h),
                        Text(
                          languageProvider.getMessage('warning', 'Warning!'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: AppColors.n70),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),

                  // Amount and chevron
                  Row(
                    children: [
                      Text(
                        formatIndianCurrency(item.amount ?? 0),
                        style:
                        Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 16.sp,
                          color: (item.amount ?? 0) < 0
                              ? AppColors.r50
                              : AppColors.n90,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.n90,
                      ),
                      SizedBox(width: 10.w),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoShowWarningWidget extends StatelessWidget {
  final DailyEarningListItem item;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;

  const NoShowWarningWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.n40),
        ),
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Column(
            children: [
              Row(
                children: [
                  // Date container
                  Container(
                    width: 64.r,
                    height: 64.r,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEAF1),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.all(12.r),
                    child: FittedBox(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.date.day.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                              color: AppColors.n90,
                              fontStyle: FontStyle.normal,
                              fontSize: 22.sp,
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(item.date).toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: AppColors.n70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Middle section with status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.getMessage(
                              'no_show', 'No Show'),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                            fontSize: 16.sp,
                            color: AppColors.r50,
                          ),
                        ),
                        SizedBox(height: 5.5.h),
                        Text(
                          languageProvider.getMessage('warning', 'Warning!'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: AppColors.n70),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),

                  // Amount and chevron
                  Row(
                    children: [
                      Text(
                        formatIndianCurrency(item.amount ?? 0),
                        style:
                        Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 16.sp,
                          color: (item.amount ?? 0) < 0
                              ? AppColors.r50
                              : AppColors.n90,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.n90,
                      ),
                      SizedBox(width: 10.w),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoShowWidget extends StatelessWidget {
  final DailyEarningListItem item;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;

  const NoShowWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.r0,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.r50),
        ),
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Row(
            children: [
              // Date container
              Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  color: AppColors.r10,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                padding: EdgeInsets.all(12.r),
                child: FittedBox(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.date.day.toString(),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: AppColors.n90,
                          fontStyle: FontStyle.normal,
                          fontSize: 22.sp,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(item.date).toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: AppColors.n70),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // Amount and chevron
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            languageProvider.getMessage(
                              'no_show',
                              'No Show',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                              fontSize: 16.sp,
                              color: AppColors.r50,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            SizedBox(width: 16.w),
                            Text(
                              formatIndianCurrency(item.amount ?? 0),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                fontSize: 16.sp,
                                color: AppColors.r50,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.n90,
                            ),
                            SizedBox(width: 10.w),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        ...[
                          AppStrings.provisional,
                          AppStrings.morning,
                          AppStrings.login
                        ].asMap().entries.map((entry) {
                          final tag = entry.value;
                          final isSuccessTag = tag != AppStrings.login;

                          return Row(
                            children: [
                              if (entry.key > 0)
                                Container(
                                  height: 14.h,
                                  width: 1,
                                  margin: EdgeInsets.symmetric(horizontal: 8.w),
                                  color: AppColors.r10,
                                ),
                              Row(
                                children: [
                                  Container(
                                    width: 16.r,
                                    height: 16.r,
                                    decoration: BoxDecoration(
                                      color: isSuccessTag
                                          ? AppColors.g40
                                          : AppColors.r50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSuccessTag ? Icons.check : Icons.close,
                                      size: 10.r,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    languageProvider.getMessage(
                                      tag.toLowerCase(),
                                      tag.toUpperCase(),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                      color: AppColors.n70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}