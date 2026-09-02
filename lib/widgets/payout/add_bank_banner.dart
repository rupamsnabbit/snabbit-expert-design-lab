import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Widget to display a banner prompting users to add bank account or UPI
class AddBankBanner extends StatelessWidget {
  /// Image URL to display on the right side of the banner
  final String? image;

  /// Callback when the banner is tapped
  final VoidCallback? onTap;

  const AddBankBanner({
    super.key,
    this.image,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final textTheme = Theme.of(context).textTheme;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            // width: 361.w,
            // height: 90.h,
            decoration: BoxDecoration(
              color: AppColors.r0,
              borderRadius: BorderRadius.circular(11.08.r),
            ),
            padding: EdgeInsets.fromLTRB(17.w, 7.h, 20.w, 0),
            child: Row(
              children: [
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 179.w,
                        height: 28.h,
                        child: Text(
                          languageProvider.getMessage(
                            'add_upi_bank_account_to_enable_payout',
                            'Add UPI / bank account to enable payout',
                          ),
                          style: textTheme.displayMedium?.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            color: AppColors.r50,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      // Add Details button
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.r40,
                          borderRadius: BorderRadius.circular(19.86.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 4.w,
                            ),
                            Text(
                              languageProvider.getMessage(
                                'add_details',
                                'Add Details',
                              ),
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                height: 18 / 12,
                                letterSpacing: -0.265,
                                color: AppColors.n0,
                              ),
                            ),
                            // Chevron icon
                            Icon(Icons.chevron_right,
                                size: 16.r, color: AppColors.n0),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bank institution image
                image != null && image!.isNotEmpty
                    ? RemoteImageHandler(
                        imageUrl: image!,
                        width: 80.w,
                        height: 83.h,
                        fit: BoxFit.contain,
                        errorWidget: Image.asset(
                          AssetConstants.bankInstitution,
                          width: 80.w,
                          height: 83.h,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
                        AssetConstants.bankInstitution,
                        width: 80.w,
                        height: 83.h,
                        fit: BoxFit.contain,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
