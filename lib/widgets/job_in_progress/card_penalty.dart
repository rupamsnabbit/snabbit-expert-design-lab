import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

import '../../constants/assets_constants.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import '../attendance_flow/attendance_confirmed.dart';

class YellowCard1 extends StatelessWidget {
  final Map<String, dynamic>? data;
  final LanguageProvider languageProvider;

  const YellowCard1({
    super.key,
    this.data,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (data?["is_yellow_card"] == true) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: AmountBanner(
          prefixIconSize: 80.w,
          valueBoxSize: 100.w,
          amount: anyValueToInt(data?["yellow_card_amount"]),
          amountColor: const Color(0xff6E431F),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  languageProvider.getMessage(
                    "reason_colon",
                    "Reason:",
                  ),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.y60,
                  ),
                ),
              ),
              FittedBox(
                child: Text(
                  languageProvider.getMessage(
                    "arrived_late_caps",
                    "ARRIVED LATE",
                  ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.y60,
                      ),
                ),
              ),
            ],
          ),
          image: AssetConstants.yellowCardBanner,
        ),
      );
    }
    return const SizedBox();
  }
}

class RedCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final LanguageProvider languageProvider;

  const RedCard({
    super.key,
    this.data,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (data?["is_red_card"] == true) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: AmountBanner(
          prefixIconSize: 80.w,
          valueBoxSize: 100.w,
          amount: anyValueToInt(data?["red_card_amount"]),
          amountColor: const Color(0xffC50F1F),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  languageProvider.getMessage(
                    "reason_colon",
                    "Reason:",
                  ),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.r60,
                  ),
                ),
              ),
              FittedBox(
                child: Text(
                  languageProvider.getMessage(
                    "arrived_late_caps",
                    "ARRIVED LATE",
                  ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.r60,
                  ),
                ),
              ),
            ],
          ),
          image: AssetConstants.redCardBanner,
        ),
      );
    }
    return const SizedBox();
  }
}
