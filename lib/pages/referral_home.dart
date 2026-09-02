import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/widgets/generic_banner_widget.dart';
import 'package:snabbit_runner/models/banner_config.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/referrals/widgets/lifetime_earnings.dart';
import 'package:snabbit_runner/referrals/widgets/monthly_view.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/constants.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../providers/contest_data_provider.dart';
import '../providers/referral.dart';
import '../referrals/widgets/referral_header.dart';
import '../widgets/referral_progress_steps.dart';

class ReferralsHome extends StatefulWidget {
  static const String routeName = "/referral-home";

  const ReferralsHome({super.key});

  @override
  ReferralsHomeState createState() => ReferralsHomeState();
}

class ReferralsHomeState extends State<ReferralsHome> {
  bool init = true;
  late LanguageProvider languageProvider;
  late ReferralDataProvider referralDataProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  late UserProfileProvider userProfileProvider;
  late ContestDataProvider contestDataProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);
      contestDataProvider =
          Provider.of<ContestDataProvider>(context, listen: false);

      referralDataProvider.reset();
      initProcess().then((_) {
        if (mounted) {
          referralDataProvider.setLoading(false);
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    await referralDataProvider.getReferralDetails(setLoadingFalse: false);
    await referralDataProvider.getReferrals(queryParameters: {
      'from_date': dateFormat.format(currentPeriodProvider.monthStartDate),
      'to_date': dateFormat.format(currentPeriodProvider.monthEndDate),
    });
  }

  void onTapCurrentReferral(RunnerReferral currentReferral) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: 0.7.sh,
      ),
      builder: (_) {
        return CommonBottomSheetSetup(
          child: ReferralProgressSteps(
            currentReferral: currentReferral,
          ),
        );
      },
    );
  }

  bool get isMonthlyEmptyView {
    return referralDataProvider.monthlyData?.referrals?.isEmpty ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        title: Text(
          "#${userProfileProvider.user?.id}",
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
      persistentFooterButtons: [
        Column(
          children: [
            const ReferNowButton(),
            if ((referralDataProvider.referralData?.earners ?? []).isNotEmpty)
              SizedBox(
                height: 46.h,
                child: const ReferralEarners(),
              ),
          ],
        ),
      ],
      body: referralDataProvider.error != null ||
              referralDataProvider.referralData == null
          ? Column(
              children: [
                referralDataProvider.loading == true
                    ? const Expanded(
                        child: Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      )
                    : referralDataProvider.error != null
                        ? Expanded(
                            child: Center(
                              child: Text(referralDataProvider.error ??
                                  "Something went wrong"),
                            ),
                          )
                        : Expanded(
                            child: Center(
                              child: Text(
                                  "Something went wrong - ${referralDataProvider.referralData}"),
                            ),
                          )
              ],
            )
          : RefreshIndicator(
              onRefresh: () async {
                await initProcess();
                referralDataProvider.setLoading(false);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.r),
                      child: const GenericBannerWidget(
                          placement: BannerPlacement.referral,
                          position: 'above_referral'),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xff008E3E),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(20.r),
                        ),
                      ),
                      child: ReferralHeaderBase(
                        data: referralDataProvider.referralData!,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.r),
                      child: const GenericBannerWidget(
                          placement: BannerPlacement.referral,
                          position: 'below_referral'),
                    ),
                    Padding(
                      padding: EdgeInsets.all(20.r),
                      child: const LifetimeEarnings(),
                    ),
                    CurrentPeriodView(
                      viewType: PayoutPeriod.monthly,
                      onChanged: () {
                        initProcess();
                      },
                      isNextDisabled: referralDataProvider.loading ||
                          currentPeriodProvider.monthStartDate.month ==
                              DateTime.now().month,
                      isPreviousDisabled: referralDataProvider.loading,
                    ),
                    const MonthlyView(),
                  ],
                ),
              ),
            ),
    );
  }
}

class ReferralEarners extends StatefulWidget {
  const ReferralEarners({
    super.key,
  });

  @override
  State<ReferralEarners> createState() => _ReferralEarnersState();
}

class _ReferralEarnersState extends State<ReferralEarners> {
  bool init = true;
  late LanguageProvider languageProvider;
  late ReferralDataProvider referralDataProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return EarnerTipsCarousel(
      items: referralDataProvider.referralData?.earners
              ?.map(
                (e) => EarnerSlide(earner: e),
              )
              .toList() ??
          [],
    );
  }
}

class EarnerTipsCarousel extends StatefulWidget {
  final List<Widget> items;

  const EarnerTipsCarousel({
    super.key,
    required this.items,
  });

  @override
  State<EarnerTipsCarousel> createState() => _EarnerTipsCarouselState();
}

class _EarnerTipsCarouselState extends State<EarnerTipsCarousel> {
  int _current = 0;
  int dotCount = 3;

  @override
  Widget build(BuildContext context) {
    return Consumer<ReferralDataProvider>(builder: (context, _, __) {
      dotCount = 3;
      dotCount = min(dotCount, widget.items.length);
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: CarouselSlider.builder(
                options: CarouselOptions(
                  scrollPhysics: const NeverScrollableScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  aspectRatio: 5,
                  autoPlay: widget.items.length > 1,
                  enableInfiniteScroll: widget.items.length > 1,
                  enlargeCenterPage: true,
                  viewportFraction: 1.0,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _current = index;
                    });
                  },
                ),
                // items: items,
                itemCount: widget.items.length,
                itemBuilder:
                    (BuildContext context, int itemIndex, int pageViewIndex) {
                  return widget.items[itemIndex];
                },
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(dotCount, (index) {
                bool activeFlag = ((_current == 0 && index == 0) ||
                    (_current == widget.items.length - 1 &&
                        index == dotCount - 1) ||
                    (_current != 0 &&
                        _current != widget.items.length - 1 &&
                        index == dotCount - 2));
                return Container(
                  width: activeFlag ? 8.r : 4.r,
                  height: activeFlag ? 8.r : 4.r,
                  margin: EdgeInsets.symmetric(vertical: 2.h, horizontal: 0.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeFlag ? AppColors.y60 : AppColors.y30,
                  ),
                );
              }),
            ),
          ],
        ),
      );
    });
  }
}

class EarnerSlide extends StatelessWidget {
  final Earner earner;

  const EarnerSlide({
    super.key,
    required this.earner,
  });

  @override
  Widget build(BuildContext context) {
    if ((earner.items ?? []).isEmpty) return const SizedBox();
    return Row(
      children: List.generate(earner.items!.length, (index) {
        final current = earner.items![index];
        return Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            decoration: BoxDecoration(
              border: index == 0
                  ? null
                  : const Border(
                      left: BorderSide(
                        color: Color(0xffCC9213),
                      ),
                    ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  RemoteImageHandler(
                    imageUrl: current.icon?.url ?? "",
                    height: current.icon?.height?.h,
                  ),
                  SizedBox(width: 4.w),
                  CustomText(textData: current.title),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
