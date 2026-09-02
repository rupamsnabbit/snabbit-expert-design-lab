import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/payout/payout_section_container.dart';

import '../../providers/payout.dart';
import '../../services/payout_http.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../widgets/drawer/drawer_menu.dart';

class DeductionDetails extends StatefulWidget {
  static const String routeName = "/deduction-details";

  const DeductionDetails({super.key});

  @override
  State<DeductionDetails> createState() => _DeductionDetailsState();
}

class _DeductionDetailsState extends State<DeductionDetails> {
  bool init = true;
  bool loading = true;
  String? error;
  late PayoutProvider payoutProvider;
  final GlobalKey<AnimatedListState> _deductionListKey =
      GlobalKey<AnimatedListState>();
  final GlobalKey<AnimatedListState> _cashListKey =
      GlobalKey<AnimatedListState>();
  final List<DeductionData> deductionItems = [];
  final List<DeductionData> cashItems = [];
  bool isAddingDeduction = false;
  bool isAddingCash = false;
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
      Response? response = await PayoutHttp.getDeductionDetails(
          start: currentPeriodProvider.monthStartDate,
          end: currentPeriodProvider.monthEndDate);
      if (response != null) {
        error = null;
        payoutProvider.setDeductionDetails(response.data);
      } else {
        error = "Something went wrong";
      }
    } catch (e) {
      error = "Something went wrong - $e";
    }
  }

  void _toggleDeductionItems() async {
    if (deductionItems.isEmpty) {
      // Add items one by one
      setState(() => isAddingDeduction = true);
      for (int i = 0;
          i < payoutProvider.deductionDetails!.deductions!.items!.length;
          i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        deductionItems
            .add(payoutProvider.deductionDetails!.deductions!.items![i]);
        _deductionListKey.currentState?.insertItem(i);
      }
    } else {
      // Remove items one by one from the end
      setState(() => isAddingDeduction = false);
      for (int i =
              payoutProvider.deductionDetails!.deductions!.items!.length - 1;
          i >= 0;
          i--) {
        await Future.delayed(const Duration(milliseconds: 100));
        DeductionData removedItem = deductionItems.removeAt(i);
        _deductionListKey.currentState?.removeItem(
          i,
          (context, animation) => _buildAnimatedItem(removedItem, animation),
          duration: const Duration(milliseconds: 100),
        );
      }
    }
  }

  void _toggleCashItems() async {
    if (cashItems.isEmpty) {
      // Add items one by one
      setState(() => isAddingCash = true);
      for (int i = 0;
          i < payoutProvider.deductionDetails!.cash!.items!.length;
          i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        cashItems.add(payoutProvider.deductionDetails!.cash!.items![i]);
        _cashListKey.currentState?.insertItem(i);
      }
    } else {
      // Remove items one by one from the end
      setState(() => isAddingCash = false);
      for (int i = payoutProvider.deductionDetails!.cash!.items!.length - 1;
          i >= 0;
          i--) {
        await Future.delayed(const Duration(milliseconds: 100));
        DeductionData removedItem = cashItems.removeAt(i);
        _cashListKey.currentState?.removeItem(
          i,
          (context, animation) => _buildAnimatedItem(removedItem, animation),
          duration: const Duration(milliseconds: 100),
        );
      }
    }
  }

  Widget _buildAnimatedItem(
      DeductionData? deductionData, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation, // Expands or shrinks items
      child: Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.n40),
          ),
          padding: EdgeInsets.symmetric(
            vertical: 8.h,
            horizontal: 16.w,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deductionData?.date != null
                    ? dateFormatVisual.format(deductionData!.date!)
                    : "-",
                style: Theme.of(context).textTheme.displaySmall,
              ),
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    deductionData?.name ?? "-",
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: const Color(0xff40515B)),
                  ),
                  Text(
                    "-₹${deductionData?.amount ?? 0}",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.r40,
                          fontStyle: FontStyle.normal,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
          "Deductions",
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
                      Column(
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
                        ],
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
                                    color: AppColors.r40,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Total Deductions",
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(color: AppColors.n0),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        "₹${payoutProvider.deductionDetails?.total ?? 0}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(color: AppColors.n0),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                if (payoutProvider
                                        .deductionDetails?.deductions !=
                                    null)
                                  ElevatedButton(
                                    onPressed: () {
                                      _toggleDeductionItems();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.r0,
                                      foregroundColor: AppColors.r30,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            8.r), // Customize the radius
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 21.h,
                                        horizontal: 16.w,
                                      ),
                                      side: const BorderSide(
                                          color: AppColors.r50),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            payoutProvider.deductionDetails
                                                    ?.deductions?.title ??
                                                "Deductions & Penalties",
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayLarge
                                                ?.copyWith(
                                                  fontStyle: FontStyle.normal,
                                                  color: AppColors.r50,
                                                  fontSize: 16.sp,
                                                ),
                                          ),
                                        ),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                    "-₹${payoutProvider.deductionDetails?.deductions?.total ?? 0} ",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displayLarge
                                                    ?.copyWith(
                                                      fontStyle:
                                                          FontStyle.normal,
                                                      color: AppColors.r50,
                                                      fontSize: 16.sp,
                                                    ),
                                              ),
                                              WidgetSpan(
                                                alignment:
                                                    PlaceholderAlignment.middle,
                                                child: AnimatedRotation(
                                                  turns: isAddingDeduction
                                                      ? 0.25
                                                      : 0.0,
                                                  duration: const Duration(
                                                      milliseconds: 100),
                                                  child: const Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: AppColors.r50,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (payoutProvider
                                        .deductionDetails?.deductions !=
                                    null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 16.h),
                                    child: AnimatedList(
                                      key: _deductionListKey,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemBuilder: (_, index, animation) {
                                        DeductionData? deductionData =
                                            payoutProvider.deductionDetails
                                                ?.deductions?.items?[index];
                                        return _buildAnimatedItem(
                                            deductionData, animation);
                                      },
                                      initialItemCount: deductionItems.length,
                                    ),
                                  ),
                                if (payoutProvider.deductionDetails?.cash !=
                                    null)
                                  ElevatedButton(
                                    onPressed: () {
                                      _toggleCashItems();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.r0,
                                      foregroundColor: AppColors.r30,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            8.r), // Customize the radius
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 21.h,
                                        horizontal: 16.w,
                                      ),
                                      side: const BorderSide(
                                          color: AppColors.r50),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            payoutProvider.deductionDetails
                                                    ?.cash?.title ??
                                                "Cash Collected",
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayLarge
                                                ?.copyWith(
                                                  fontStyle: FontStyle.normal,
                                                  color: AppColors.r50,
                                                  fontSize: 16.sp,
                                                ),
                                          ),
                                        ),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                    "₹${payoutProvider.deductionDetails?.cash?.total ?? 0} ",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displayLarge
                                                    ?.copyWith(
                                                      fontStyle:
                                                          FontStyle.normal,
                                                      color: AppColors.r50,
                                                      fontSize: 16.sp,
                                                    ),
                                              ),
                                              WidgetSpan(
                                                alignment:
                                                    PlaceholderAlignment.middle,
                                                child: AnimatedRotation(
                                                  turns:
                                                      isAddingCash ? 0.25 : 0.0,
                                                  duration: const Duration(
                                                      milliseconds: 100),
                                                  child: const Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: AppColors.r50,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (payoutProvider.deductionDetails?.cash !=
                                    null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 16.h),
                                    child: AnimatedList(
                                      key: _cashListKey,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemBuilder: (_, index, animation) {
                                        DeductionData? deductionData =
                                            payoutProvider.deductionDetails
                                                ?.cash?.items?[index];
                                        return _buildAnimatedItem(
                                            deductionData, animation);
                                      },
                                      initialItemCount: cashItems.length,
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
