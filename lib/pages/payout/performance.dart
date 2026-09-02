import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';

import '../../providers/payout.dart';
import '../../services/payout_http.dart';
import '../../utils/colors.dart';
import '../../utils/enums.dart';
import '../../widgets/drawer/drawer_menu.dart';
import '../../widgets/payout/current_period_view.dart';
import '../../widgets/payout/payout_section_container.dart';
import '../../widgets/payout/ratings_breakdown.dart';

class Performance extends StatefulWidget {
  static const String routeName = "/performance";

  const Performance({super.key});

  @override
  State<Performance> createState() => _PerformanceState();
}

class _PerformanceState extends State<Performance> {
  bool init = true;
  bool loading = true;
  String? error;
  late PayoutProvider payoutProvider;
  late CurrentPeriodProvider currentPeriodProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    try {
      Response? response = await PayoutHttp.getRatings(
          start: currentPeriodProvider.monthStartDate,
          end: currentPeriodProvider.monthEndDate);
      if (response != null) {
        error = null;
        payoutProvider.setRatings(response.data);
      } else {
        error = "Something went wrong";
      }
    } catch (e) {
      error = "Something went wrong - $e";
    }
  }

  bool ratingsAvailable() {
    try {
      return payoutProvider.ratings?.ratedJobs != null &&
          payoutProvider.ratings!.ratedJobs! != 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        centerTitle: true,
        title: Text(
          "Performance",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 20.h,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    PayoutSectionContainer(
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: CurrentPeriodView(
                              viewType: PayoutPeriod.monthly,
                              onChanged: () async {
                                setState(() {
                                  loading = true;
                                });
                                await initProcess();
                                setState(() {
                                  loading = false;
                                });
                              },
                            ),
                          ),
                          if (error == null)
                            Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4.h),
                                  child: const Divider(
                                    color: AppColors.n30,
                                  ),
                                ),
                                Text(
                                  "Mahine ki Rating",
                                  style:
                                      Theme.of(context).textTheme.displaySmall,
                                ),
                                SizedBox(height: 9.h),
                                ratingsAvailable()
                                    ? RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                                  "${payoutProvider.ratings?.ratingCurrentMonth ?? 0}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displayLarge,
                                            ),
                                            const WidgetSpan(
                                              child: Icon(
                                                Icons.star_rounded,
                                                color: Color(0xff40515B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Text(
                                        "No ratings yet",
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge,
                                      ),
                                if (ratingsAvailable())
                                  Padding(
                                    padding: EdgeInsets.only(top: 20.h),
                                    child: StarRating(
                                      rating: payoutProvider
                                              .ratings?.ratingCurrentMonth ??
                                          0,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    error != null
                        ? Center(
                            child: Text(error ?? ""),
                          )
                        : Column(
                            children: [
                              Accolades(payoutProvider: payoutProvider),
                              Improvements(payoutProvider: payoutProvider),
                              if (ratingsAvailable())
                                Padding(
                                  padding: EdgeInsets.only(top: 8.h),
                                  child: PayoutSectionContainer(
                                    child: RatingsBreakdown(
                                      averageRating: payoutProvider
                                              .ratings?.ratingCurrentMonth ??
                                          0,
                                      totalReviews:
                                          payoutProvider.ratings?.ratedJobs ??
                                              0,
                                      ratings: payoutProvider
                                          .ratings?.ratingBreakdown,
                                    ),
                                  ),
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

class Accolades extends StatelessWidget {
  final PayoutProvider payoutProvider;

  const Accolades({
    super.key,
    required this.payoutProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: PayoutSectionContainer(
        child: Column(
          children: [
            Text(
              "Tareef",
              style: Theme.of(context).textTheme.displayMedium,
            ),
            Text(
              "Customer ne aap ki tareef ki",
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xffA0A7AE)),
            ),
            SizedBox(
              height: 12.h,
              width: 1.sw,
            ),
            if (payoutProvider.ratings?.accolades != null &&
                payoutProvider.ratings!.accolades!.isNotEmpty)
              RichText(
                text: TextSpan(
                  children: payoutProvider.ratings?.accolades?.map((e) {
                    if (e != null) {
                      return WidgetSpan(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 4.h,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1000.r),
                              border: Border.all(color: AppColors.n60),
                            ),
                            padding: EdgeInsets.all(8.r),
                            child: Text(
                              e,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.n80),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const WidgetSpan(child: SizedBox());
                    }
                  }).toList(),
                ),
              )
            else
              Text(
                "“Abhi aap ki koi ratings nahi aayi. Please customer se ratings maangye”",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.n60),
              ),
            // Text(
            //   "“ TEXT goes HERE ”",
            //   style: Theme.of(context)
            //       .textTheme
            //       .labelMedium
            //       ?.copyWith(
            //         fontWeight: FontWeight.w700,
            //         fontStyle: FontStyle.italic,
            //         color: const Color(0xff40515B),
            //       ),
            // ),
            // SizedBox(height: 8.h),
            // FittedBox(
            //   fit: BoxFit.scaleDown,
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: List.generate(
            //       5,
            //       (index) {
            //         return Padding(
            //           padding: EdgeInsets.symmetric(
            //               horizontal: 2.w),
            //           child: Icon(
            //             Icons.star_rounded,
            //             size: 16.sp,
            //             color: AppColors.y40,
            //           ),
            //         );
            //       },
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class Improvements extends StatelessWidget {
  final PayoutProvider payoutProvider;

  const Improvements({
    super.key,
    required this.payoutProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: PayoutSectionContainer(
        child: Column(
          children: [
            Text(
              "Kripya Sudharein",
              style: Theme.of(context).textTheme.displayMedium,
            ),
            Text(
              "Sudhar ki zarurat hai",
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xffA0A7AE)),
            ),
            SizedBox(
              height: 12.h,
              width: 1.sw,
            ),
            if (payoutProvider.ratings?.improvements != null &&
                payoutProvider.ratings!.improvements!.isNotEmpty)
              RichText(
                text: TextSpan(
                  children: payoutProvider.ratings?.improvements?.map((e) {
                    if (e != null) {
                      return WidgetSpan(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 4.h,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1000.r),
                              border: Border.all(color: AppColors.n60),
                            ),
                            padding: EdgeInsets.all(8.r),
                            child: Text(
                              e,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.n80),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const WidgetSpan(child: SizedBox());
                    }
                  }).toList(),
                ),
              )
            else
              Text(
                "“Aap badhiya kaam kar rahe ho. Accha kaam karte raho”",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.n60),
              ),
          ],
        ),
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating; // Accepts rating between 0.0 to 5.0

  const StarRating({
    super.key,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          // Fully filled star
          return Icon(Icons.star_rounded, size: 36.sp, color: AppColors.y40);
        } else if (index < rating) {
          // Half-filled star (Optional)
          return Icon(Icons.star_half_rounded,
              size: 36.sp, color: AppColors.y40);
        } else {
          // Empty star with border
          return Icon(Icons.star_border_rounded,
              size: 36.sp, color: AppColors.n60);
        }
      }),
    );
  }
}
