import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/miscellaneous/dashed_vertical_line.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ShiftOverview extends StatefulWidget {
  final String startDay;
  final String endDay;
  final String startTime;
  final int duration;
  final Color topSectionColor;
  final Color bottomSectionColor;
  final Color foregroundColor;

  const ShiftOverview({
    super.key,
    required this.startDay,
    required this.endDay,
    required this.startTime,
    required this.duration,
    required this.topSectionColor,
    required this.bottomSectionColor,
    required this.foregroundColor,
  });

  @override
  State<ShiftOverview> createState() => _ShiftOverviewState();
}

class _ShiftOverviewState extends State<ShiftOverview> {

  late LanguageProvider languageProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }


  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: widget.bottomSectionColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            // width: 327.w,
            // height: 67.h,
            padding: EdgeInsets.symmetric(horizontal: 17.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: widget.topSectionColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Start time
                Row(
                  children: [
                    SvgPicture.asset(
                      AssetConstants.shiftStartTime,
                      height: 24.h,
                      colorFilter:
                          ColorFilter.mode(widget.foregroundColor, BlendMode.srcIn),
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          languageProvider.getMessage('start_message', 'Start time'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: widget.foregroundColor,
                          ),
                        ),
                        SizedBox(height: 4.4.h),
                        Text(
                          widget.startTime,
                          style: textTheme.displayMedium?.copyWith(
                            fontSize: 16.sp,
                            color: widget.foregroundColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Dashed divider
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 24.w),
                  child: CustomPaint(
                    size: const Size(1, 44),
                    painter: DashedLineVerticalPainter(
                      color:widget.foregroundColor,
                      dashHeight: 2.5,
                      dashSpace: 3,
                    ),
                  ),
                ),
                // Duration
                Row(
                  children: [
                    SvgPicture.asset(
                      AssetConstants.shiftDuration,
                      height: 24.h,
                      colorFilter:
                      ColorFilter.mode(widget.foregroundColor, BlendMode.srcIn),
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          languageProvider.getMessage('duration', 'Duration'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: widget.foregroundColor,
                          ),
                        ),
                        SizedBox(height: 4.4.h),
                        Text(
                          '${widget.duration} hours',
                          style: textTheme.displayMedium?.copyWith(
                            fontSize: 16.sp,
                            color: widget.foregroundColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 327.w,
            height: 25.h,
            decoration: BoxDecoration(
              color: widget.bottomSectionColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${widget.startDay} - ${widget.endDay}',
              style: textTheme.displayLarge?.copyWith(
                fontSize: 16.sp,
                color: Colors.black,
                height: 1.1,
                letterSpacing: -0.14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
