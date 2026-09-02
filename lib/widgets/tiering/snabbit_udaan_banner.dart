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

/// "Introducing Snabbit Udaan" intro banner.
///
/// Hidden once the runner has viewed the tier intro
/// ([UserProfile.hasViewedIntro] via [UserProfileProvider]) — it collapses to a
/// [SizedBox.shrink]. Otherwise it renders the intro card in one of two states:
/// [showHeaderImage] true adds the hero header image above the copy; false is
/// the copy-only variant. Tapping **Accept** opens the Tiers home page
/// ([WebviewRoutes.tiersHome]) in the bifrost webview.
class SnabbitUdaanBanner extends StatefulWidget {
  const SnabbitUdaanBanner({
    super.key,
    this.showHeaderImage = true,
    this.margin
  });

  /// Whether to render the hero header image above the copy.
  final bool showHeaderImage;
  final EdgeInsets? margin;

  @override
  State<SnabbitUdaanBanner> createState() => _SnabbitUdaanBannerState();
}

class _SnabbitUdaanBannerState extends State<SnabbitUdaanBanner> {

  /// Guards the one-shot `viewed` impression while the banner is visible.
  bool _impressionLogged = false;
  bool init = true;
  late LanguageProvider _languageProvider;

  String get _title => _languageProvider.getMessage('snabbit_udaan_banner_title','Introducing Snabbit Udaan');
  String get _subtitle => _languageProvider.getMessage('snabbit_udaan_banner_subtitle','A new way to reward good work');
  String get _webViewTitle => _languageProvider.getMessage("snabbit_udaan_banner_webview_title",'Snabbit Udaan');

  @override
  void didChangeDependencies() {
    if(init){
      init=false;
      _languageProvider = Provider.of<LanguageProvider>(context,listen: true);
    }
    super.didChangeDependencies();
  }


  void _openTierHome(BuildContext context) {
    TieringAnalytics.bannerClicked(showHeaderImage: widget.showHeaderImage);
    final url = buildWebviewUrl(WebviewRoutes.tiersHome);
    if (!WebViewLauncher.isOpenableHttps(url)) return;
    WebViewLauncher.open(context, url: url, title: _webViewTitle);
  }

  /// Fires a one-shot impression the first time the banner is shown (the runner
  /// hasn't viewed the intro). Fired inline from [build], guarded so it logs
  /// once per mount.
  void _logImpression() {
    if (_impressionLogged) return;
    _impressionLogged = true;
    TieringAnalytics.bannerViewed(showHeaderImage: widget.showHeaderImage);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, provider, _) {
        // Show only to tiering-enabled runners who haven't accepted the intro —
        // the pre-intro mirror of `shouldShowTiering` (drawer row, play-video
        // row, TierBadgeV2 all require isTieringEnabled). `has_viewed_intro`
        // defaults to false, so without the isTieringEnabled gate this would
        // surface to non-tiering runners.
        if (provider.user?.hasViewedIntro == true ||
            provider.user?.serviceId != 1 ||
            provider.user?.runnerStatus == RunnerState.SUSPENDED) {
          return const SizedBox.shrink();
        }
        _logImpression();
        return Padding(
          padding: widget.margin ?? EdgeInsets.zero,
          child: widget.showHeaderImage
              ? _buildWithHeader(context)
              : _buildWithoutHeader(context),
        );
      },
    );
  }

  Widget _buildWithHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.udaanBannerBorder, width: 1.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 1.sw,
            color: AppColors.n0,
            child: RemoteImageHandler(
              imageUrl: RemoteConfigAssets.udaanBannerHeaderImage,
              fit: BoxFit.contain,
              animate: false,
              loadingWidget: const SizedBox.shrink(),
              errorWidget: const SizedBox.shrink(),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildWithoutHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.udaanBannerFooterBg,
      ),
      child: _buildFooterContent(context),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: 1.sw,
      color: AppColors.udaanBannerFooterBg,
      child: _buildFooterContent(context),
    );
  }

  Widget _buildFooterContent(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.16,
                    color: AppColors.udaanBannerTitle,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.12,
                    color: AppColors.udaanBannerSubtitle,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          _AcceptButton(onTap: () => _openTierHome(context)),
        ],
      ),
    );
  }
}

/// Dark "Accept" pill — opens the Tiers webview on tap.
class _AcceptButton extends StatelessWidget {
  const _AcceptButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context,provider,_) {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.udaanBannerButton,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              provider.getMessage('View', "View"),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.n0,
              ),
            ),
          ),
        );
      }
    );
  }
}
