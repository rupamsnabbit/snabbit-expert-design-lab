import 'package:dio/dio.dart';
import 'package:dotted_line/dotted_line.dart';
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
import '../../widgets/drawer/drawer_menu.dart';

class NetEarnings extends StatefulWidget {
  static const String routeName = "/net-earnings";

  const NetEarnings({super.key});

  @override
  State<NetEarnings> createState() => _NetEarningsState();
}

class _NetEarningsState extends State<NetEarnings> {
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
      Response? response = await PayoutHttp.getPayslip(
          start: currentPeriodProvider.monthStartDate,
          end: currentPeriodProvider.monthEndDate);
      if (response != null) {
        error = null;
        payoutProvider.setPayslip(response.data);
      } else {
        error = "Something went wrong";
      }
    } catch (e) {
      error = "Something went wrong - $e";
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
          "Net Earnings",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 20.h,
        ),
        child: loading
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    PayoutSectionContainer(
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
                          if (error == null)
                            Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4.h),
                                  child: const Divider(
                                    color: AppColors.n30,
                                  ),
                                ),
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
                                        "Kamai",
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(color: AppColors.n0),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        "₹${payoutProvider.payslip?.netEarnings ?? 0}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(color: AppColors.n0),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 12.h),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4.r),
                                      color: AppColors.g10,
                                    ),
                                    padding: EdgeInsets.all(7.r),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            payoutProvider.payslip?.grossEarning
                                                    ?.title ??
                                                "Mahine ki Kamai",
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayMedium
                                                ?.copyWith(
                                                    color: AppColors.g40),
                                          ),
                                        ),
                                        Text(
                                          "₹${anyValueToInt(payoutProvider.payslip?.grossEarning?.value)}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .displayMedium
                                              ?.copyWith(color: AppColors.g40),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 12.h),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4.r),
                                      color: AppColors.r10,
                                    ),
                                    padding: EdgeInsets.all(7.r),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            payoutProvider.payslip
                                                    ?.grossDeduction?.title ??
                                                "Mahine ke Deductions",
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayMedium
                                                ?.copyWith(
                                                    color: AppColors.r50),
                                          ),
                                        ),
                                        Text(
                                          "₹${anyValueToInt(payoutProvider.payslip?.grossDeduction?.value)}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .displayMedium
                                              ?.copyWith(color: AppColors.r50),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    error != null
                        ? Center(
                            child: Text("$error"),
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 8.h),
                                child: PayoutSectionContainer(
                                  child: Column(
                                    children: [
                                      Text(
                                        payoutProvider
                                                .payslip?.earnings?.title ??
                                            "Kamai",
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayMedium
                                            ?.copyWith(color: AppColors.g40),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12.h),
                                        child: DottedLine(
                                          lineThickness: 1.h,
                                          dashLength: 5.w,
                                          dashColor: AppColors.n30,
                                        ),
                                      ),
                                      if (payoutProvider.payslip?.earnings !=
                                          null)
                                        EarningsBreakdown(
                                            payoutProvider: payoutProvider),
                                      if (payoutProvider.payslip?.minG != null)
                                        MinGBreakdown(
                                          payoutProvider: payoutProvider,
                                        ),
                                      if (payoutProvider.payslip?.overtime !=
                                          null)
                                        OvertimeBreakdown(
                                          payoutProvider: payoutProvider,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (payoutProvider.payslip?.incentives != null)
                                IncentivesBreakdown(
                                    payoutProvider: payoutProvider),
                              if (payoutProvider.payslip?.deductions != null)
                                DeductionsBreakdown(
                                    payoutProvider: payoutProvider),
                            ],
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}

class EarningsBreakdown extends StatelessWidget {
  final PayoutProvider payoutProvider;

  const EarningsBreakdown({
    super.key,
    required this.payoutProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (payoutProvider.payslip?.earnings?.breakdown != null)
          ...payoutProvider.payslip!.earnings!.breakdown!.map((e) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${e.title}",
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "${e.value}",
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }),
        Row(
          children: [
            Expanded(
              child: Text(
                payoutProvider.payslip?.earnings?.total?.title ??
                    "Kaam ki Kamai",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.n90),
              ),
            ),
            SizedBox(width: 16.w),
            Text(
              "${payoutProvider.payslip?.earnings?.total?.value ?? 0}",
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(color: AppColors.n90),
            ),
          ],
        ),
      ],
    );
  }
}

