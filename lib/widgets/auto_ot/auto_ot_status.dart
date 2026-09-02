import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/auto_ot_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class AutoOtStatusView extends StatelessWidget {
  final EdgeInsets? margin;
  final OtType otType;

  const AutoOtStatusView({
    super.key,
    this.margin,
    this.otType = OtType.EndOt,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<AutoOtProvider, LanguageProvider>(
        builder: (context, provider, languageProvider, _) {
      final String message = otType == OtType.StartOt
          ? languageProvider.getMessage(
              provider.details?.status?.title ?? 'change_only_for_tomorrow',
              'Change in timings only for tomorrow')
          : languageProvider.getMessage(
              provider.details?.status?.title ?? 'change_only_for_today',
              'Change in timings only for today');
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 6.h,
        ),
        margin: margin ??
            EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 20.h,
            ),
        decoration: BoxDecoration(
          color: provider.details?.status?.bgColor ?? AppColors.y10,
          borderRadius: BorderRadius.circular(70.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RemoteImageHandler(
              imageUrl: provider.details?.status?.icon?.cdn ?? '',
              width: 16.w,
              errorWidget: Icon(Icons.info, color: AppColors.y50, size: 16.r),
            ),
            SizedBox(width: 8.w),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 12 / 12,
                    color: provider.details?.status?.textColor ?? AppColors.y50,
                    letterSpacing: -0.24,
                  ),
            ),
          ],
        ),
      );
    });
  }
}
