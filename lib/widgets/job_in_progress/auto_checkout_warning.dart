import 'package:comm_stream/comm_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

import '../../services/remote_config/remote_config_assets.dart';
import '../../utils/colors.dart';


class AutoCheckoutWarning extends StatelessWidget {

  const AutoCheckoutWarning({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Consumer(
          builder: (context, LanguageProvider languageProvider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TriangleIndicator(color: AppColors.r30,),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.r10,
                    border: Border.all(
                      color: AppColors.r30,
                      width: 1.5.r,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RemoteImageHandler(
                        imageUrl: RemoteConfigAssets.jobRejectionWarningStatusRed,
                        width: 14.r,
                        errorWidget: SizedBox(),
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: FittedBox(
                          child: Text(
                            languageProvider.getMessage("you_will_get_auto_checked_out", "You will get auto checked out"),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
      ),
    );
  }
}

class _TriangleIndicator extends StatelessWidget {
  final Color color;
  const _TriangleIndicator({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(16.w, 8.h),
      painter: _TrianglePainter(color),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)           // Bottom-left
      ..lineTo(size.width / 2, 0)        // Top-center
      ..lineTo(size.width, size.height)  // Bottom-right
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}