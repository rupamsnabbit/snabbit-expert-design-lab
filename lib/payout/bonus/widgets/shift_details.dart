import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/payout/bonus/models/festive_bonus.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class ShiftDetails extends StatelessWidget {
  final TrackerInfo? trackerInfo;
  final Color? bgColor;

  const ShiftDetails({
    super.key,
    this.trackerInfo,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: bgColor,
      ),
      padding: EdgeInsets.fromLTRB(
        8.r,
        11.r,
        8.r,
        8.r,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            textData: trackerInfo?.title,
          ),
          SizedBox(height: 13.h),
          ...trackerInfo?.items?.map((e) {
                final isLast = e == trackerInfo?.items?.last;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
                  child: Row(
                    children: [
                      RemoteImageHandler(
                          imageUrl: e.icon?.url ?? "",
                          height: e.icon?.height?.h),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: CustomText(
                          textData: e.title,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList() ??
              [],
        ],
      ),
    );
  }
}
