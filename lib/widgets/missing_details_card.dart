import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

//TODO: CLEAN AND OPTIMIZE
class MissingDetailsCard extends StatelessWidget {
  final String? missingDetails;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? action;
  final double widthFactor;

  const MissingDetailsCard({
    super.key,
    this.missingDetails,
    this.subtitle,
    this.actionText,
    this.action,
    required this.widthFactor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        24.r,
      ),
      alignment: Alignment.topCenter,
      decoration: BoxDecoration(
        color: Colors.white, // White background for the container
        borderRadius: BorderRadius.circular(8.r), // Rounded corners
      ),
      child: SizedBox(
        width: widthFactor,
        child: Row(
          // mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14.r,
              backgroundColor: AppColors.r10,
              child: Icon(
                Icons.priority_high_sharp,
                color: AppColors.r50,
                size: 18,
              ),
            ),
            SizedBox(
              width: 8.w,
            ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                // Make the dialog size fit its content
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    missingDetails ?? "",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.r50,
                        ),
                    textAlign: TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.n70,
                            ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  SizedBox(
                    height: 11.h,
                  ),
                  ElevatedButton(
                    onPressed: action,
                    child: FittedBox(
                      child: Text(
                        actionText ?? "",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
