import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/widgets/insurance_support/lose_benefits_warning.dart';

import '../constants/assets_constants.dart';
import '../providers/language_provider.dart';
import '../providers/user_profile.dart';
import '../utils/colors.dart';
import '../utils/enums.dart';

class ExpertInfoAppbar extends StatefulWidget {
  const ExpertInfoAppbar({
    super.key,
  });

  @override
  State<ExpertInfoAppbar> createState() => _ExpertInfoAppbarState();
}

class _ExpertInfoAppbarState extends State<ExpertInfoAppbar> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  bool profilePicError = false;

  Widget? tierBadge;
  String? bgImage;
  Color? titleColor;
  LinearGradient? dividerGradient;

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
        bgImage = AssetConstants.tierBronzeAppbar;
        titleColor = const Color(0xFF111827);
        dividerGradient = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x00C95555),
            Color(0x4DC95555),
            Color(0x4DC95555),
            Color(0x00C95555),
          ],
          stops: [0.0, 0.1068, 0.8815, 1.0],
        );
        tierBadge = TierBadge(
          bgColor: const Color(0xFFC95555),
          asset: AssetConstants.tierBronzeBadge,
          tier: userProfileProvider.user?.tier,
          textColor: const Color(0xFFF9FAFB),
        );
        break;
      case Tier.PRO:
        bgImage = AssetConstants.tierSilverAppbar;
        titleColor = const Color(0xFF111827);
        dividerGradient = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x008874D8),
            Color(0x4D8874D8),
            Color(0x4D8874D8),
            Color(0x008874D8),
          ],
          stops: [0.0, 0.1068, 0.8815, 1.0],
        );
        tierBadge = TierBadge(
          bgColor: const Color(0xFF8874D8),
          asset: AssetConstants.tierSilverBadge,
          tier: userProfileProvider.user?.tier,
          textColor: const Color(0xFFF9FAFB),
        );
        break;
      case Tier.ELITE:
        bgImage = AssetConstants.tierGoldAppbar;
        titleColor = const Color(0xFF111827);
        dividerGradient = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x00EAA10F),
            Color(0x4DEAA10F),
            Color(0x4DEAA10F),
            Color(0x00EAA10F),
          ],
          stops: [0.0, 0.1068, 0.8815, 1.0],
        );
        tierBadge = TierBadge(
          bgColor: const Color(0xFFEAA10F),
          asset: AssetConstants.tierGoldBadge,
          tier: userProfileProvider.user?.tier,
          textColor: const Color(0xFFF3F4F6),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            bgImage ?? "",
          ),
          fit: BoxFit.cover,
          onError: (_, __) => const SizedBox(),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: InkWell(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: AppColors.n80,
                  ),
                ),
              ),
              Column(
                children: [
                  SizedBox(height: 23.h),
                  Column(
                    children: [
                      Transform.translate(
                        offset: Offset(0, 15.h),
                        child: CircleAvatar(
                          radius: 40.r,
                          backgroundImage:
                              userProfileProvider.user?.publicPic != null
                                  ? NetworkImage(
                                      userProfileProvider.user!.publicPic!)
                                  : null,
                          backgroundColor: const Color(0xFFD9D9D9),
                          onBackgroundImageError: (_, __) {
                            setState(() {
                              profilePicError = true;
                            });
                          },
                          child: userProfileProvider.user?.publicPic == null ||
                                  profilePicError
                              ? Icon(Icons.person,
                                  size: 32.r, color: AppColors.n0)
                              : null,
                        ),
                      ),
                      if (tierBadge != null) tierBadge!,
                    ],
                  ),
                  SizedBox(height: 10.h),

                  // Name
                  Text(
                    userProfileProvider.user?.name ?? "",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: titleColor ?? AppColors.n90,
                        ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                  SizedBox(height: 4.h),

                  // Phone
                  if (userProfileProvider.user?.showPhoneNumber == true)
                    Text(
                      "${userProfileProvider.user?.countryCode ?? ""} ${userProfileProvider.user?.phoneNumber ?? ""}",
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: titleColor ?? AppColors.n90,
                              ),
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: 8.h, horizontal: 50.w),
                    child: Container(
                      height: 1.h,
                      decoration: BoxDecoration(
                        gradient: dividerGradient,
                      ),
                    ),
                  ),
                  // Rating number
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // RATING_HIDDEN: start
                      // Icon(
                      //   Icons.star_rounded,
                      //   color: titleColor ?? AppColors.n90,
                      //   size: 14.sp,
                      // ),
                      // SizedBox(width: 2.w),
                      // Text(
                      //   userProfileProvider.user?.currentMonthRating
                      //           ?.toStringAsFixed(1) ??
                      //       "0.0",
                      //   style:
                      //       Theme.of(context).textTheme.displayMedium?.copyWith(
                      //             fontWeight: FontWeight.w800,
                      //             color: titleColor ?? AppColors.n90,
                      //           ),
                      // ),
                      // SizedBox(width: 14.w),
                      // RATING_HIDDEN: end
                      SvgPicture.asset(
                        userProfileProvider.user?.alternateDeliveryMethod
                                ?.getAsset() ??
                            "",
                        width: 16.r,
                        height: 16.r,
                        color: titleColor ?? AppColors.n90,
                        // errorBuilder: (context, error, stackTrace) =>
                        // const SizedBox(),
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        userProfileProvider.user?.alternateDeliveryMethod?.name
                                .toUpperCase() ??
                            "",
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: titleColor ?? AppColors.n90,
                                ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  LoseBenefitsWarning(),
                ],
              ),
            ],
          ),
        ),
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
        horizontal: 6.w,
        vertical: 3.h,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            asset,
            height: 21.r,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
          SizedBox(width: 2.w),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tier?.description ?? "",
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
