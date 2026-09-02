import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

class EarlyLogoutView extends StatelessWidget {
  const EarlyLogoutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return  Container(
          height: 100.h,
          margin: EdgeInsets.only(bottom: 18.h),
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              image: const DecorationImage(
                  image:
                  AssetImage(AssetConstants.earlyLogoutBg))),
          child: Row(
            children: [
              Image.asset(AssetConstants.earlyLogoutExpert),
              Flexible(
                child: FittedBox(
                  child: Text(
                    languageProvider.getMessage(
                        "early_logout_message",
                        "Today's work is over Early Logout"),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
