import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/banner_config.dart';
import 'package:snabbit_runner/providers/banner_config_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class GenericBannerWidget extends StatefulWidget {
  final BannerPlacement placement;
  final String? position;

  const GenericBannerWidget({
    super.key,
    required this.placement,
    this.position,
  });

  @override
  State<GenericBannerWidget> createState() => _GenericBannerWidgetState();
}

class _GenericBannerWidgetState extends State<GenericBannerWidget> {
  String? _lastImpressionBannerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bannerProvider = context.read<BannerConfigProvider>();
      if (!bannerProvider.isLoaded) {
        bannerProvider.loadBanners();
      }
    });
  }

  /// Safely open banner action URL, allowing only http/https schemes.
  static Future<void> _openBannerUrl(BannerConfig banner) async {
    final url = banner.actionUrl;
    if (url == null) return;

    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'http' && uri.scheme != 'https') return;

      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (launched) {
        ClevertapSetup.logEvent(TrackingEvents.bannerUrlLaunched, {
          'banner_id': banner.id,
          'placement': banner.placement?.jsonValue,
          'position': banner.position,
          'action_url': url,
        });
      }
    } catch (e) {
      ClevertapSetup.logEvent(TrackingEvents.bannerUrlLaunchFailed, {
        'banner_id': banner.id,
        'placement': banner.placement?.jsonValue,
        'position': banner.position,
        'action_url': url,
        'error': e.toString(),
      });
    }
  }

  void _logImpressionEvent(BannerConfig banner) {
    _lastImpressionBannerId = banner.id;
    ClevertapSetup.logEvent(TrackingEvents.genericBannerImpression, {
      'banner_id': banner.id,
      'placement': banner.placement?.jsonValue,
      'position': banner.position,
      'has_action_url': banner.actionUrl != null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bannerProvider = context.watch<BannerConfigProvider>();

    if (!bannerProvider.isLoaded) return const SizedBox.shrink();

    final banner = bannerProvider.getBannerForPlacement(widget.placement);

    if (banner == null) return const SizedBox.shrink();

    // If position filter is set, only show when it matches
    if (widget.position != null && banner.position != widget.position) {
      return const SizedBox.shrink();
    }

    if (banner.id != _lastImpressionBannerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logImpressionEvent(banner);
        }
      });
    }

    final double maxHeight = 115.h;
    final double bannerHeight = min(banner.height, maxHeight);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: GestureDetector(
        onTap: () {
          ClevertapSetup.logEvent(TrackingEvents.bannerClicked, {
            'banner_id': banner.id,
            'placement': banner.placement?.jsonValue,
            'position': banner.position,
            'has_action_url': banner.actionUrl != null,
          });
          if (banner.actionUrl != null) {
            _openBannerUrl(banner);
          }
        },
        child: SizedBox(
          width: double.infinity,
          height: bannerHeight,
          child: RemoteImageHandler(
            imageUrl: banner.imageUrl.cdn,
            fit: BoxFit.contain,
            height: bannerHeight,
            width: double.infinity,
            errorWidget: const SizedBox.shrink(),
            loadingWidget: const Center(
              child: CupertinoActivityIndicator(),
            ),
          ),
        ),
      ),
    );
  }
}
