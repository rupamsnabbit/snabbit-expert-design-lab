import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';

/// Drawer-menu "Snabbit Udaan" row with a trailing "Play video" CTA.
///
/// Shown once the runner has already viewed the tier intro
/// ([UserProfile.hasViewedIntro]) — it is the post-intro counterpart to the
/// [SnabbitUdaanBanner] "Accept" card (which shows while the intro is unseen).
/// Visible only for tiering-enabled runners above the base tier ([Tier.BASE]
/// is excluded); collapses to a
/// [SizedBox.shrink] otherwise. Tapping **Play video** always opens the intro
/// flow ([WebviewRoutes.tiersIntro]) in the bifrost webview so the runner can
/// re-watch it.
class SnabbitUdaanPlayVideoRow extends StatelessWidget {
  const SnabbitUdaanPlayVideoRow({super.key});

  static const String _title = 'Snabbit Udaan';
  static const String _webViewTitle = 'Snabbit Udaan';

  void _openIntro(BuildContext context) {
    final url = buildWebviewUrl(WebviewRoutes.tiersIntro);
    if (!WebViewLauncher.isOpenableHttps(url)) return;
    WebViewLauncher.open(context, url: url, title: _webViewTitle);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (context, provider, _) {
        final user = provider.user;
        if (user == null ||
            provider.user?.hasViewedIntro != true ||
            provider.user?.serviceId != 1 ||
            provider.user?.runnerStatus == RunnerState.SUSPENDED ||
            user.tier == Tier.BASE) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: AppColors.udaanPlayVideoBg,
          padding: EdgeInsets.only(
            left: 24.w,
            right: 16.w,
            top: 12.h,
            bottom: 12.h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.udaanPlayVideoTitle,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              _PlayVideoButton(onTap: () => _openIntro(context)),
            ],
          ),
        );
      },
    );
  }
}

/// Dark "Play video" pill — opens the Tiers intro webview on tap.
class _PlayVideoButton extends StatelessWidget {
  const _PlayVideoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.udaanBannerButton,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          'Play video',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.n0,
          ),
        ),
      ),
    );
  }
}
