import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/referrals/widgets/referral_header.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

class HowItWorksModal extends StatelessWidget {
  final String? videoUrl;
  final String? thumbnailUrl;
  final List<dynamic>? howItWorksSteps;
  final String title;

  const HowItWorksModal({
    Key? key,
    this.videoUrl,
    this.thumbnailUrl,
    this.howItWorksSteps,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    return CommonBottomSheetSetup(
      child: Column(
        children: [
          SizedBox(height: 20.h),
          if (videoUrl != null)
            VideoThumbnailWidget(
              videoUrl: videoUrl!,
              thumbnailUrl: thumbnailUrl,
            ),
          if (howItWorksSteps != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.h,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFF5F6F8),
                                Color(0xFF979EF4),
                              ],
                              stops: [0.0, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: 0.65.sw,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 32.h),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.n90),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1.h,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                Color(0xFFF5F6F8),
                                Color(0xFF979EF4),
                              ],
                              stops: [0.0, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Stack(
                    children: [
                      Positioned.fill(
                        left: 17.5.r,
                        top: 30.r,
                        bottom: 10.r,
                        child: Container(
                          decoration: const BoxDecoration(
                            border:
                                Border(left: BorderSide(color: AppColors.n30)),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            List.generate(howItWorksSteps!.length, (index) {
                          final current = howItWorksSteps?[index];
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: index == howItWorksSteps!.length - 1
                                    ? 0
                                    : 32.h),
                            child: HowItWorksItem(
                              index: current?.order ?? 0,
                              title: current?.title,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Container(
            width: 1.sw,
            margin: EdgeInsets.only(top: 40.h, bottom: 8.h),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                languageProvider.getMessage(
                    "okay_understood", "Okay Understood"),
              ),
            ),
          )
        ],
      ),
    );
  }
}
