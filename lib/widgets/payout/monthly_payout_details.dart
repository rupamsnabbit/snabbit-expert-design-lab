import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/payout/incentive_details.dart';
import 'package:snabbit_runner/pages/payout/overtime_details.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';

import '../../pages/payout/attendance.dart';
import '../../providers/payout.dart';
import '../../utils/colors.dart';
import 'clickable_text.dart';
import 'payout_section_container.dart';
import 'payout_section_row.dart';

class MonthlyPayoutDetails extends StatefulWidget {
  final DateTime currentDate;
  const MonthlyPayoutDetails({super.key, required this.currentDate});

  @override
  State<MonthlyPayoutDetails> createState() => _MonthlyPayoutDetailsState();
}

class _MonthlyPayoutDetailsState extends State<MonthlyPayoutDetails> {
  bool init = true;
  bool loading = true;
  late PayoutProvider payoutProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {}
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: PayoutSectionContainer(
            child: PayoutSectionRow(
              children: [
                PayoutDetail(
                  heading: Text(
                    "Overtime",
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  title: ClickableText(
                    onTap: () {
                      Navigator.of(context).pushNamed(OvertimeDetails.routeName);
                    },
                    child: Text(
                      "OT hours",
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  content: Text(
                    "${minsToHours(payoutProvider.earnings?.otMins)} hours",
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
                PayoutDetail(
                  heading: const SizedBox(),
                  title: ClickableText(
                    onTap: () {},
                    child: Text(
                      "OT earnings",
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  content: Text(
                    "₹${payoutProvider.earnings?.otEarning ?? 0}",
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: PayoutSectionContainer(
            child: PayoutSectionRow(
              children: [
                PayoutDetail(
                  heading: Text(
                    "Ratings",
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  title: ClickableText(
                    child: Text(
                      "This month",
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    onTap: () {},
                  ),
                  content: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "${payoutProvider.earnings?.avgRating}",
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const WidgetSpan(
                          child: Icon(
                            Icons.star_rounded,
                            color: Color(0xff40515B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PayoutDetail(
                  heading: Text(
                    "Attendance",
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  title: ClickableText(
                    child: Text(
                      "This month",
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed(Attendance.routeName);
                    },
                  ),
                  content: Text(
                    "${payoutProvider.earnings?.totalPresentDays ?? 0}/${daysInCurrentMonth(widget.currentDate)}",
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Padding(
        //   padding: EdgeInsets.only(top: 8.h),
        //   child: PayoutSectionContainer(
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Text(
        //           "Monthly Attendance Incentive",
        //           style: Theme.of(context).textTheme.displaySmall,
        //         ),
        //         SizedBox(height: 4.h),
        //         RichText(
        //           text: TextSpan(
        //             children: [
        //               TextSpan(
        //                 text: "20/26 ",
        //                 style: Theme.of(context).textTheme.displayLarge,
        //               ),
        //               TextSpan(
        //                 text: "Days",
        //                 style: Theme.of(context).textTheme.displayMedium,
        //               ),
        //             ],
        //           ),
        //         ),
        //         SizedBox(height: 4.h),
        //         const CustomProgressBar(
        //           progress: 0.5,
        //           color: AppColors.g40,
        //         ),
        //         Padding(
        //           padding: EdgeInsets.symmetric(vertical: 4.h),
        //           child: const Divider(
        //             color: AppColors.n30,
        //           ),
        //         ),
        //         Text(
        //           "Monthly Performance Incentive",
        //           style: Theme.of(context).textTheme.displaySmall,
        //         ),
        //         SizedBox(height: 4.h),
        //         RichText(
        //           text: TextSpan(
        //             children: [
        //               TextSpan(
        //                 text: "3.2/4.6",
        //                 style: Theme.of(context).textTheme.displayLarge,
        //               ),
        //               const WidgetSpan(
        //                 child: Icon(
        //                   Icons.star_rounded,
        //                   color: Color(0xff40515B),
        //                 ),
        //               ),
        //             ],
        //           ),
        //         ),
        //         SizedBox(height: 4.h),
        //         CustomProgressBar(
        //           progress: 0.5,
        //           color: const Color(0xffD68D35),
        //           endValue: Text(
        //             "5",
        //             style: Theme.of(context)
        //                 .textTheme
        //                 .labelMedium
        //                 ?.copyWith(color: const Color(0xff9CA2BA)),
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
        Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: InkWell(
            onTap: () {
              Navigator.of(context).pushNamed(IncentiveDetails.routeName);
            },
            child: PayoutSectionContainer(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total incentive earnings",
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "₹${payoutProvider.earnings?.totalIncentive ?? 0}",
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(color: AppColors.g40),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}