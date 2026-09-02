import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Lunch-slots strip docked flush above PartnerHome's bottom edge.
/// Server-driven via the top-level `show_lunch_selection` `current_state` flag
/// (`RunnerRtDataProvider.showLunchSelection`): edge-to-edge info wash,
/// title on the left, Select CTA on the right. The WHOLE strip is tappable,
/// not just the CTA — both routes fire the same [onUpdate]. Stateless — copy
/// and the tap are hoisted to [LunchSlotsBannerSlot].
class LunchSlotsBanner extends StatelessWidget {
  const LunchSlotsBanner({
    super.key,
    required this.title,
    required this.ctaLabel,
    required this.onUpdate,
  });

  final String title;
  final String ctaLabel;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    // liveRegion announces the strip when the server flips it on.
    return Semantics(
      liveRegion: true,
      // Material + InkWell (not a bare GestureDetector) so the whole-strip tap
      // ripples. The wash moves onto the Material so the splash paints ON the
      // banner rather than being hidden behind an opaque Container colour.
      child: Material(
        color: AppColors.bgInfo,
        child: InkWell(
          onTap: onUpdate,
          child: Container(
            width: 1.sw,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                // Leading illustration — hosted on the CDN so it can change without
                // a release. Falls back to the bundled lunch art (already in the
                // asset bundle) so the strip still reads while the remote object is
                // missing or the device is offline.
                SizedBox(
                  width: 32.r,
                  height: 32.r,
                  child: RemoteImageHandler(
                    imageUrl: RemoteConfigAssets.lunchBanner,
                    fit: BoxFit.contain,
                    errorWidget: Image.asset(
                      AssetConstants.lunchTime,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.n90,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: onUpdate,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(0, 32.h),
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(ctaLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Self-contained dock for the banner on PartnerHome — reads the flag and
/// copy from the providers and owns the Select tap, so the page carries no
/// banner logic (same self-contained idiom as the page's `PendingPayout`)
/// and the visibility branch + tap wiring are widget-testable. Renders
/// nothing while the flag is off.
///
/// Stateless: the `lunch_banner_shown` impression is owned by
/// [RunnerRtDataProvider.showLunchSelection]'s setter, not by this widget. A
/// widget-held guard would reset on dispose and re-count every time the runner
/// returned to the home; the provider is app-lifetime, so the impression is
/// counted once per server flip.
class LunchSlotsBannerSlot extends StatelessWidget {
  const LunchSlotsBannerSlot({super.key});

  @override
  Widget build(BuildContext context) {
    // select: only the flag flip rebuilds this slot, not every provider tick.
    final visible = context.select<RunnerRtDataProvider, bool>(
      (p) => p.showLunchSelection,
    );
    if (!visible) return const SizedBox.shrink();
    final language = context.watch<LanguageProvider>();
    // Flat catalog keys (not the dotted `home.*` shape) — the live server
    // catalog is flat-keyed; the English strings here are the fallbacks.
    return LunchSlotsBanner(
      title: language.getMessage(
        'lunch_banner_title',
        'Book your lunch slot for next week',
      ),
      ctaLabel: language.getMessage('lunch_banner_cta', 'Select'),
      onUpdate: () => _openLunchSlotsWebview(context),
    );
  }

  /// "Select" — opens the lunch-slot page, path resolved from the
  /// `expert_lunch_webview_path` RC key. The `lunch_banner_update` event value
  /// predates the copy change and stays put so the existing dashboard keeps
  /// working.
  void _openLunchSlotsWebview(BuildContext context) {
    final language = Provider.of<LanguageProvider>(context, listen: false);
    final url = buildWebviewUrl(WebviewRoutes.lunchSlotsPath);
    // Logged BEFORE the URL gate: the runner tapped either way, so gating the
    // log here would under-count the CTA on a bad RC path.
    unawaited(
      ClevertapSetup.logEvent(TrackingEvents.homeScreenCtaClick, {
        'cta_text': 'lunch_banner_update',
      }),
    );
    if (!WebViewLauncher.isOpenableHttps(url)) {
      // A misconfigured `expert_lunch_webview_path` would otherwise make the CTA
      // a silent no-op; leave a breadcrumb so the RC mistake is diagnosable.
      unawaited(
        MonitoringServiceHelper.logError('lunch_banner_url_not_openable', {
          'url': url,
        }),
      );
      return;
    }
    WebViewLauncher.open(
      context,
      url: url,
      // Localized like the banner copy, off the same flat catalog.
      title: language.getMessage('lunch_slots_webview_title', 'Lunch Slots'),
      // Slot selection changes `show_lunch_selection`; refresh on close so the
      // banner reflects the new state instead of waiting for the next poll.
      refreshCurrentStateOnClose: true,
    );
  }
}
