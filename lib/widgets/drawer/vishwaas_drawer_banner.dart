import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/remote_config/vishwaas_banner_remote_config.dart';
import 'package:snabbit_runner/utils/switch_rc_analytics.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Opens the vishwaas rate card inside the in-app webview. The destination
/// is now driven by [WebviewRoutes.payoutsVishwaasRateCard]; the Remote
/// Config `drawer.actionUrl` field is no longer consulted for this tap.
void _openVishwaasRateCard(BuildContext context) {
  // Legacy banner-clicked event — kept for back-compat with existing
  // dashboards that filter on banner_id.
  ClevertapSetup.logEvent(TrackingEvents.bannerClicked, {
    'banner_id': 'vishwaas_drawer',
    'placement': 'drawer',
  });
  final user = context.read<UserProfileProvider>().user;
  final props = <String, dynamic>{
    'banner_id': 'vishwaas_drawer',
    'placement': 'drawer',
    ...switchRcCommonProps(user),
  };
  MixpanelSetup.logEvent(
      TrackingEvents.switchRcProfilePageBannerCtaClick, props);
  Navigator.of(context).pushNamed(
    AppWebViewPage.routeName,
    arguments: WebViewArgs(
      url: buildWebviewUrl(WebviewRoutes.payoutsVishwaasRateCard),
      title: 'Rate card',
    ),
  );
}

/// Vishwaas image banner; uses [VishwaasBannerRemoteConfig.load] → [VishwaasBannerRemoteConfig.drawer].
class VishwaasDrawerBanner extends StatefulWidget {
  const VishwaasDrawerBanner({super.key});

  @override
  State<VishwaasDrawerBanner> createState() => _VishwaasDrawerBannerState();
}

class _VishwaasDrawerBannerState extends State<VishwaasDrawerBanner> {
  String? _lastImpressionKey;

  @override
  Widget build(BuildContext context) {
    final config = VishwaasBannerRemoteConfig.load()?.drawer;
    if (config == null) {
      return const SizedBox.shrink();
    }

    return Consumer<UserProfileProvider>(
      builder: (context, userProfile, _) {
        final url =
            config.resolveImageUrl(userProfile.user?.languagePreference);
        if (url == null || url.isEmpty) {
          return const SizedBox.shrink();
        }

        final impressionKey =
            '${userProfile.user?.languagePreference ?? ''}|$url';
        if (impressionKey != _lastImpressionKey) {
          _lastImpressionKey = impressionKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            // Legacy generic-impression event — kept for back-compat.
            ClevertapSetup.logEvent(TrackingEvents.genericBannerImpression, {
              'banner_id': 'vishwaas_drawer',
              'placement': 'drawer',
            });
            final props = <String, dynamic>{
              'banner_id': 'vishwaas_drawer',
              'placement': 'drawer',
              ...switchRcCommonProps(userProfile.user),
            };
            MixpanelSetup.logEvent(
                TrackingEvents.switchRcProfilePageBannerLoad, props);
          });
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 0.w),
          child: GestureDetector(
            onTap: () => _openVishwaasRateCard(context),
            child: SizedBox(
              width: double.infinity,
              child: RemoteImageHandler(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                errorWidget: const SizedBox.shrink(),
                loadingWidget: const Center(
                  child: CupertinoActivityIndicator(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
