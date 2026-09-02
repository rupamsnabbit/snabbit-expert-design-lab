import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

bool _isNullOrZeroEarningAmount(String amount) {
  final trimmed = amount.trim();
  if (trimmed.isEmpty) return true;
  final cleaned = trimmed.replaceAll(RegExp(r'[^\d.]'), '');
  if (cleaned.isEmpty) return true;
  final value = double.tryParse(cleaned);
  return value == null || value == 0;
}

class EarningLossBottomSheet extends StatelessWidget {
  final String earningLossAmount;
  final VoidCallback onMarkAbsent;
  final VoidCallback onMarkPresent;

  const EarningLossBottomSheet({
    super.key,
    required this.earningLossAmount,
    required this.onMarkAbsent,
    required this.onMarkPresent,
  });

  static const _gray900 = Color(0xFF111827);
  static const _red600 = Color(0xFFDC2626);
  static const _green600 = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: Stack(
        children: [
          // Pink gradient background
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.r),
              topRight: Radius.circular(24.r),
            ),
            child: SizedBox(
              height: 185.h,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: kNudgesBottomSheetBackgroundUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.only(
              left: 16.w,
              right: 16.w,
              top: 24.h,
              bottom: 48.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular SVG icon
                SvgPicture.asset(
                  'assets/svgs/loss_earning_circle_icon.svg',
                  width: 100.r,
                  height: 100.r,
                ),

                SizedBox(height: 16.h),

                // Title text
                Text(
                  _isNullOrZeroEarningAmount(earningLossAmount)
                      ? lang.getMessage(
                          'earning_loss_confirm_no_amount',
                          'You will lose your earnings \n for tomorrow, Are you sure?',
                        )
                      : lang.getFormattedMessage(
                          'earning_loss_confirm',
                          'You can earn ₹{{amount}} tomorrow.\nAre you sure?',
                          {'amount': earningLossAmount},
                        ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: _gray900,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    height: 32 / 24,
                  ),
                ),

                SizedBox(height: 24.h),

                // Absent / Present buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56.h,
                        child: ElevatedButton.icon(
                          onPressed: onMarkAbsent,
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: Text(
                            lang.getMessage('absent', 'Absent'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.white,
                              letterSpacing: -0.24,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _red600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: SizedBox(
                        height: 56.h,
                        child: ElevatedButton.icon(
                          onPressed: onMarkPresent,
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: Text(
                            lang.getMessage('present', 'Present'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.white,
                              letterSpacing: -0.24,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
