import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/payout/payout_section_container.dart';

import '../../providers/payout.dart';
import '../../services/payout_http.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../widgets/drawer/drawer_menu.dart';

class OvertimeDetails extends StatefulWidget {
  static const String routeName = "/overtime-details";

  const OvertimeDetails({super.key});

  @override
  State<OvertimeDetails> createState() => _OvertimeDetailsState();
}

class _OvertimeDetailsState extends State<OvertimeDetails> {
  bool init = true;
  bool loading = true;
  String? error;
  late PayoutProvider payoutProvider;
  late CurrentPeriodProvider currentPeriodProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    try {
      Response? response = await PayoutHttp.getOvertimeDetails(
          start: currentPeriodProvider.monthStartDate,
          end: currentPeriodProvider.monthEndDate);
      if (response != null) {
        error = null;
        payoutProvider.setOvertimeDetails(response.data);
      } else {
        error = "Something went wrong";
      }
    } catch (e) {
      error = "Something went wrong";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const DrawerMenu(),
      backgroundColor: const Color(0xffF5F6F8),
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext ctx) {
            return IconButton(
              onPressed: () async {
                Scaffold.of(ctx).openDrawer();
              },
              icon: const Icon(
                Icons.menu,
                color: AppColors.n90,
              ),
            );
          },
        ),
        elevation: 10.r,
        centerTitle: true,
        title: Text(
          "Overtime",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 20.h,
              ),
              child: PayoutSectionContainer(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: CurrentPeriodView(
                          viewType: PayoutPeriod.monthly,
                          onChanged: () async {
                            setState(() {
                              loading = true;
                            });
                            await initProcess();
                            setState(() {
                              loading = false;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: const Divider(
                          color: AppColors.n30,
                        ),
                      ),
                      error != null
                          ? Center(
                              child: Text("$error"),
                            )
                          : Column(
                              children: [
                                Container(
                                  width: 1.sw,
                                  padding: EdgeInsets.symmetric(vertical: 7.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.g40,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Total OT earnings",
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(color: AppColors.n0),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        "₹${payoutProvider.overtimeDetails?.total ?? 0}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(color: AppColors.n0),
                                      ),
                                    ],
                                  ),
                                ),
                                // Padding(
                                //   padding: EdgeInsets.symmetric(vertical: 12.h),
                                //   child: RichText(
                                //     text: TextSpan(
                                //       children: [
                                //         TextSpan(
                                //           text: "Earned from ",
                                //           style: Theme.of(context)
                                //               .textTheme
                                //               .displaySmall,
                                //         ),
                                //         TextSpan(
                                //           text:
                                //               "${minsToHours(payoutProvider.overtimeDetails?.otMins)} hours",
                                //           style: Theme.of(context)
                                //               .textTheme
                                //               .displayMedium
                                //               ?.copyWith(
                                //                   color:
                                //                       const Color(0xffA0A7AE)),
                                //         ),
                                //         TextSpan(
                                //           text: " of Overtime work",
                                //           style: Theme.of(context)
                                //               .textTheme
                                //               .displaySmall,
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                                // ),
                                if (payoutProvider.overtimeDetails?.otData !=
                                        null &&
                                    payoutProvider
                                        .overtimeDetails!.otData!.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: 12.h),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemBuilder: (_, index) {
                                        OvertimeData? otData = payoutProvider
                                            .overtimeDetails?.otData?[index];
                                        return Padding(
                                          padding:
                                              EdgeInsets.only(bottom: 16.h),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                              border: Border.all(
                                                  color: AppColors.n40),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8.h,
                                              horizontal: 16.w,
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      otData?.date != null
                                                          ? dateFormat.format(
                                                              otData!.date!)
                                                          : "-",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .displaySmall,
                                                    ),
                                                    Text(
                                                      "${minsToHours(otData?.otMins)} hours",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .displayMedium,
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4.h),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      otData?.otTime ?? "-",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .displayMedium
                                                          ?.copyWith(
                                                              color: const Color(
                                                                  0xffA0A7AE)),
                                                    ),
                                                    Text(
                                                      "₹${otData?.otPay ?? 0}",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .displayLarge
                                                          ?.copyWith(
                                                            color:
                                                                AppColors.g40,
                                                            fontStyle: FontStyle
                                                                .normal,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      itemCount: payoutProvider
                                          .overtimeDetails?.otData?.length,
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: EdgeInsets.only(top: 21.h),
                                    child: Text(
                                      "Aapne iss mahine ab tak OT nahi kiya",
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(color: AppColors.n60),
                                    ),
                                  ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
