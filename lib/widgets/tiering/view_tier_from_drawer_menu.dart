import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/tiering/tiering_analytics.dart';

/// Drawer-menu row showing the runner's current tier (badge + name, e.g.
/// "Silver Tier") on a per-tier coloured background, with a trailing "View tier" +
/// chevron that opens the Tiers home page ([WebviewRoutes.tiersHome]) in the
/// bifrost webview.
///
/// Visible only once tiering is live for the runner — i.e. the current date is
/// on/after the profile's tier effective date ([UserProfile.isTieringEnabled]).
/// Tiers without a colour/badge (PRO / ELITE — being dropped — or none) collapse
/// to a [SizedBox.shrink].
class ViewTierFromDrawerMenu extends StatefulWidget {
  const ViewTierFromDrawerMenu({super.key});

  @override
  State<ViewTierFromDrawerMenu> createState() =>
      _ViewTierFromDrawerMenuState();
}

class _ViewTierFromDrawerMenuState extends State<ViewTierFromDrawerMenu> {
  static const String _webViewTitle = 'Snabbit Udaan';

  /// Last tier an impression was logged for — guards re-firing `viewed` on
  /// every provider rebuild while the row stays visible.
  Tier? _lastImpressionTier;

  void _openTierHome(BuildContext context) {
    final url = buildWebviewUrl(WebviewRoutes.tiersHome);
    if (!WebViewLauncher.isOpenableHttps(url)) return;
    WebViewLauncher.open(context, url: url, title: _webViewTitle);
  }

  /// Fires a one-shot `viewed` impression when the visible tier changes. Fired
  /// inline from [build], guarded by `_lastImpressionTier`.
  void _logImpression(Tier? tier) {
    if (tier == _lastImpressionTier) return;
    _lastImpressionTier = tier;
    TieringAnalytics.drawerViewed(tier);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProfileProvider, LanguageProvider>(
      builder: (context, provider, languageProvider, _) {
        final user = provider.user;
        if (provider.user?.tier?.isLegacyTier ?? false) {
          return const SizedBox.shrink();
        }

        final tier = user?.tier;
        final chrome = _chromeFor(tier);
        if (tier == null || chrome == null) {
          return const SizedBox.shrink();
        }

        _logImpression(tier);
        return Container(
          width: double.infinity,
          color: chrome.background,
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 24.r,
                      height: 24.r,
                      child: RemoteImageHandler(
                        imageUrl: chrome.badgeUrl,
                        fit: BoxFit.contain,
                        animate: false,
                        loadingWidget: const SizedBox.shrink(),
                        errorWidget: const SizedBox.shrink(),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        '${tier.normalizedDescription ?? ''} Level'.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.n0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () {
                  TieringAnalytics.drawerClicked(tier);
                  _openTierHome(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      languageProvider.getMessage('view_tier','View level'),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.n0,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.n0,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.chevron_right,
                      size: 16.r,
                      color: AppColors.n0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Per-tier background colour + badge asset. Null for tiers we don't surface
/// here (PRO / ELITE — being dropped).
class _TierChrome {
  const _TierChrome(this.background, this.badgeUrl);

  final Color background;
  final String badgeUrl;
}

_TierChrome? _chromeFor(Tier? tier) {
  return switch (tier) {
    Tier.BASE => _TierChrome(AppColors.tierBgBase, RemoteConfigAssets.baseTier),
    Tier.SILVER =>
      _TierChrome(AppColors.tierBgSilver, RemoteConfigAssets.silverTier),
    Tier.GOLD => _TierChrome(AppColors.tierBgGold, RemoteConfigAssets.goldTier),
    Tier.DIAMOND =>
      _TierChrome(AppColors.tierBgDiamond, RemoteConfigAssets.diamondTier),
    Tier.PINK_DIAMOND =>
      _TierChrome(AppColors.tierBgPinkDiamond, RemoteConfigAssets.pinkDiamondTier),
    Tier.PRO || Tier.ELITE || Tier.BASIC || null => null,
  };
}
