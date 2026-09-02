import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/shift_insight.dart';
import 'package:snabbit_runner/widgets/payout/shift_insight_item.dart';

class ShiftInsightsList extends StatelessWidget {
  const ShiftInsightsList({
    super.key,
    required this.shiftInsightList,
    this.showDescription = false,
    this.childAspectRatio = 0.7,
  });

  final double childAspectRatio;
  final List<ShiftInsight> shiftInsightList;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: shiftInsightList.length,
      itemBuilder: (context, index) {
        return ShiftInsightItem(
          shiftInsight: shiftInsightList[index],
          showDescription: showDescription,
        );
      },
    );
  }
}
