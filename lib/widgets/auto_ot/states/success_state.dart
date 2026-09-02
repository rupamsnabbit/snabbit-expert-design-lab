import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/auto_ot/ot_shift.dart';
import '../../../providers/auto_ot_provider.dart';
import '../../../services/remote_config/remote_config_assets.dart';
import '../../../utils/colors.dart';
import '../../../widgets/remote_image_handler.dart';

/// Success state widget for Auto-OT bottom sheet
///
/// Displays success message and confirmed OT shift details.
class SuccessStateWidget extends StatelessWidget {
  final OtType otType;

  const SuccessStateWidget({
    super.key,
    this.otType = OtType.EndOt,
  });

  @override
  Widget build(BuildContext context) {
    final autoOtProvider = Provider.of<AutoOtProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    final details = autoOtProvider.details;

    if (details == null) {
      return const SizedBox.shrink();
    }

    final String headline = otType == OtType.StartOt
        ? languageProvider.getMessage(
            'early_shift_confirmed_tomorrow',
            'Congrats!\nOvertime confirmed for tomorrow!')
        : languageProvider.getMessage(
            'congrats_overtime_confirmed',
            'Congrats!\nOvertime confirmed.');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          // Success animation/image
          RemoteImageHandler(
            imageUrl: RemoteConfigAssets.otAssignmentSuccessIcon,
            height: 200.h,
          ),

          SizedBox(height: 24.h),

          // Title
          Text(
            headline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 28 / 22,
                  letterSpacing: -0.24,
                ),
          ),

          SizedBox(height: 24.h),

          // OT shift details card
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: OtShiftView(),
          ),

          SizedBox(height: 20.h),

          // Close button
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
                  languageProvider.getMessage('close', 'Close'),
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
