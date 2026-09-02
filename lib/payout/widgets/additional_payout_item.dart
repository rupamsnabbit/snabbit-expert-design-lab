import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Widget to display an additional payout item with optional dropdown for subitems
class AdditionalPayoutItem extends StatefulWidget {
  final AdditionalPayout payout;

  const AdditionalPayoutItem({
    super.key,
    required this.payout,
  });

  @override
  State<AdditionalPayoutItem> createState() => _AdditionalPayoutItemState();
}

class _AdditionalPayoutItemState extends State<AdditionalPayoutItem> {
  bool _isExpanded = false;
  late LanguageProvider _languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSubitems = widget.payout.subitems?.isNotEmpty == true;
    final String title = widget.payout.key ?? '';
    final double amount = widget.payout.amount ?? 0;
    final String amountText = formatIndianCurrency2(amount);

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (hasSubitems)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _languageProvider.getMessage(title, title),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.n70,
                                  ),
                            ),
                            SizedBox(width: 4.w),
                            SvgPicture.asset(
                              _isExpanded
                                  ? AssetConstants.navigateChevronDown
                                  : AssetConstants.navigateChevronRight,
                              width: 15.w,
                              height: 15.h,
                              colorFilter: ColorFilter.mode(
                                AppColors.n70,
                                BlendMode.srcIn,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      _languageProvider.getMessage(title, title),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.n70,
                          ),
                    ),
                  if ((widget.payout.tooltip ?? '').isNotEmpty)
                    SizedBox(width: 4.w),
                  if ((widget.payout.tooltip ?? '').isNotEmpty)
                    Tooltip(
                      richMessage: TextSpan(
                        text: _languageProvider.getMessage(
                          widget.payout.tooltip!,
                          widget.payout.tooltip!,
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.n0,
                            ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 10.w,
                      ),
                      showDuration: const Duration(seconds: 3),
                      triggerMode: TooltipTriggerMode.tap,
                      preferBelow: true,
                      child: SvgPicture.asset(
                        AssetConstants.tooltip,
                        width: 15.w,
                        height: 15.h,
                      ),
                    ),
                ],
              ),
              Text(
                amountText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.n70,
                    ),
              ),
            ],
          ),
          if (hasSubitems && _isExpanded) ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.n10,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xffE6E8F0),
                ),
              ),
              child: Column(
                children: widget.payout.subitems!
                    .map(
                      (subitem) => Padding(
                        padding: EdgeInsets.only(
                          bottom: subitem == widget.payout.subitems!.last
                              ? 0
                              : 12.h,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _languageProvider.getMessage(
                                      subitem.title ?? '',
                                      subitem.title ?? '',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.n90,
                                        ),
                                  ),
                                  if ((subitem.subtitle ?? '').isNotEmpty) ...[
                                    SizedBox(height: 4.h),
                                    Text(
                                      _languageProvider.getMessage(
                                        subitem.subtitle ?? '',
                                        subitem.subtitle ?? '',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.n70,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              formatIndianCurrency2((subitem.amount ?? 0)),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.n70,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
