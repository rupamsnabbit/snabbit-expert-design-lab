import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/remote_config/vishwaas_banner_remote_config.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/switch_rc_analytics.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

const _kShowCountPrefsKey = 'vishwaas_provisional_rate_card_bs_show_count_v1';
const _kDefaultMaxShowCount = 3;

/// Frequency-capped bottom sheet — max shows per install controlled by
/// Remote Config [RemoteConfigKeys.vishwaasProvisionalSheetMaxShowCount]
/// (defaults to [_kDefaultMaxShowCount]).
/// Uses [VishwaasBannerRemoteConfig.load] →
/// [VishwaasBannerRemoteConfig.provisionalAttendanceSheet] (or flat legacy / shared).
///
/// [forDebugPreview]: if true, skip the show-count guard and do not increment
/// the counter (for manual / test entry points).
Future<void> showVishwaasProvisionalRateCardIfNeeded(
  BuildContext context, {
  bool forDebugPreview = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final shownCount = prefs.getInt(_kShowCountPrefsKey) ?? 0;
  final maxShowCount = RemoteConfigService.instance.getInt(
    RemoteConfigKeys.vishwaasProvisionalSheetMaxShowCount,
    defaultValue: _kDefaultMaxShowCount,
  );
  if (!forDebugPreview && shownCount >= maxShowCount) {
    return;
  }
  if (!context.mounted) return;

  final config = VishwaasBannerRemoteConfig.load()?.provisionalAttendanceSheet;
  if (config == null) return;

  final user = context.read<UserProfileProvider>().user;
  final imageUrl = config.resolveImageUrl(user?.languagePreference);
  if (imageUrl == null || imageUrl.isEmpty || !context.mounted) return;

  // Legacy generic-impression event — kept for back-compat.
  ClevertapSetup.logEvent(TrackingEvents.genericBannerImpression, {
    'banner_id': 'vishwaas_provisional_rate_card',
    'placement': 'provisional_attendance_bottom_sheet',
  });

  final maxH = 0.78 * MediaQuery.sizeOf(context).height;

  var sheetLoadTracked = false;
  // Captured by the proceed/dismiss handlers below; read after the
  // modal closes to fire a single switch_rc_bs_banner_click event with
  // cta_type=proceed or dismiss.
  String bsCtaType = 'dismiss';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    // Avoid an extra top inset; keep only bottom padding for the home indicator.
    useSafeArea: false,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (sheetContext) {
      if (!sheetLoadTracked) {
        sheetLoadTracked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!sheetContext.mounted) return;
          final loadProps = <String, dynamic>{
            'banner_id': 'vishwaas_provisional_rate_card',
            'placement': 'provisional_attendance_bottom_sheet',
            ...switchRcCommonProps(user),
          };
          MixpanelSetup.logEvent(
              TrackingEvents.switchRcBsBannerLoad, loadProps);
        });
      }
      final safeBottom = MediaQuery.viewPaddingOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: safeBottom),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(0.r)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  SingleChildScrollView(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          bsCtaType = 'proceed';
                          _onImageTap(sheetContext);
                        },
                        child: RemoteImageHandler(
                          animate: false,
                          imageUrl: imageUrl,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorWidget: const SizedBox.shrink(),
                          loadingWidget: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32.h),
                            child: const Center(
                              child: CupertinoActivityIndicator(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12.h,
                    right: 12.w,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      elevation: 1,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(6.r),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 18.r,
                            color: AppColors.n70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  // Single unified click event with cta_type discriminating proceed
  // (image tap) vs dismiss (X / swipe / back).
  final clickProps = <String, dynamic>{
    'banner_id': 'vishwaas_provisional_rate_card',
    'placement': 'provisional_attendance_bottom_sheet',
    'cta_type': bsCtaType,
    ...switchRcCommonProps(user),
  };
  MixpanelSetup.logEvent(TrackingEvents.switchRcBsBannerClick, clickProps);

  if (context.mounted && !forDebugPreview) {
    await prefs.setInt(_kShowCountPrefsKey, shownCount + 1);
  }
}

/// Opens the Vishwaas rate card inside the in-app webview. Same pattern
/// as the drawer Vishwaas banner — destination is driven by
/// [WebviewRoutes.payoutsVishwaasRateCard]; the Remote Config
/// `provisional_attendance_sheet.action_url` field is no longer
/// consulted.
void _onImageTap(BuildContext context) {
  // Legacy banner-clicked event — kept for back-compat with existing
  // dashboards. The spec'd switch_rc_bs_banner_click event fires once
  // from the parent after the modal closes (with cta_type=proceed).
  ClevertapSetup.logEvent(TrackingEvents.bannerClicked, {
    'banner_id': 'vishwaas_provisional_rate_card',
    'placement': 'provisional_attendance_bottom_sheet',
  });
  if (!context.mounted) return;
  // popAndPushNamed dismisses this bottom sheet first, then pushes
  // the webview onto the underlying navigator — single screen visible
  // at a time, no stacking.
  Navigator.of(context).popAndPushNamed(
    AppWebViewPage.routeName,
    arguments: WebViewArgs(
      url: buildWebviewUrl(WebviewRoutes.payoutsVishwaasRateCard),
      title: 'Rate card',
    ),
  );
}
