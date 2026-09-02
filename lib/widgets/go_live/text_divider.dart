import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class AndDivider extends StatelessWidget {
  const AndDivider({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left gradient line
          const Expanded(
            child: DividerGradient(isLeft: true,),
          ),
          SizedBox(width: 24.w),
          // Center text
          Text(
           label?? "AND",
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              height: 18 / 14,
              color: AppColors.n90,
            ),
          ),
          SizedBox(width: 24.w),
          // Right gradient line
          const Expanded(
            child: DividerGradient(isLeft: false,),
          ),
        ],
      ),
    );
  }
}

class DividerGradient extends StatelessWidget {
  const DividerGradient({super.key, required this.isLeft,});
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    List<Color> colors=[];
    List<double> stops=[];
    if(isLeft){
      colors.add(Colors.transparent);
      stops.add(0.0);
    }
    colors.add(Colors.black);
    stops.add(0.5);
    if(!isLeft){
      colors.add(Colors.transparent);
      stops.add(1.0);
    }
    return Container(
      height: 1.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          stops: stops,
        ),
      ),
    );
  }
}
