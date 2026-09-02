import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/referrals/services/referral_http.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class ReferralEarnBanner extends StatefulWidget {
  const ReferralEarnBanner({super.key});

  @override
  State<ReferralEarnBanner> createState() => _ReferralEarnBannerState();
}

class _ReferralEarnBannerState extends State<ReferralEarnBanner> {
  int? _amount;
  bool _loading = true;
  late LanguageProvider languageProvider;
  bool init = true;

  @override
  void initState() {
    super.initState();
    _loadAmount();
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    }
    super.didChangeDependencies();
  }

  Future<void> _loadAmount() async {
    final amount = await ReferralHttp.referralBannerAmount();
    if (!mounted) return;
    setState(() {
      _amount = amount;
      _loading = false;
    });
  }

  void _openReferralsWebView() {
    final url = buildWebviewUrl(
      WebviewRoutes.referralsHome,
      query: {'entry_point': 'home_banner'},
    );
    if (!WebViewLauncher.isOpenableHttps(url)) return;
    final title = languageProvider.getMessage('refer_and_earn', 'Refer & earn');
    WebViewLauncher.open(context, url: url, title: title);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _amount == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: GestureDetector(
        onTap: _openReferralsWebView,
        child: Container(
          width: double.infinity,
          height: 150.h,
          decoration: BoxDecoration(
            color: AppColors.referralBannerBg,
            borderRadius: BorderRadius.circular(12.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: RemoteImageHandler(
                  imageUrl: RemoteConfigAssets.referAndEarnV2Banner,
                  fit: BoxFit.cover,
                  repeat: false,
                  animate: false,
                  loadingWidget: const SizedBox.shrink(),
                  errorWidget: const SizedBox.shrink(),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getMessage(
                              'refer_and_earn',
                              'Refer and earn',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.sp,
                              height: 24 / 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.referralBannerTitle,
                            ),
                          ),
                          Text(
                            formatIndianCurrency(_amount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 32.sp,
                              height: 40 / 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.referralBannerAmount,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.referralBannerCta,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        languageProvider.getMessage('refer_now', 'Refer now'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          height: 16 / 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.n0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
