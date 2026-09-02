import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/utils/colors.dart';

class GoodShiftDetailsView extends StatelessWidget {
  final GoodShiftDetails? goodShiftDetails;

  const GoodShiftDetailsView({
    super.key,
    this.goodShiftDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (goodShiftDetails != null) {
      return Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
            padding: EdgeInsets.all(8.r),
            width: 1.sw,
            decoration: BoxDecoration(
              color: Color(0xFF321B01),
              borderRadius: BorderRadius.circular(8.r),
            ),
            alignment: Alignment.center,
            child: Text(
              languageProvider.getFormattedMessage(
                "good_shifts_earned",
                "Good shifts Earned: {{good_shift_count}}/{{total_good_shift_required}}",
                {
                  'good_shift_count': goodShiftDetails?.goodShiftCount ?? 0,
                  'total_good_shift_required':
                      goodShiftDetails?.totalGoodShiftRequired ?? 0,
                },
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.n0,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}