class MinGBreakdown extends StatelessWidget {
  final PayoutProvider payoutProvider;

  const MinGBreakdown({
    super.key,
    required this.payoutProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: DottedLine(
            lineThickness: 1.h,
            dashLength: 5.w,
            dashColor: AppColors.n30,
          ),
        ),
        if (payoutProvider.payslip?.minG?.breakdown != null)
          ...payoutProvider.payslip!.minG!.breakdown!.map((e) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${e.title}",
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "${e.value}",
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }),
        Row(
          children: [
            Expanded(
              child: Text(
                payoutProvider.payslip?.minG?.total?.title ?? "OT ki Kamai",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.n90),
              ),
            ),
            SizedBox(width: 16.w),
            Text(
              "${payoutProvider.payslip?.minG?.total?.value ?? 0}",
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(color: AppColors.n90),
            ),
          ],
        ),
      ],
    );
  }
}

class OvertimeBreakdown extends StatelessWidget {
  final PayoutProvider payoutProvider;

  const OvertimeBreakdown({
    super.key,
    required this.payoutProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: DottedLine(
            lineThickness: 1.h,
            dashLength: 5.w,
            dashColor: AppColors.n30,
          ),
        ),
        if (payoutProvider.payslip?.overtime?.breakdown != null)
          ...payoutProvider.payslip!.overtime!.breakdown!.map((e) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${e.title}",
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "${e.value}",
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }),
        Row(
          children: [
            Expanded(
              child: Text(
                payoutProvider.payslip?.overtime?.total?.title ??
                    "Total Overtime Earning",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.n90),
              ),
            ),
            SizedBox(width: 16.w),
            Text(
              "${payoutProvider.payslip?.overtime?.total?.value ?? 0}",
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(color: AppColors.n90),
            ),
          ],
        ),
      ],
    );
  }
}

class IncentivesBreakdown extends StatelessWidget {
  final PayoutProvider payoutProvider;

  const IncentivesBreakdown({
    super.key,
    required this.payoutProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: PayoutSectionContainer(
        child: Column(
          children: [
            Text(
              payoutProvider.payslip?.incentives?.title ?? "Bonus",
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(color: AppColors.g40),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: DottedLine(
                lineThickness: 1.h,
                dashLength: 5.w,
                dashColor: AppColors.n30,
              ),
            ),
            if (payoutProvider.payslip?.incentives?.breakdown != null)
              ...payoutProvider.payslip!.incentives!.breakdown!.map((e) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${e.title}",
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        "${e.value}",
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    payoutProvider.payslip?.incentives?.total?.title ??
                        "Bonus Kamai",
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: AppColors.n90),
                  ),
                ),
                SizedBox(width: 16.w),
                Text(
                  "${payoutProvider.payslip?.incentives?.total?.value ?? 0}",
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(color: AppColors.n90),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DeductionsBreakdown extends StatelessWidget {
  final PayoutProvider payoutProvider;

  const DeductionsBreakdown({
    super.key,
    required this.payoutProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: PayoutSectionContainer(
        child: Column(
          children: [
            Text(
              payoutProvider.payslip?.deductions?.title ?? "Deductions",
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(color: AppColors.r40),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: DottedLine(
                lineThickness: 1.h,
                dashLength: 5.w,
                dashColor: AppColors.n30,
              ),
            ),
            if (payoutProvider.payslip?.deductions?.breakdown != null)
              ...payoutProvider.payslip!.deductions!.breakdown!.map((e) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${e.title}",
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        "${e.value}",
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    payoutProvider.payslip?.deductions?.total?.title ??
                        "Total Deductions",
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: AppColors.n90),
                  ),
                ),
                SizedBox(width: 16.w),
                Text(
                  "${payoutProvider.payslip?.deductions?.total?.value ?? 0}",
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(color: AppColors.n90),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
