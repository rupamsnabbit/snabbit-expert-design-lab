import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class OnboardingCallout extends StatelessWidget {
  const OnboardingCallout({
    super.key,
    this.callOut,
    this.padding,
  });

  final CallOutData? callOut;
  final EdgeInsets? padding;

  bool get _hasValidMessage => (callOut?.description ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasValidMessage) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: padding ?? EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: callOut?.backgroundColor ?? const Color(0xffFFF8EC),
        border: Border.all(
          color: callOut?.borderColor ?? const Color(0xffF7D9A4),
          width: 1.w,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if ((callOut?.icon ?? '').isNotEmpty) ...[
            RemoteImageHandler(
              imageUrl: callOut?.icon?.cdn ?? '',
              width: 22.r,
              errorWidget: const SizedBox(),
            ),
            SizedBox(width: 16.w),
          ],
          Expanded(
            child: Text(
              callOut?.description ?? '',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: callOut?.foregroundColor ?? AppColors.y50,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
