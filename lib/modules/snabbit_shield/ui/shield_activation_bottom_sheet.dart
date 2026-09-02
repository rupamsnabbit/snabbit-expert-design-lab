import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:snabbit_runner/modules/snabbit_shield/ui/shield_background_circles_painter.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Bottom sheet shown when Snabbit Shield starts (capped by Remote Config,
/// persisted across sessions via SharedPreferences).
/// Layout matches Figma 22879-8487: gradient bg, vector lines, shield icon,
/// "Snabbit Kavach" title, headline, subtitle, "Got it" CTA.
class ShieldActivationBottomSheet extends StatelessWidget {
  const ShieldActivationBottomSheet({super.key});

  /// Shows the bottom sheet as a modal. Returns `true` if user tapped "Got it",
  /// `null` if dismissed by swipe. Caller is responsible for checking
  /// cap and persistence (e.g. via _maybeShowShieldActivationSheet).
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.n0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) => CommonBottomSheetSetup(
        horizontalPadding: 0,
        bottomPadding: 24,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(52, 163, 252, 0),
            Color(0xFFFFFFFF),
          ],
          stops: [0.0, 0.422],
        ),
        child: const ShieldActivationBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(top: 0.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 234.h,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    left: -17.w,
                    right: -17.w,
                    top: 20,
                    height: 107.h,
                    child: SvgPicture.asset(
                      'assets/svgs/shield_vector_lines_blue.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ShieldBackgroundCirclesPainter(),
                    ),
                  ),
                  // Shield icon (Figma 22879:8777)
                  Positioned(
                    top: 12,
                    child: Image.asset(
                      'assets/pngs/shield_icon_blue.png',
                      width: 190.w,
                      height: 190.h,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // "Snabbit Kavach" at bottom of hero (Figma 22879:8550 – 20px, #016ee6)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: _ActivationShieldTitle(
                      title: lang.getMessage(
                          'snabbit_shield_activation_title', 'Snabbit Kavach'),
                    ),
                  ),
                ],
              ),
            ),
            // Content: headline, subtitle, button (Figma 22879:8552–8493)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  Text(
                    lang.getMessage('snabbit_shield_keep_phone_title',
                        'Always keep your phone with you'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 32.sp,
                          color: const Color(0xFF303030),
                          height: 38 / 32,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    lang.getMessage('snabbit_shield_keep_phone_subtitle',
                        'Snabbit Kavach helps keep you safe using your phone\'s audio and location'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF828282),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          height: 24 / 16,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.shieldBlue,
                        foregroundColor: AppColors.n0,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        lang.getMessage('got_it', 'Got it'),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
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

/// "Snabbit " (Medium) + "Kavach" (Extra Bold), 20px, #016ee6 – activation variant.
class _ActivationShieldTitle extends StatelessWidget {
  final String title;

  const _ActivationShieldTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF016EE6);
    final firstSpace = title.indexOf(' ');
    final firstPart =
        firstSpace >= 0 ? title.substring(0, firstSpace + 1) : title;
    final secondPart = firstSpace >= 0 ? title.substring(firstSpace + 1) : '';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: firstPart,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w500,
              color: color,
              height: 38 / 20,
            ),
          ),
          TextSpan(
            text: secondPart,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: color,
              height: 38 / 20,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
