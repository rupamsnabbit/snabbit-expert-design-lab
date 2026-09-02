import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/payout/rating_bonus_popup.dart';

class WelcomeBanner extends StatefulWidget {
  const WelcomeBanner({
    super.key,
  });

  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  bool profilePicError = false;

  Widget? tierBadge;
  String? bgImage;
  Color? titleColor;
  Color? subtitleColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      setDesignParams();
      setState(() {});
    }
  }

  void setDesignParams() {
    switch (userProfileProvider.user?.tier) {
      case Tier.BASIC:
        bgImage = AssetConstants.bronzeBanner;
        titleColor = const Color(0xff603E1A);
        subtitleColor = const Color(0xffBA6B4D);
        tierBadge = TierBadge(
          bgColor: const Color(0xfff8a965),
          asset: AssetConstants.tierBronzeBadge,
          tier: userProfileProvider.user?.tier,
          textColor: titleColor ?? AppColors.n90,
        );
        break;
      case Tier.PRO:
        bgImage = AssetConstants.tierSilverBg;
        titleColor = const Color(0xff525871);
        subtitleColor = const Color(0xff525871);
        tierBadge = TierBadge(
          bgColor: const Color(0xffd9dbde),
          asset: AssetConstants.tierSilverBadge,
          tier: userProfileProvider.user?.tier,
          textColor: const Color(0xff696864),
        );
        break;
      case Tier.ELITE:
        bgImage = AssetConstants.tierGoldBg;
        titleColor = const Color(0xff604D1A);
        subtitleColor = const Color(0xffBA6B4D);
        tierBadge = TierBadge(
          bgColor: const Color(0xfff6cf88),
          asset: AssetConstants.tierGoldBadge,
          tier: userProfileProvider.user?.tier,
          textColor: titleColor ?? AppColors.n90,
        );
        break;
      default:
        break;
    }
  }

  bool get isHighlyRated {
    try {
      return userProfileProvider.user!.realAvgRating! >= 4.3;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 329 / 87,
            child: Image.asset(
              bgImage ?? "",
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
              fit: BoxFit.fitWidth,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile image
                Expanded(
                  flex: 65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getMessage("welcome", "Welcome"),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 11.sp,
                              color: titleColor?.withOpacity(0.6),
                            ),
                        softWrap: true,
                      ),
                      Text(
                        userProfileProvider.user?.name ?? "",
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontSize: 15.889.sp,
                                  color: titleColor,
                                ),
                        softWrap: true,
                      ),
                      SizedBox(height: 8.h),
                      if (tierBadge != null) tierBadge!,
                    ],
                  ),
                ),
                const Expanded(flex: 35, child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
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
