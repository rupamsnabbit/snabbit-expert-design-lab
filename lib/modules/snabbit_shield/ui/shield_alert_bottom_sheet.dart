import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/modules/snabbit_shield/ui/shield_background_circles_painter.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

/// A configurable alert bottom sheet for Snabbit Shield.
///
/// Displays an image, bold title, and one or two action buttons.
/// Reusable with different images, titles, colors, and button actions.
class ShieldAlertBottomSheet extends StatelessWidget {
  final String imageUrl;
  final String title;
  final Color accentColor;
  final String primaryButtonText;
  final VoidCallback onPrimaryTap;
  final Widget? primaryButtonIcon;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryTap;
  final Widget? secondaryButtonIcon;
  static bool _isShowing = false;

  /// Whether the alert sheet is currently visible.
  static bool get isShowing => _isShowing;

  const ShieldAlertBottomSheet({
    super.key,
    required this.imageUrl,
    required this.title,
    this.accentColor = const Color(0xFFE63F3F),
    required this.primaryButtonText,
    required this.onPrimaryTap,
    this.primaryButtonIcon,
    this.secondaryButtonText,
    this.onSecondaryTap,
    this.secondaryButtonIcon,
  });

  /// Shows the alert bottom sheet as a modal.
  ///
  /// [onShown] runs once after the first frame when the sheet is visible (analytics).
  static Future<T?> show<T>(
    BuildContext context, {
    required String imageUrl,
    required String title,
    Color accentColor = const Color(0xFFE63F3F),
    required String primaryButtonText,
    required VoidCallback onPrimaryTap,
    Widget? primaryButtonIcon,
    String? secondaryButtonText,
    VoidCallback? onSecondaryTap,
    Widget? secondaryButtonIcon,
    VoidCallback? onShown,
  }) {
    const ribbonHeight = 40.0;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.none,
      builder: (context) {
        _isShowing = true;
        return _ShieldAlertSheetOnShownScope(
          onShown: onShown,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(top: ribbonHeight / 2),
                child: CommonBottomSheetSetup(
                  horizontalPadding: 0,
                  bottomPadding: 24,
                  showDragHandle: false,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16.r)),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xffFFB8B8),
                      Color(0xffFFB8B8),
                      Colors.white,
                    ],
                    stops: [0.0, 0.5, 0.7],
                  ),
                  child: ShieldAlertBottomSheet(
                    imageUrl: imageUrl,
                    title: title,
                    accentColor: accentColor,
                    primaryButtonText: primaryButtonText,
                    onPrimaryTap: onPrimaryTap,
                    primaryButtonIcon: primaryButtonIcon,
                    secondaryButtonText: secondaryButtonText,
                    onSecondaryTap: onSecondaryTap,
                    secondaryButtonIcon: secondaryButtonIcon,
                  ),
                ),
              ),
              Positioned(
                top: 13,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    AssetConstants.kavachRibbon,
                    height: ribbonHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => _isShowing = false);
  }

  static hide(BuildContext context) {
    if (_isShowing && context.mounted && Navigator.canPop(context)) {
      _isShowing = false;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 40.h),
              // Header hero section – matches Snabbit Shield activation layout
              SizedBox(
                height: 234.h,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ShieldBackgroundCirclesPainter(),
                      ),
                    ),
                    // Red vector lines background from Figma (shield_vector_lines_red.svg)
                    Positioned(
                      left: -17.w,
                      right: -17.w,
                      top: 60,
                      height: 107.h,
                      child: SvgPicture.asset(
                        AssetConstants.shieldVectorLinesRed,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Soft concentric circles behind the siren, matching consent header

                    // Siren / alert image on top of the lines
                    Positioned(
                      top: 40,
                      child: Image.asset(
                        AssetConstants.shieldSirenIconLarge,
                        height: 150.h,
                        width: 150.w,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              // Content: title + buttons
              Padding(
                // Figma uses 20px inset with 393px sheet width -> 353px buttons
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 16.h),
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontSize: 32.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF303030),
                                letterSpacing: -0.5,
                                height: 38 / 32,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32.h),
                    _buildPrimaryButton(context),
                    if (secondaryButtonText != null &&
                        onSecondaryTap != null) ...[
                      SizedBox(height: 12.h),
                      _buildSecondaryButton(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Close (X) icon in the top-right, matching Figma
          Positioned(
            top: 16.h,
            right: 16.w,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(16.r),
                onTap: () {
                  _isShowing = false;
                  Navigator.of(context).maybePop();
                },
                child: Container(
                  width: 24.r,
                  height: 24.r,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 15.r,
                    color: const Color(0xFF303030),
                  ),
                ),
              ),
            ),
          ),
          // Drag handle at the bottom center, matching Figma's 140×5 grey bar
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    final buttonTextStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.n0,
        );
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: FilledButton(
        onPressed: onPrimaryTap,
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: AppColors.n0,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: buttonTextStyle,
        ),
        child: primaryButtonIcon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  primaryButtonIcon!,
                  SizedBox(width: 8.w),
                  Text(primaryButtonText, style: buttonTextStyle),
                ],
              )
            : Text(primaryButtonText, style: buttonTextStyle),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context) {
    final buttonTextStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF303030),
        );
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: OutlinedButton(
        onPressed: onSecondaryTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF303030),
          side: const BorderSide(color: Color(0xFF303030), width: 2),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: buttonTextStyle,
        ),
        child: secondaryButtonIcon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  secondaryButtonIcon!,
                  SizedBox(width: 8.w),
                  Text(secondaryButtonText!, style: buttonTextStyle),
                ],
              )
            : Text(secondaryButtonText!, style: buttonTextStyle),
      ),
    );
  }
}

/// Invokes [onShown] once after the first frame (sheet visible); skips if null.
class _ShieldAlertSheetOnShownScope extends StatefulWidget {
  const _ShieldAlertSheetOnShownScope({
    required this.child,
    this.onShown,
  });

  final Widget child;
  final VoidCallback? onShown;

  @override
  State<_ShieldAlertSheetOnShownScope> createState() =>
      _ShieldAlertSheetOnShownScopeState();
}

class _ShieldAlertSheetOnShownScopeState
    extends State<_ShieldAlertSheetOnShownScope> {
  @override
  void initState() {
    super.initState();
    final cb = widget.onShown;
    if (cb != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) cb();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
