import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../providers/payout.dart';

class AdjustmentSummaryView extends StatefulWidget {
  const AdjustmentSummaryView({super.key});

  @override
  State<AdjustmentSummaryView> createState() => _AdjustmentSummaryViewState();
}

class _AdjustmentSummaryViewState extends State<AdjustmentSummaryView>
    with SingleTickerProviderStateMixin {
  bool init = true;
  bool isExpanded = false;
  late PayoutProvider payoutProvider;
  late LanguageProvider languageProvider;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  void _toggleExpansion() {
    setState(() {
      isExpanded = !isExpanded;
      if (isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _toggleExpansion,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    RemoteImageHandler(
                      imageUrl:
                          "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/payouts/referrals/referral_minus.svg",
                      width: 18.r,
                    ),
                    SizedBox(width: 8.r),
                    Text(
                      languageProvider.getMessage('adjustments', 'Adjustments'),
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: AppColors.n90),
                    ),
                    SizedBox(width: 8.r),
                    AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: -_rotationAnimation.value * math.pi/2,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.n90,
                            size: 20.r,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Text(
                "-₹${payoutProvider.earnings?.adjustmentDetails?.total}",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: AppColors.r50),
              ),
            ],
          ),
        ),
        if (payoutProvider.earnings?.adjustmentDetails?.summaryItems != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              margin: EdgeInsets.only(
                top: isExpanded ? 8.h : 0,
                left: 26.r,
              ),
              child: isExpanded
                  ? Column(
                      children: payoutProvider
                              .earnings?.adjustmentDetails?.summaryItems
                              ?.map((e) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 2.h),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      languageProvider.getMessage(
                                        e.key!,
                                        e.key!,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.n70),
                                    ),
                                  ),
                                  Text(
                                    "-₹${e.value}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppColors.r50),
                                  ),
                                ],
                              ),
                            );
                          }).toList() ??
                          [])
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}
