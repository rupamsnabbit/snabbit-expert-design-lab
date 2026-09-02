import 'package:comm_stream/comm_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

import '../../services/remote_config/remote_config_assets.dart';
import '../../utils/colors.dart';

enum WarningState{
  green,
  yellow,
  red,
}

class WarningBelowTimer extends StatelessWidget {
  final WarningState warningState;

  const WarningBelowTimer({
    super.key,
    required this.warningState,
  });

  ({ String text,
   Color bgColor,
   Color borderColor,
   String icon,}) getData(LanguageProvider languageProvider) {
    switch(warningState){
      case WarningState.green:
        return (
        text: languageProvider.getMessage(
          'accept_job_now_and_do_good_shift',
          'Accept job now & do good shift',
        ),
          bgColor: AppColors.g10,
          borderColor: AppColors.g20,
          icon:  RemoteConfigAssets.jobRejectionWarningStatusGreen
        );
      case WarningState.yellow:
        return (
        text: languageProvider.getMessage(
          'accept_job_now_and_do_good_shift',
          'Accept job now & do good shift',
        ),
        bgColor: AppColors.y10,
        borderColor: AppColors.y20,
        icon:  RemoteConfigAssets.jobRejectionWarningStatusYellow
        );
      case WarningState.red:
        return (
        text: languageProvider.getMessage("accept_job_now_or_lose_good_shift", "Accept Job or lose Good Shift"),
        bgColor: AppColors.r10,
        borderColor: AppColors.r30,
        icon:  RemoteConfigAssets.jobRejectionWarningStatusRed
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Consumer(
        builder: (context, LanguageProvider languageProvider, child) {
          final data = getData(languageProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TriangleIndicator(color: data.borderColor,),
              Container(
                decoration: BoxDecoration(
                  color: data.bgColor,
                  border: Border.all(
                    color: data.borderColor,
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
                      imageUrl: data.icon,
                      width: 14.r,
                      errorWidget: SizedBox(),
                      key: ValueKey(data.icon),
                    ),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: FittedBox(
                        child: Text(
                          data.text,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          key: ValueKey(data.text),
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