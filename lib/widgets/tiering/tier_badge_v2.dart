import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Tier badge (v2) — a rounded pill with the tier's badge image and its name,
/// coloured per tier (Figma "tier badge v2" frames). The base tier is `BASE`
/// (the renamed BASIC). Renders a [SizedBox.shrink] for tiers without a v2 badge
/// (legacy `BASIC` / `PRO` / `ELITE` / null).
class TierBadgeV2 extends StatelessWidget {
  const TierBadgeV2({super.key, });

  void _openWebView(BuildContext context) {
    final path = WebviewRoutes.tiersHome;
    if (path.isEmpty) return;
    final url = buildWebviewUrl(path);
    if (!WebViewLauncher.isOpenableHttps(url)) return;
    WebViewLauncher.open(context, url: url, title: "Levels Home");
  }


  @override
  Widget build(BuildContext context) {
   return Consumer<UserProfileProvider>(builder: (context, value, child) {
     final tier = value.user?.tier;
     final style = _styleFor(tier);
        if (!value.shouldShowTiering || style==null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _openWebView(context),
          child: Container(
                 padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                 decoration: BoxDecoration(
           color: style.background,
           borderRadius: BorderRadius.circular(24.r),
           border: Border.all(color: style.border, width: 1.r),
                 ),
                 child: Row(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.center,
           children: [
             SizedBox(
               width: 18.r,
               height: 18.r,
               child: RemoteImageHandler(
                 key: ValueKey(style.badgeUrl),
                 imageUrl: style.badgeUrl,
                 fit: BoxFit.contain,
                 animate: false,
                 loadingWidget: const SizedBox.shrink(),
                 errorWidget: const SizedBox.shrink(),
               ),
             ),
             SizedBox(width: 2.w),
             Text(
               tier?.normalizedDescription ?? '',
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
               style: TextStyle(
                 fontSize: 14.sp,
                 fontWeight: FontWeight.w600,
                 letterSpacing: -0.24,
                 color: style.text,
               ),
             ),
           ],
                 ),
               ),
        );
   },);
  }
}

/// Resolved per-tier badge styling; null for tiers without a v2 badge.
class _TierBadgeStyle {
  const _TierBadgeStyle({
    required this.background,
    required this.border,
    required this.text,
    required this.badgeUrl,
  });

  final Color background;
  final Color border;
  final Color text;
  final String badgeUrl;
}

_TierBadgeStyle? _styleFor(Tier? tier) {
  switch (tier) {
    case Tier.BASE:
      return _TierBadgeStyle(
        background: AppColors.tierBadgeBaseBg,
        border: AppColors.tierBadgeBaseBorder,
        text: AppColors.tierBadgeBaseText,
        badgeUrl: RemoteConfigAssets.baseTier,
      );
    case Tier.SILVER:
      return _TierBadgeStyle(
        background: AppColors.tierBadgeSilverBg,
        border: AppColors.tierBadgeSilverBorder,
        text: AppColors.tierBadgeSilverText,
        badgeUrl: RemoteConfigAssets.silverTier,
      );
    case Tier.GOLD:
      return _TierBadgeStyle(
        background: AppColors.tierBadgeGoldBg,
        border: AppColors.tierBadgeGoldBorder,
        text: AppColors.tierBadgeGoldText,
        badgeUrl: RemoteConfigAssets.goldTier,
      );
    case Tier.DIAMOND:
      return _TierBadgeStyle(
        background: AppColors.tierBadgeDiamondBg,
        border: AppColors.tierBadgeDiamondBorder,
        text: AppColors.tierBadgeDiamondText,
        badgeUrl: RemoteConfigAssets.diamondTier,
      );
    case Tier.PINK_DIAMOND:
      return _TierBadgeStyle(
        background: AppColors.tierBadgePinkDiamondBg,
        border: AppColors.tierBadgePinkDiamondBorder,
        text: AppColors.tierBadgePinkDiamondText,
        badgeUrl: RemoteConfigAssets.pinkDiamondTier,
      );
    // Legacy / no v2 badge.
    case Tier.BASIC:
    case Tier.PRO:
    case Tier.ELITE:
    case null:
      return null;
  }
}
