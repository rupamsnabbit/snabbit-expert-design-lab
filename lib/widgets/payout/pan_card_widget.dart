import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_widgets/add_button_with_dashed_border.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_add_details_banner.dart';
import 'package:snabbit_runner/widgets/payout/pan_details_bottom_sheet.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/upload_documents/upload_pan_modal_sheet_v2.dart';

/// Widget to display PAN card details or prompt to add PAN card
/// Shows PAN number if available, otherwise shows add PAN card UI
class PanCardWidget extends StatelessWidget {
  const PanCardWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, userProfileProvider, child) {
        final languageProvider = Provider.of<LanguageProvider>(context);
        final panNumber = userProfileProvider.user?.pan;
        final isPanVerified = userProfileProvider.user?.isPanVerified == true;
        final hasPan =
            panNumber != null && panNumber.isNotEmpty && isPanVerified;

        if (hasPan) {
          return _buildPanCardView(context, languageProvider, panNumber);
        } else {
          return _buildAddPanView(context, languageProvider);
        }
      },
    );
  }

  /// Builds the view when PAN card is available
  Widget _buildPanCardView(
    BuildContext context,
    LanguageProvider languageProvider,
    String? panNumber,
  ) {
    return GestureDetector(
      onTap: () {
        showPanDetailsBottomSheet(context: context);
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(12.w, 16.h, 16.w, 12.h),
        decoration: BoxDecoration(
          color: AppColors.n0,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 1),
              blurRadius: 4,
            ),
          ],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon and PAN details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ID card icon
                RemoteImageHandler(
                    imageUrl: RemoteConfigAssets.panIdCardMiniBanner,
                    width: 21.w,
                    errorWidget: const SizedBox()),
                SizedBox(width: 12.w),
                // PAN No and number
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      languageProvider.getMessage(
                        'pan_no',
                        'PAN No',
                      ),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.02,
                            height: 22 / 14,
                            color: AppColors.n90,
                          ),
                    ),
                    Text(
                      panNumber ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.02,
                            height: 22 / 13,
                            color: AppColors.n90,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            // Chevron icon
            Container(
              width: 24.w,
              height: 24.h,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.n30,
                  width: 1.5.r,
                ),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(
                Icons.chevron_right,
                size: 16.r,
                color: AppColors.n90,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the view when PAN card is not available
  Widget _buildAddPanView(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    return Container(
      width: 361.w,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.n0,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add button with dashed border
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  constraints: BoxConstraints(
                    maxHeight: 0.7.sh,
                  ),
                  builder: (ctx) {
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(ctx).viewInsets.bottom),
                      child: const UploadPanModalSheetV2(),
                    );
                  });
            },
            child: SizedBox(
              width: 329.w,
              height: 52.h,
              child: AddButtonWithDashedBorder(
                text: languageProvider.getMessage(
                  'add_pan_card_details',
                  'Add PAN card details',
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Custom add details banner (without subtitle button)
          SizedBox(
            width: 329.w,
            // height: 52.h,
            child: CustomAddDetailsBanner(
              title: {
                "key": "pan_card_benefit_text",
                "text": "{{pan_card_highlight}} helps reduce Income Tax",
                "style": {
                  "name": "Metropolis",
                  "font_size": 14,
                  "color": "#C50F1F",
                  "weight": 600,
                  "style": "normal"
                },
                "data": [
                  {
                    "key": "pan_card_highlight",
                    "text": "PAN Card",
                    "style": {
                      "name": "Metropolis",
                      "font_size": 14,
                      "color": "#C50F1F",
                      "weight": 800,
                      "style": "normal"
                    }
                  }
                ],
                "alignment": "left"
              },
              image: RemoteConfigAssets.addPanMiniBanner,
              backgroundColor: AppColors.r0,
              padding: EdgeInsets.zero,
              imageWidth: 51.w,
              titlePadding: EdgeInsets.all(12.r),
            ),
          ),
        ],
      ),
    );
  }
}
