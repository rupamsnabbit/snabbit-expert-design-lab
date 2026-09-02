import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/tiering/tier_nudge_list_item.dart';

/// Job/coin tiering nudge — a pink gradient row with the job badge, a localized
/// title (e.g. "Do a perfect job") and a trailing white pill showing the
/// [coinsCount] with the Snabbit-coin icon. Opens [route] in the bifrost
/// webview on tap, when one is supplied (no current call site does — see the
/// ECPO-1022 note below).
///
/// Only [titleKey], [coinsCount] and [route] vary per usage; the leading/coin
/// icons, gradient, borderless 12px container and 8×12 padding are fixed (from
/// [RemoteConfigAssets] / the design). Built on top of [TierNudgeListItem] —
/// passes the coin pill as its `trailing`.
///
/// ECPO-1022: [coinsCount] is null when the backend sent no `coin_amount` — the
/// pill is then omitted (no hard-coded default reward). An empty trailing is
/// passed rather than letting [TierNudgeListItem] fall back to its default
/// chevron, because the job nudge is non-navigable.
class JobTieringNudge extends StatelessWidget {
  const JobTieringNudge({
    super.key,
    required this.titleKey,
    required this.coinsCount,
    this.route,
    this.titleFallback = '',
    this.additionalData = const {},
    this.webViewTitle = '',
    this.onTap,
  });

  /// Localization key for the nudge title, e.g. `"do_a_perfect_job"`.
  final String titleKey;

  /// Coins shown in the trailing pill. Null hides the pill entirely (the
  /// backend sent no `coin_amount`) — ECPO-1022: no default is invented.
  final int? coinsCount;

  /// [WebviewRoutes] path opened in the bifrost webview on tap. Null (or empty)
  /// renders the nudge non-tappable.
  final String? route;

  /// English fallback used when [titleKey] is missing from the active locale.
  final String titleFallback;

  /// Values substituted into the resolved title's `{{placeholder}}` tokens.
  final Map<String, dynamic> additionalData;

  /// Title shown in the webview app bar once opened.
  final String webViewTitle;

  /// Analytics hook fired when the nudge is tapped, before the webview opens.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TierNudgeListItem(
      titleKey: titleKey,
      titleFallback: titleFallback,
      additionalData: additionalData,
      onTap: onTap,
      leadingImage: RemoteConfigAssets.tierJob,
      leadingSize: 24,
      route: route,
      webViewTitle: webViewTitle,
      hideBorder: true,
      // Discarded while hideBorder is true; TierNudgeListItem requires a value.
      borderColor: Colors.transparent,
      borderRadius: 12,
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      titleColor: AppColors.tierNudgeText,
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [AppColors.tierNudgePinkStart, AppColors.tierNudgePinkEnd],
      ),
      // Show the coin pill only when the backend sent a reward; an empty
      // (non-null) trailing suppresses TierNudgeListItem's default chevron —
      // the job nudge is non-navigable, so a chevron would mislead.
      trailing: coinsCount == null
          ? const SizedBox.shrink()
          : _CoinCountChip(coinsCount: coinsCount!),
    );
  }
}

/// White pill: the Snabbit-coin icon + the coin count.
class _CoinCountChip extends StatelessWidget {
  const _CoinCountChip({required this.coinsCount});

  final int coinsCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 4.h, 10.w, 4.h),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20.r,
            height: 20.r,
            child: RemoteImageHandler(
              imageUrl: RemoteConfigAssets.tierCoin,
              fit: BoxFit.contain,
              animate: false,
              loadingWidget: const SizedBox.shrink(),
              errorWidget: const SizedBox.shrink(),
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            '$coinsCount',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.tierNudgeText,
            ),
          ),
        ],
      ),
    );
  }
}
