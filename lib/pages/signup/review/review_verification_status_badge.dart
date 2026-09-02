import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class ReviewVerificationStatusBadge extends StatelessWidget {
  const ReviewVerificationStatusBadge({
    super.key,
    required this.verificationStatus,
    this.statusImage,
  });
  final VerificationStatus verificationStatus;
  final String? statusImage;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: verificationStatus.bgColor,
        borderRadius: BorderRadius.circular(11.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 7.w, top: 1.h, bottom: 1.h),
            child: Text(
              verificationStatus.label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: verificationStatus.labelColor),
            ),
          ),
          SizedBox(width: 3.w),
          RemoteImageHandler(
            imageUrl: statusImage?.cdn ?? '',
            width: 20.w,
          )
        ],
      ),
    );
  }
}
