import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

class CheckInConfirmed extends StatelessWidget {
  const CheckInConfirmed({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context,languageProvider,_) {
        return SizedBox(
          width: 1.sw,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 8.h, bottom: 18.h),
                child: Container(
                  height: 4.h,
                  width: 36.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4.r),
                    color: const Color(0xffD1D1D1),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48.r,
                    height: 48.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.g40,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 30.r,
                      color: AppColors.n0,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 36.w),
                    child: Text(
                      languageProvider.getMessage("check_in_successful",
                          "Check in successful. Please start the job."),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 36.w),
                    child: Container(
                      height: 63.h,
                      decoration: BoxDecoration(
                          color: AppColors.r20,
                          borderRadius: BorderRadius.circular(12.r)
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: Text(
                                languageProvider.getMessage(
                                  'keep_phone_in_pocket',
                                  'Keep phone in pocket',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium
                                    ?.copyWith(
                                    fontSize: 16.sp,
                                    color: AppColors.n90),
                              ),
                            ),
                          ),
                          Image.asset(
                            AssetConstants.phoneInPocketBanner,
                            height: 63.h,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 60.h),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}
