import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/payout/attendance.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';

import '../../pages/payout/overtime_details.dart';
import '../../pages/payout/performance.dart';
import '../../providers/payout.dart';
import '../../utils/colors.dart';
import 'clickable_text.dart';
import 'payout_section_container.dart';
import 'payout_section_row.dart';

class DailyPayoutDetails extends StatefulWidget {
  final DateTime currentDate;
  const DailyPayoutDetails({super.key, required this.currentDate,});

  @override
  State<DailyPayoutDetails> createState() => _DailyPayoutDetailsState();
}

class _DailyPayoutDetailsState extends State<DailyPayoutDetails> {
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
        // Padding(
        //   padding: EdgeInsets.only(top: 8.h),
        //   child: PayoutSectionContainer(
        //     child: PayoutSectionRow(
        //       children: [
        //         PayoutDetail(
        //           heading: ClickableText(
        //             child: Text(
        //               "Today’s earnings",
        //               style: Theme.of(context)
        //                   .textTheme
        //                   .displayMedium
        //                   ?.copyWith(color: AppColors.g40),
        //             ),
        //             onTap: () {},
        //           ),
        //           title: Text(
        //             "Cash collected",
        //             style: Theme.of(context).textTheme.displaySmall,
        //           ),
        //           content: Text(
        //             "₹${payoutProvider.earnings?.cashCollected ?? 0}",
        //             style: Theme.of(context).textTheme.displayLarge,
        //           ),
        //         ),
        //         PayoutDetail(
        //           heading: const SizedBox(),
        //           title: Text(
        //             "Job earnings",
        //             style: Theme.of(context).textTheme.displaySmall,
        //           ),
        //           content: Text(
        //             "₹${payoutProvider.earnings?.earning ?? 0}",
        //             style: Theme.of(context).textTheme.displayLarge,
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
        Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: PayoutSectionContainer(
            child: PayoutSectionRow(
              children: [
                PayoutDetail(
                  heading: ClickableText(
                    child: Text(
                      "Overtime",
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: AppColors.g40),
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed(OvertimeDetails.routeName);
                    },
                  ),
                  title: Text(
                    "OT hours",
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  content: Text(
                    "${minsToHours(payoutProvider.earnings?.otMins)} hours",
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
                PayoutDetail(
                  heading: const SizedBox(),
                  title: Text(
                    "OT earnings",
                    style: Theme.of(context).textTheme.displaySmall,
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
        // Padding(
        //   padding: EdgeInsets.only(top: 8.h),
        //   child: PayoutSectionContainer(
        //     child: PayoutSectionRow(
        //       children: [
        //         PayoutDetail(
        //           heading: ClickableText(
        //             child: Text(
        //               "Deductions",
        //               style: Theme.of(context)
        //                   .textTheme
        //                   .displayMedium
        //                   ?.copyWith(color: AppColors.r40),
        //             ),
        //             onTap: () {
        //               Navigator.of(context).pushNamed(DeductionDetails.routeName);
        //             },
        //           ),
        //           title: Text(
        //             "General",
        //             style: Theme.of(context).textTheme.displaySmall,
        //           ),
        //           content: Text(
        //             "-₹${payoutProvider.earnings?.deduction ?? 0}",
        //             style: Theme.of(context).textTheme.displayLarge,
        //           ),
        //         ),
        //         // PayoutDetail(
        //         //   heading: const SizedBox(),
        //         //   title: Text(
        //         //     "Penalties",
        //         //     style: Theme.of(context).textTheme.displaySmall,
        //         //   ),
        //         //   content: Text(
        //         //     "-₹800",
        //         //     style: Theme.of(context).textTheme.displayLarge,
        //         //   ),
        //         // ),
        //       ],
        //     ),
        //   ),
        // ),
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
                      "Today",
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed(Performance.routeName);
                    },
                  ),
                  content: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "${payoutProvider.earnings?.avgRating ?? "-"}",
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        if (payoutProvider.earnings?.avgRating != null)
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
                      "This week",
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed(Attendance.routeName);
                    },
                  ),
                  content: Text(
                    "${payoutProvider.earnings?.totalPresentDays ?? 0}/7",
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
