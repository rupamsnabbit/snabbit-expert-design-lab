import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/auto_ot/todays_shift.dart';
import '../../../providers/auto_ot_provider.dart';
import '../../../services/remote_config/remote_config_assets.dart';
import '../../../utils/colors.dart';
import '../../../widgets/remote_image_handler.dart';

/// Expired/Failure state widget for Auto-OT bottom sheet
///
/// Displays expired message and regular shift details.
class ExpiredStateWidget extends StatelessWidget {
  final OtType otType;

  const ExpiredStateWidget({
    super.key,
    this.otType = OtType.EndOt,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AutoOtProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final details = provider.details;

    if (details == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        image: DecorationImage(
          image: CachedNetworkImageProvider(
            RemoteConfigAssets.autoOtLastStepBg.cdn,
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 20.h),

          // Failure icon
          RemoteImageHandler(
            imageUrl: RemoteConfigAssets.otAssignmentFailureIcon,
            height: 181.h,
            errorWidget: SizedBox(),
          ),

          SizedBox(height: 24.h),

          // Error message
          Text(
            languageProvider.getMessage('sorry_you_were_late_request_expired',
                'Sorry, you were late.\nRequest expired!'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 28 / 22,
                  letterSpacing: -0.24,
                ),
          ),

          SizedBox(height: 24.h),

          // Regular shift details card
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TodaysShiftView(
              otType: otType
            ),
          ),

          SizedBox(height: 20.h),

          // Okay button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              width: 361.w,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandInverted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  languageProvider.getMessage('okay', 'Okay'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        height: 20 / 15,
                        letterSpacing: -0.24,
                      ),
                ),
              ),
            ),
          ),

          SizedBox(height: 17.h),
        ],
      ),
    );
  }
}
