import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/pages/signup/review/review_verification_status_badge.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/overlapping_widget_setup.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class ReviewAnswerV2 extends StatefulWidget {
  const ReviewAnswerV2(
      {super.key, this.answer, required this.verificationStatus});
  final String? answer;
  final VerificationStatus verificationStatus;

  @override
  State<ReviewAnswerV2> createState() => _ReviewAnswerV2State();
}

class _ReviewAnswerV2State extends State<ReviewAnswerV2> {
  @override
  Widget build(BuildContext context) {
    bool isUnverified =
        widget.verificationStatus == VerificationStatus.unverified;
    // Todo: Set showEditWarning using relevant conditions
    bool showEditWarning = true;
    return OverlappingStackWidget(
      mainWidget: Container(
        decoration: !isUnverified
            ? null
            : BoxDecoration(
                // Todo: Add this color to AppColors
                border: Border.all(color: Color(0xffD8DADC)),
                borderRadius: BorderRadius.circular(10.r),
                color: AppColors.n0,
              ),
        padding: isUnverified ? EdgeInsets.all(16.r) : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.answer ?? "",
                style: isUnverified
                    ? Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: AppColors.n70)
                    : Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.n70,
                        ),
              ),
            ),
            SizedBox(
              width: 16.w,
            ),
            ReviewVerificationStatusBadge(
                verificationStatus: widget.verificationStatus),
          ],
        ),
      ),
      // Todo: Maybe add another condition to display this or not
      bottomWidget: isUnverified && showEditWarning
          ? Container(
              decoration: !isUnverified
                  ? null
                  : BoxDecoration(
                      // Todo: Add this color to AppColors
                      border: Border.all(color: Color(0xffF7D9A4)),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(10.r),
                        bottomRight: Radius.circular(10.r),
                        topLeft: Radius.circular(0),
                        topRight: Radius.circular(0),
                      ),
                      color: Color(0xffFFF8EC),
                    ),
              padding: EdgeInsets.only(
                  top: 22.h, left: 20.w, right: 27.w, bottom: 14.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Todo: Get this icon from the server
                  RemoteImageHandler(
                    imageUrl:
                        "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/referrals/rupee_coin.png",
                    width: 24.w,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'The details entered would be manually verified.'
                      ' Entering wrong details can result in Termination.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.y50,
                          ),
                    ),
                  )
                ],
              ),
            )
          : SizedBox.shrink(),
      bottomOverlap: isUnverified ? 8.h : 0,
    );
  }
}
