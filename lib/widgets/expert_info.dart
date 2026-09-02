import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/payout/performance.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/tiering/view_tier_from_drawer_menu.dart';
import 'package:snabbit_runner/widgets/tiering/snabbit_udaan_play_video_row.dart';
import '../utils/enums.dart';
import 'package:snabbit_runner/widgets/drawer/vishwaas_drawer_banner.dart';


class ExpertInfo extends StatefulWidget {
  const ExpertInfo({
    super.key,
  });

  @override
  State<ExpertInfo> createState() => _ExpertInfoState();
}

class _ExpertInfoState extends State<ExpertInfo> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  bool profilePicError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
  }

  bool get isHighlyRated {
    try {
      return userProfileProvider.user!.currentMonthRating! >= 4.3;
    } catch (e) {
      return false;
    }
  }

  bool get isTieringEnabled => !(userProfileProvider.user?.tier?.isLegacyTier ?? false);

  /// CDN blood-drop icon (same as period-leave sheets / emergency logout).
  final String _kPeriodLeaveDropIconUrl =
      'https://assets-expert.snabbit.com/payouts/nudges/period_leave_drop.png';

  /// Figma 6705:146043 — period leave label (gray-600).
  Color get _kPeriodLeaveChipTextColor => isTieringEnabled? AppColors.n0 : Color(0xff000000);

  @override
  Widget build(BuildContext context) {
    final periodLeave = context.watch<PeriodLeaveProvider>();
    final showVishwaasBanner =
        context.watch<UserProfileProvider>().showVishwaasBanner;
    debugPrint('showVishwaasBanner: $showVishwaasBanner');
    final periodLeaveMax = periodLeave.periodLeaveTotal;
    final periodLeaveTaken = periodLeaveMax == 0
        ? 0
        : (periodLeaveMax - periodLeave.periodLeaveRemaining)
            .clamp(0, periodLeaveMax);

    // Tier header styling.
    // - New tiering UI (gated by the tier effective date via `isTieringEnabled`):
    //   remote per-tier background, white title/subtitle, no badge.
    // - Legacy fallback (tiering not yet live): the existing bronze/silver/gold
    //   backgrounds + tier badges — kept for backward compatibility
    //   (BASIC / PRO / ELITE; PRO & ELITE are being dropped later).
    final user = userProfileProvider.user;
    ImageProvider? bgImageProvider;
    Widget? tierBadge;
    Color? titleColor;
    Color? subtitleColor;

    if (isTieringEnabled) {
      final String? bgUrl = switch (user?.tier) {
        Tier.BASE => RemoteConfigAssets.drawerMenuBasicTierBg,
        Tier.SILVER => RemoteConfigAssets.drawerMenuSilverTierBg,
        Tier.GOLD => RemoteConfigAssets.drawerMenuGoldTierBg,
        Tier.DIAMOND => RemoteConfigAssets.drawerMenuDiamondTierBg,
        Tier.PINK_DIAMOND => RemoteConfigAssets.drawerMenuBasicPinkDiamondBg,
        Tier.PRO || Tier.ELITE || Tier.BASIC || null => null,
      };
      if (bgUrl != null) {
        bgImageProvider = CachedNetworkImageProvider(bgUrl);
        titleColor = AppColors.n0;
        subtitleColor = AppColors.n0;
      }
    } else {
      switch (user?.tier) {
        case Tier.BASIC:
          bgImageProvider = const AssetImage(AssetConstants.tierBronzeBg);
          titleColor = const Color(0xFF111827);
          subtitleColor = const Color(0xFF111827);
          tierBadge = TierBadge(
            bgColor: const Color(0xFFC95555),
            asset: AssetConstants.tierBronzeBadge,
            tier: user?.tier,
            textColor: const Color(0xFFF9FAFB),
          );
          break;
        case Tier.PRO:
          bgImageProvider = const AssetImage(AssetConstants.tierSilverBg);
          titleColor = const Color(0xFF111827);
          subtitleColor = const Color(0xFF111827);
          tierBadge = TierBadge(
            bgColor: const Color(0xFF8874D8),
            asset: AssetConstants.tierSilverBadge,
            tier: user?.tier,
            textColor: const Color(0xFFF9FAFB),
          );
          break;
        case Tier.ELITE:
          bgImageProvider = const AssetImage(AssetConstants.tierGoldBg);
          titleColor = const Color(0xFF111827);
          subtitleColor = const Color(0xFF111827);
          tierBadge = TierBadge(
            bgColor: const Color(0xFFEAA10F),
            asset: AssetConstants.tierGoldBadge,
            tier: user?.tier,
            textColor: const Color(0xFFF3F4F6),
          );
          break;
        default:
          break;
      }
    }

    return Column(
      children: [
        //top content
        Container(
          decoration: bgImageProvider != null
              ? BoxDecoration(
                  image: DecorationImage(
                    image: bgImageProvider,
                    fit: BoxFit.cover,
                    alignment: isTieringEnabled
                        ? Alignment.centerRight
                        : Alignment.center,
                    onError: (_, __) {},
                  ),
                )
              : null,
          child: SafeArea(
            bottom: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 140.h),
              child: Padding(
                padding: EdgeInsets.only(left: 16.r, right: 16.r, bottom: 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Profile + text + period leave (Figma 6705:146043).
                    Expanded(
                      flex: 65,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Transform.translate(
                                    offset: Offset(0, 10.h),
                                    child: CircleAvatar(
                                      radius: 32.r,
                                      backgroundImage:
                                          userProfileProvider.user?.publicPic !=
                                                  null
                                              ? NetworkImage(userProfileProvider
                                                  .user!.publicPic!)
                                              : null,
                                      backgroundColor: const Color(0xFFD9D9D9),
                                      onBackgroundImageError: (_, __) {
                                        setState(() {
                                          profilePicError = true;
                                        });
                                      },
                                      child:
                                          userProfileProvider.user?.publicPic ==
                                                      null ||
                                                  profilePicError
                                              ? Icon(Icons.person,
                                                  size: 32.r,
                                                  color: AppColors.n0)
                                              : null,
                                    ),
                                  ),
                                  if (tierBadge != null) tierBadge,
                                ],
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userProfileProvider.user?.name ?? "",
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 17.sp,
                                            height: 1.2,
                                            color: titleColor ?? AppColors.n90,
                                          ),
                                      softWrap: true,
                                    ),
                                    SizedBox(height: 8.h),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // RATING_HIDDEN: start
                                        // Row(
                                        //   mainAxisSize: MainAxisSize.min,
                                        //   crossAxisAlignment:
                                        //       CrossAxisAlignment.center,
                                        //   children: [
                                        //     SizedBox(
                                        //       width: 16.r,
                                        //       height: 16.r,
                                        //       child: Center(
                                        //         child: Icon(
                                        //           Icons.star_rounded,
                                        //           color: subtitleColor ??
                                        //               AppColors.n90,
                                        //           size: 14.sp,
                                        //         ),
                                        //       ),
                                        //     ),
                                        //     SizedBox(width: 2.w),
                                        //     Text(
                                        //       userProfileProvider
                                        //               .user?.currentMonthRating
                                        //               ?.toStringAsFixed(1) ??
                                        //           "0.0",
                                        //       style: Theme.of(context)
                                        //           .textTheme
                                        //           .displayMedium
                                        //           ?.copyWith(
                                        //             fontWeight: FontWeight.w800,
                                        //             fontSize: 14.sp,
                                        //             height: 1.0,
                                        //             color: subtitleColor ??
                                        //                 AppColors.n90,
                                        //           ),
                                        //     ),
                                        //   ],
                                        // ),
                                        // SizedBox(width: 14.w),
                                        // RATING_HIDDEN: end
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 16.r,
                                              height: 16.r,
                                              child: Center(
                                                child: SvgPicture.asset(
                                                  userProfileProvider.user
                                                          ?.alternateDeliveryMethod
                                                          ?.getAsset() ??
                                                      "",
                                                  width: 16.r,
                                                  height: 16.r,
                                                  fit: BoxFit.contain,
                                                  colorFilter: ColorFilter.mode(
                                                    subtitleColor ??
                                                        AppColors.n90,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 2.w),
                                            Text(
                                              userProfileProvider
                                                      .user
                                                      ?.alternateDeliveryMethod
                                                      ?.name
                                                      .toUpperCase() ??
                                                  "",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displayMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14.sp,
                                                    height: 1.0,
                                                    color: subtitleColor ??
                                                        AppColors.n90,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (periodLeaveMax > 0) ...[
                            SizedBox(height: 8.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 12.r,
                                    height: 12.r,
                                    child: CachedNetworkImage(
                                      imageUrl: _kPeriodLeaveDropIconUrl,
                                      fit: BoxFit.contain,
                                      placeholder: (_, __) =>
                                          SizedBox(width: 12.r, height: 12.r),
                                      errorWidget: (_, __, ___) => Icon(
                                        Icons.water_drop_rounded,
                                        size: 12.r,
                                        color: AppColors.r50,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    languageProvider.getFormattedMessage(
                                      'period_leave_with_quota',
                                      'Period Leave ({{taken}}/{{max}})',
                                      {
                                        'taken': periodLeaveTaken,
                                        'max': periodLeaveMax,
                                      },
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.sp,
                                          letterSpacing: -0.24,
                                          color: _kPeriodLeaveChipTextColor,
                                        ),
                                  ),
                                  SizedBox(height: 8.h),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Expanded(flex: 35, child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        ),
        ViewTierFromDrawerMenu(),
        const SnabbitUdaanPlayVideoRow(),

        //btn content
        if (showVishwaasBanner) const VishwaasDrawerBanner(),
        
        if (userProfileProvider.user?.currentMonthRating != null)
          SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushNamed(Performance.routeName);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 17.w, vertical: 5.h),
                decoration: BoxDecoration(
                    color: isHighlyRated
                        ? const Color(0xFFF5F5F5)
                        : const Color(0xffD33F4C),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8.r),
                      bottomRight: Radius.circular(8.r),
                    )),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(3.r),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isHighlyRated
                                  ? const Color(0xFFFBBC05)
                                  : AppColors.r50,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: AppColors.n0,
                            ),
                          ),
                          SizedBox(
                            width: 9.w,
                          ),
                          Text(
                            languageProvider
                                .getMessage(
                                  "improve_ratings",
                                  "Improve Ratings",
                                )
                                .capitalize(),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: isHighlyRated
                                      ? const Color(0xFFA27900)
                                      : AppColors.n10,
                                  fontSize: 12.sp,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: isHighlyRated
                          ? const Color(0xFFA27900)
                          : AppColors.n0,
                      size: 15.r,
                    )
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TierBadge extends StatelessWidget {
  final Color bgColor;
  final String asset;
  final Tier? tier;
  final Color textColor;

  const TierBadge({
    super.key,
    required this.bgColor,
    required this.asset,
    required this.textColor,
    this.tier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1000.r),
        color: bgColor,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 3.w,
        vertical: 1.h,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            asset,
            height: 15.r,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
          SizedBox(width: 2.w),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tier?.description ?? "",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
