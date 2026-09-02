import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/go_live/confirm_shift_timings.dart';
import 'package:snabbit_runner/pages/go_live/weekend_earnings.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/potential_earnings_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/go_live/rays_clockwise_rotation.dart';

class ConfirmPotentialEarnings extends StatefulWidget {
  const ConfirmPotentialEarnings({
    Key? key,
  }) : super(key: key);

  @override
  State<ConfirmPotentialEarnings> createState() =>
      _ConfirmPotentialEarningsState();
}

class _ConfirmPotentialEarningsState extends State<ConfirmPotentialEarnings> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late PotentialEarningsProvider earningsProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      earningsProvider =
          Provider.of<PotentialEarningsProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            top: -150.h,
            child: RaysClockwiseRotation(
              size: 1.sw,
              raysImage: SvgPicture.asset(
                AssetConstants.rotatingRays,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 24.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D1),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // Illustration
              SizedBox(
                height: 175.h,
                width: 1.sw,
                child: SizedBox(
                  child: Image.network(
                    earningsProvider
                            .topSectionData?.assets?.willingToWorkWeekends ??
                        '',
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ), // Replace with image if needed
                ),
              ),
              // SizedBox(height: 24.h),

              Flexible(
                child: Container(
                  color: AppColors.n0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Text section
                      Flexible(
                        child: FittedBox(
                          child: Text(
                            languageProvider.getMessage('earn_more_saturday_sunday','Earn more on Saturday & Sunday?'),
                            textAlign: TextAlign.center,
                            style: textTheme.headlineMedium?.copyWith(
                              letterSpacing: -0.24,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Take selfie button
                      Column(
                        children: [
                          SizedBox(
                            width: 1.sw,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, WeekendEarnings.routeName);
                              },
                              child: Text(
                                languageProvider.getMessage('yes','Yes'),
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.n0,
                                  letterSpacing: -0.24,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          SizedBox(
                            width: 1.sw,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEAEAF1),
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(
                                    context, ConfirmShiftTimings.routeName);
                              },
                              child: Text(
                                languageProvider.getMessage('no','No'),
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              )

            ],
          ),
        ],
      ),
    );
  }
}

void showConfirmPotentialEarnings(
  BuildContext context,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: const ConfirmPotentialEarnings(),
    ),
  );
}
