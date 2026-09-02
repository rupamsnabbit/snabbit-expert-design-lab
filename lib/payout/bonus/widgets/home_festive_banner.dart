import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/effects/blinking.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../../services/payout_http.dart';
import '../models/festive_bonus.dart';
import '../pages/festive_bonus_screen.dart';

class HomeFestiveBanner extends StatefulWidget {
  final Map<String, dynamic>? data;

  const HomeFestiveBanner({
    super.key,
    this.data,
  });

  @override
  State<HomeFestiveBanner> createState() => _HomeFestiveBannerState();
}

class _HomeFestiveBannerState extends State<HomeFestiveBanner> {
  FestiveBanner? banner;

  @override
  void initState() {
    if (widget.data != null) {
      banner = FestiveBanner.fromJson(widget.data!);
    }
    super.initState();
  }

  void showModalBottomNeedHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: 0.85.sh,
      ),
      builder: (context) {
        return const CommonBottomSheetSetup(
          child: BottomSheetFestiveTracker(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: banner == null
          ? const SizedBox()
          : GestureDetector(
              onTap: () {
                showModalBottomNeedHelp();
              },
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  RemoteImageHandler(
                    imageUrl: banner?.bgImage?.url ?? "",
                    fit: BoxFit.cover,
                    width: 1.sw,
                    errorWidget: Container(
                      width: 1.sw,
                      height: banner?.bgImage?.height?.h,
                      color: banner?.bgImage?.color,
                    ),
                  ),
                  if (banner != null)
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(13.w, 14.h, 15.w, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: CustomText(textData: banner?.title),
                                ),
                              ),
                            ),
                            CustomText(textData: banner?.value),
                          ],
                        ),
                      ),
                    ),
                  if (banner?.footer != null)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                              bottom: 5.h, left: 12.w, right: 12.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              BlinkingWidget(
                                child: RemoteImageHandler(
                                  imageUrl: banner?.footer?.icon?.url ?? "url",
                                  height: banner?.footer?.icon?.height,
                                ),
                              ),
                              SizedBox(width: 7.w),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: CustomText(
                                      textData: banner?.footer?.title,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class BottomSheetFestiveTracker extends StatefulWidget {
  const BottomSheetFestiveTracker({super.key});

  @override
  State<BottomSheetFestiveTracker> createState() =>
      _BottomSheetFestiveTrackerState();
}

class _BottomSheetFestiveTrackerState extends State<BottomSheetFestiveTracker> {
  bool loading = true;
  FestiveBonus? festiveBonus;

  @override
  void initState() {
    initProcess().then((_) {
      loading = false;
      if (mounted) setState(() {});
    });
    super.initState();
  }

  Future<void> initProcess() async {
    try {
      final response = await PayoutHttp.getFestiveBonus();
      if (response != null) {
        festiveBonus = FestiveBonus.fromJson(response.data);
      }
    } catch (e) {
      // DO NOTHING
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? SizedBox(
            height: 0.3.sh,
            child: const Center(child: CupertinoActivityIndicator()),
          )
        : festiveBonus == null
            ? SizedBox(
                height: 0.3.sh,
                child: const Center(child: Text("No data found")),
              )
            : Column(
                children: [
                  SizedBox(height: 16.h),
                  CalendarSectionView(
                    dateWiseDeductions: festiveBonus?.dateWiseDeductions,
                  ),
                  SizedBox(height: 8.h),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamed(FestiveBonusScreen.routeName);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomText(
                          textData: {
                            "text": "View earnings",
                            "key": "view_earnings",
                            "style": {"color": "#FFFFFF", "name": "labelLarge"}
                          },
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.n0,
                        )
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              );
  }
}
