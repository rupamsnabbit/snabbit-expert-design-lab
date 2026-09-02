import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/constants.dart';

import '../../providers/payout.dart';

class FinalPayoutView extends StatefulWidget {
  const FinalPayoutView({super.key});

  @override
  State<FinalPayoutView> createState() => _FinalPayoutViewState();
}

class _FinalPayoutViewState extends State<FinalPayoutView> {
  bool init = true;
  late PayoutProvider payoutProvider;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: AppColors.n0,
        border: Border.all(color: AppColors.n40),
      ),
      padding: EdgeInsets.symmetric(vertical: 23.h, horizontal: 16.w),
      child: Row(
        mainAxisAlignment: payoutProvider.earnings?.payoutDate != null
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: payoutProvider.earnings?.payoutDate != null
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    languageProvider.getMessage(
                      'final_payout',
                      'Final Payout',
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                SizedBox(height: 4.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatIndianCurrency(
                        payoutProvider.earnings?.amountDue ?? 0),
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(color: const Color(0xff26A179)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          if (payoutProvider.earnings?.payoutDate != null)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      payoutProvider.earnings!.payoutDate!
                              .isAfter(DateTime.now())
                          ? languageProvider.getMessage(
                              'paid_on',
                              'Paid on',
                            )
                          : languageProvider.getMessage(
                              'to_be_paid_on',
                              'To be paid on',
                            ),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: AppColors.n90),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      dateFormatVisual3
                          .format(payoutProvider.earnings!.payoutDate!),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontSize: 18.sp),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
