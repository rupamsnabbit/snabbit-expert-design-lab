import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/support_popup.dart';

class EmergencyLogoutUnavailable extends StatefulWidget {
  final int? jobsAvailable;
  final VoidCallback? onPositive;
  final VoidCallback? onNegative;

  const EmergencyLogoutUnavailable({
    super.key,
    this.jobsAvailable,
    this.onPositive,
    this.onNegative,
  });

  @override
  State<EmergencyLogoutUnavailable> createState() =>
      _EmergencyLogoutUnavailableState();
}

class _EmergencyLogoutUnavailableState
    extends State<EmergencyLogoutUnavailable> {
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 24.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              AssetConstants.emergencyBeacon,
              width: 32.w,
              height: 32.h,
            ),
            SizedBox(width: 8.w),
            Text(
              "${widget.jobsAvailable ?? 0} ${languageProvider.getMessage(
                'available',
                'Available',
              )}",
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.n90,
                    fontSize: 32.r,
                  ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Text(
          languageProvider.getMessage(
            'emergency_logout_already_taken',
            'Emergency logout already taken',
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.n80,
              ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24.h),
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return const CommonBottomSheetSetup(
                        child: SupportPopup(),
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.g40,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.phone,
                      size: 16.sp,
                      color: AppColors.n0,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      languageProvider.getMessage(
                        'call_support',
                        'Call Support',
                      ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.n0,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: OutlinedButton(
                onPressed: widget.onNegative,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.n50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  languageProvider.getMessage(
                    'go_back',
                    'Go back',
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.n80,
                      ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
      ],
    );
  }
}

void showEmergencyLogoutUnavailable(
  BuildContext context, {
  int? jobsAvailable,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16.r),
      ),
    ),
    builder: (context) => CommonBottomSheetSetup(
      child: EmergencyLogoutUnavailable(
        jobsAvailable: jobsAvailable,
        onPositive: () {
          Navigator.pop(context);
        },
        onNegative: () {
          Navigator.pop(context);
        },
      ),
    ),
  );
}
