import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

/// Function to show error popup bottom sheet
void showErrorPopup({
  required BuildContext context,
  required CustomError error,
  VoidCallback? onButtonTap,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.n0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16.r),
      ),
    ),
    builder: (context) {
      return CommonBottomSheetSetup(
        horizontalPadding: 0,
        bottomPadding: 0,
        child: ErrorPopupContent(
          error: error,
          onButtonTap: onButtonTap,
        ),
      );
    },
  );
}

/// Widget to display error popup content
class ErrorPopupContent extends StatelessWidget {
  /// The error object containing title, message, and button text
  final CustomError error;

  /// Callback when the action button is tapped
  final VoidCallback? onButtonTap;

  const ErrorPopupContent({
    super.key,
    required this.error,
    this.onButtonTap,
  });

  /// Gets the button text from error data
  String _getButtonText() {
    if (error.data is String) {
      return error.data as String;
    } else if (error.data is Map) {
      final dataMap = error.data as Map;
      return dataMap['button_text'] ?? 'Okay';
    }
    return 'Okay';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final buttonText = _getButtonText();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle area
        SizedBox(height: 30.h),

        // Content area
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon and title section
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Red circular icon with white X
                  Container(
                    width: 48.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: AppColors.r40,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: Size(10.29.w, 10.5.h),
                        painter: _XIconPainter(),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Title
                  if (error.title != null)
                    Text(
                      error.title!,
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.24,
                        color: AppColors.n90,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  SizedBox(height: 12.h),

                  // Error message box
                  if (error.message != null)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(horizontal: 27.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.y10,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        error.message!,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          height: 24 / 14,
                          color: AppColors.y60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Button area
        Container(
          width: double.infinity,
          height: 80.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Center(
            child: SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onButtonTap?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                ),
                child: Text(
                  buttonText,
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.24,
                    color: AppColors.n0,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Home indicator area
        SizedBox(height: 21.h),
      ],
    );
  }
}

/// Custom painter for drawing X icon
class _XIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.n0
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw diagonal lines to form X
    // Top-left to bottom-right
    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, size.height),
      paint,
    );
    // Top-right to bottom-left
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

