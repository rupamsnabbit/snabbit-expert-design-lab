import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_page.dart';
import 'package:snabbit_runner/pages/bcp/bcp_degraded_page.dart';
import 'package:snabbit_runner/pages/getting_started/debug_menu.dart';
import 'package:snabbit_runner/pages/insurance_support.dart';
import 'package:snabbit_runner/pages/payout/early_payouts/early_payouts_screen.dart';
import 'package:snabbit_runner/pages/payout/payout_home.dart';
import 'package:snabbit_runner/pages/payout/transaction_history.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/pages/referral_home.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/file_ops.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/gamification_manager.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/notification_service.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_helper_utils.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/shorebird/shorebird_manager.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/merch_store_tracking.dart';
import 'package:snabbit_runner/utils/snabbit_seva_tracking.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/drawer/aadhaar_rekyc_drawer_card.dart';
import 'package:snabbit_runner/widgets/drawer/long_leave.dart';
import 'package:snabbit_runner/widgets/emergency_logout/emergency_logout_confirmation.dart';
import 'package:snabbit_runner/widgets/emergency_logout/emergency_logout_confirmation_v1.dart';
import 'package:snabbit_runner/widgets/emergency_logout/emergency_logout_unavailable.dart';
import 'package:snabbit_runner/widgets/expert_info.dart';
import 'package:snabbit_runner/providers/loan_provider.dart';
import 'package:snabbit_runner/services/loan_service.dart';
import 'package:snabbit_runner/widgets/loan/utils/loan_tracking.dart';

import 'package:snabbit_runner/services/language_channel.dart';
import 'package:snabbit_runner/widgets/tiering/snabbit_udaan_banner.dart';
import '../../providers/language_provider.dart';
import '../upload_documents/upload_pan_modal_sheet_v2.dart';
import 'identity_card.dart';

import 'package:snabbit_runner/pages/language_home.dart';

class DrawerMenu extends StatefulWidget {
  const DrawerMenu({super.key});

  @override
  State<DrawerMenu> createState() => _DrawerMenuState();
}

class _DrawerMenuState extends State<DrawerMenu> {
  late UserProfileProvider userProfileProvider;
  UserProfile? userProfile;
  late RunnerRtDataProvider runnerRtDataProvider;
  bool profilePicError = false;
  bool init = true;
  late LanguageProvider languageProvider;
  late LoanProvider loanProvider;
  String appVersion = '';
  final RemoteConfigService _remoteConfigService = RemoteConfigService.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      userProfileProvider = Provider.of<UserProfileProvider>(
        context,
        listen: true,
      );
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      runnerRtDataProvider = Provider.of<RunnerRtDataProvider>(
        context,
        listen: true,
      );
      loanProvider = Provider.of<LoanProvider>(context, listen: true);

      userProfile = userProfileProvider.user;
      _fetchAppVersion();
      _trackSidebarLoad();
    }
  }

  /// Builds the context properties shared by sidebar load + CTA click
  /// events. Both Mixpanel and CleverTap auto-attach the runner identity
  /// (set at login), so we don't repeat `runner_id` here.
  Map<String, dynamic> _sidebarContextProps() {
    final user = userProfileProvider.user;
    final periodLeaveAvailable = context
        .read<PeriodLeaveProvider>()
        .periodLeaveAvailable;
    final panNudge = user?.isPanVerified != true;
    final bankNudge = user?.bankVerified != true;
    final panAadharLinkNudge = user?.panAadharLinked != true;
    final listVisible = <String>[
      'identity_card',
      if (showEarnings) 'earnings',
      if (userProfileProvider.isRateCardV2Effective) 'rate_card',
      if (showEarlyPayout) 'early_payout',
      'refer_and_earn',
      if (showTransactionHistory) 'transaction_history',
      if (user?.showSeva ?? false) 'seva',
      if (user?.showMerchStore ?? false) 'merch_store',
      if (user?.isTieringEnabled ?? false) ...[
        'accident_insurance',
        'health_insurance',
      ] else
        'claim_insurance',
      'leaves',
      'language',
      if (user?.isLoanEligible == true) 'get_loan',
      if (panNudge) 'pan_nudge',
      if (bankNudge) 'bank_nudge',
      if (panAadharLinkNudge) 'pan_aadhar_link_nudge',
    ];
    return {
      'insurance_tier': user?.tier?.name,
      'current_month_rating': user?.currentMonthRating,
      'list_visible': listVisible,
      'period_leave_available': periodLeaveAvailable,
      'pan_nudges_visible': panNudge || bankNudge || panAadharLinkNudge,
      'pan_nudge_visible': panNudge,
      'bank_nudge_visible': bankNudge,
      'pan_aadhar_link_nudge_visible': panAadharLinkNudge,
    };
  }

  void _trackSidebarLoad() {
    final props = _sidebarContextProps();
    MixpanelSetup.logEvent(TrackingEvents.profileSectionSidebarLoad, props);
  }

  void _trackSidebarCtaClick(String ctaName) {
    final props = <String, dynamic>{
      ..._sidebarContextProps(),
      'cta_click': ctaName,
    };
    MixpanelSetup.logEvent(TrackingEvents.profileSectionSidebarCtaClick, props);
    ClevertapSetup.logEvent(
      TrackingEvents.profileSectionSidebarCtaClick,
      props,
    );
  }

  Future<void> _fetchAppVersion() async {
    appVersion = await ShorebirdManager.instance.getAppVersion();
    if (mounted) {
      setState(() {});
    }
  }

  void _openWebView({
    required String? url,
    required String title,
    bool fetchLocation = false,
    void Function()? onDrawerClick,
    void Function()? onPageLoaded,
    void Function(String reason)? onPageLoadFailed,
    void Function(String url, bool success)? onExternalUrlOpened,
  }) {
    if (url == null || url.isEmpty) return;
    if (!WebViewLauncher.isOpenableHttps(url)) {
      showSnackbar(context, 'Insecure URL, cannot be opened');
      return;
    }
    onDrawerClick?.call();
    WebViewLauncher.open(
      context,
      url: url,
      title: title,
      fetchLocation: fetchLocation,
      replace: true,
      onPageLoaded: onPageLoaded,
      onPageLoadFailed: onPageLoadFailed,
      onExternalUrlOpened: onExternalUrlOpened,
    );
  }

  bool get detailsMissing =>
      userProfileProvider.user?.isPanVerified != true ||
      userProfileProvider.user?.bankVerified != true;

  bool get showEarnings {
    return _remoteConfigService.getBool(
      RemoteConfigKeys.showEarnings,
      defaultValue: true,
    );
  }

  bool get showEarlyPayout {
    return userProfileProvider
            .user
            ?.runnerAppConfig
            ?.payoutConfig
            ?.showEarlyPayout ??
        false;
  }

  bool get showTransactionHistory {
    return userProfileProvider
            .user
            ?.runnerAppConfig
            ?.payoutConfig
            ?.showTransactionHistory ??
        false;
  }

  bool get showAadhaarRekyc => userProfileProvider.user?.isAadhaarRekyc == true;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 0.9.sw,
      backgroundColor: Colors.white,
      child: userProfile == null
          ? const Center(child: Text("User not found. Restart the app."))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      InkWell(
                        onTap: () {
                          // ECPO-930: tiering-enabled experts open the Tiers home
                          // page from the profile header; others keep the legacy
                          // Identity Card.
                          if (!(userProfileProvider.user?.tier?.isLegacyTier ?? false)) {
                            _trackSidebarCtaClick('tiers_home');
                            _openWebView(
                              url: buildWebviewUrl(WebviewRoutes.tiersHome),
                              title: 'Snabbit Udaan',
                            );
                          } else {
                            _trackSidebarCtaClick('identity_card');
                            Navigator.of(
                              context,
                            ).popAndPushNamed(IdentityCard.routeName);
                          }
                        },
                        child: const ExpertInfo(),
                      ),
                      SnabbitUdaanBanner(showHeaderImage: false,),
                      if (showAadhaarRekyc)
                        AadhaarRekycDrawerCard(
                          onTap: () {
                            _trackSidebarCtaClick('aadhaar_rekyc');
                            Navigator.of(context).popAndPushNamed(
                              AadhaarReverificationPage.routeName,
                            );
                          },
                        ),
                      // ListTile(
                      //   leading: SvgPicture.asset(
                      //     'assets/svgs/drawer/statusRank.svg',
                      //   ),
                      //   title: Text(
                      //     'Status & Rank',
                      //     style: Theme.of(context).textTheme.headlineSmall,
                      //   ),
                      //   onTap: () {},
                      // ),
                      if (showEarnings)
                        ListTile(
                          leading: SvgPicture.asset(
                            'assets/svgs/drawer/earning.svg',
                          ),
                          title: Text(
                            'Monthly Earnings',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('earnings');
                            // Route to v2 webview only once v2 has actually
                            // taken effect, not just when the runner opted
                            // in. Opted-but-not-yet-effective runners stay
                            // on the legacy native PayoutHome.
                            if (userProfileProvider.isRateCardV2Effective) {
                              _openWebView(
                                url: buildWebviewUrl(
                                  WebviewRoutes.payoutsMonthlySummary,
                                ),
                                title: 'Earnings',
                              );
                            } else {
                              Navigator.of(
                                context,
                              ).pushNamed(PayoutHome.routeName);
                            }
                          },
                        ),
                      if (userProfileProvider.isRateCardV2Effective)
                        ListTile(
                          leading: SvgPicture.asset(
                            'assets/svgs/rate_card_icon.svg',
                          ),
                          title: Text(
                            'Rate card',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('rate_card');
                            _openWebView(
                              url: buildWebviewUrl(
                                WebviewRoutes.payoutsRateCardEducation,
                              ),
                              title: 'Rate card',
                            );
                          },
                        ),
                      if (showEarlyPayout)
                        ListTile(
                          leading: SvgPicture.asset(AssetConstants.earlyPayout),
                          title: Text(
                            languageProvider.getMessage(
                                'early_payout', 'Early Payout'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('early_payout');
                            if (userProfileProvider.user?.isTieringEnabled ??
                                false) {
                              _openWebView(
                                url: buildWebviewUrl(
                                  WebviewRoutes.earlyPayoutHome,
                                ),
                                title: languageProvider.getMessage(
                                    'early_payout', 'Early Payout'),
                              );
                            } else {
                              Navigator.of(
                                context,
                              ).pushNamed(EarlyPayoutsScreen.routeName);
                            }
                          },
                        ),
                      ListTile(
                        leading: SvgPicture.asset(
                          'assets/svgs/drawer/refer_and_earn.svg',
                        ),
                        title: Text(
                          'Refer & earn',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        onTap: () {
                          _trackSidebarCtaClick('refer_and_earn');
                          // Gated behind an RC flag (default off) so we can
                          // roll the referrals webview forward/back without a
                          // release; fall back to native ReferralsHome.
                          if (RemoteConfigHelperUtils.isReferralsV2Enabled) {
                            _openWebView(
                              url: buildWebviewUrl(
                                WebviewRoutes.referralsHome,
                                query: {'entry_point': 'profile_menu'},
                              ),
                              title: 'Refer & earn',
                            );
                          } else {
                            Navigator.of(
                              context,
                            ).popAndPushNamed(ReferralsHome.routeName);
                          }
                        },
                      ),
                      const EmergencyLogoutWidget(),
                      if (showTransactionHistory)
                        ListTile(
                          leading: SvgPicture.asset(
                            AssetConstants.transactionHistory,
                          ),
                          title: Text(
                            'Transaction History',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('transaction_history');
                            Navigator.of(
                              context,
                            ).pushNamed(TransactionHistory.routeName);
                          },
                        ),
                      if (userProfileProvider.user?.showSeva ?? false)
                        ListTile(
                          leading: SizedBox(
                            width: 24.r,
                            height: 24.r,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/svgs/drawer/find_washroom.svg',
                                height: 20.r,
                                width: 20.r,
                              ),
                            ),
                          ),
                          title: Text(
                            languageProvider.getMessage('seva', 'Seva'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('seva');
                            _openWebView(
                              url: userProfileProvider.user?.sevaUrl,
                              title: languageProvider.getMessage(
                                'seva',
                                'Seva',
                              ),
                              fetchLocation: true,
                              onDrawerClick:
                                  SnabbitSevaTracking.trackDrawerClick,
                              onPageLoaded:
                                  SnabbitSevaTracking.trackWebPageLoaded,
                              onPageLoadFailed: (reason) =>
                                  SnabbitSevaTracking.trackWebPageLoadFailed(
                                    reason: reason,
                                  ),
                              onExternalUrlOpened: (url, success) =>
                                  SnabbitSevaTracking.trackExternalMapLinkClicked(
                                    url: url,
                                    success: success,
                                  ),
                            );
                          },
                        ),
                      if (userProfileProvider.user?.showMerchStore ?? false)
                        ListTile(
                          leading: SizedBox(
                            width: 24.r,
                            height: 24.r,
                            child: Center(
                              child: Icon(
                                Icons.storefront_outlined,
                                size: 20.r,
                              ),
                            ),
                          ),
                          title: Text(
                            languageProvider.getMessage(
                              'merch_store',
                              'Merch Store',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('merch_store');
                            _openWebView(
                              url: userProfileProvider.user?.merchStoreUrl,
                              title: languageProvider.getMessage(
                                'merch_store',
                                'Merch Store',
                              ),
                              fetchLocation: true,
                              onDrawerClick:
                                  MerchStoreTracking.trackDrawerClick,
                              onPageLoaded:
                                  MerchStoreTracking.trackWebPageLoaded,
                              onPageLoadFailed: (reason) =>
                                  MerchStoreTracking.trackWebPageLoadFailed(
                                    reason: reason,
                                  ),
                              onExternalUrlOpened: (url, success) =>
                                  MerchStoreTracking.trackExternalUrlOpened(
                                    url: url,
                                    success: success,
                                  ),
                            );
                          },
                        ),
                      if (userProfileProvider.user?.isTieringEnabled ?? false) ...[
                        ListTile(
                          leading: Image.asset(
                            AssetConstants.insuranceClaim,
                            height: 24.r,
                            width: 24.r,
                          ),
                          title: Text(
                            languageProvider.getMessage(
                                'accident_insurance', 'Accident Insurance'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('accident_insurance');
                            _openWebView(
                              url: buildWebviewUrl(
                                WebviewRoutes.insuranceAccident,
                              ),
                              title: languageProvider.getMessage(
                                  'accident_insurance', 'Accident Insurance'),
                            );
                          },
                        ),
                        ListTile(
                          leading: SvgPicture.asset(
                            AssetConstants.healthCard,
                            height: 24.r,
                            width: 24.r,
                          ),
                          title: Text(
                            languageProvider.getMessage(
                                'health_insurance', 'Health Insurance'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('health_insurance');
                            _openWebView(
                              url: buildWebviewUrl(
                                WebviewRoutes.insuranceHealth,
                              ),
                              title: languageProvider.getMessage(
                                  'health_insurance', 'Health Insurance'),
                            );
                          },
                        ),
                      ] else
                        ListTile(
                          leading: Image.asset(
                            AssetConstants.insuranceClaim,
                            height: 24.r,
                            width: 24.r,
                          ),
                          title: Text(
                            'Claim Insurance',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('claim_insurance');
                            Navigator.pushNamed(
                              context,
                              InsuranceSupport.routeName,
                            );
                          },
                        ),
                      ListTile(
                        leading: SvgPicture.asset(
                          'assets/svgs/drawer/leaves.svg',
                        ),
                        title: Text(
                          'Leaves',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        onTap: () {
                          _trackSidebarCtaClick('leaves');
                          Navigator.of(
                            context,
                          ).popAndPushNamed(LongLeaveApplication.routeName);
                        },
                      ),
                      ListTile(
                        leading: SvgPicture.asset(
                          'assets/svgs/drawer/language.svg',
                        ),
                        title: Text(
                          'Language',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        onTap: () {
                          _trackSidebarCtaClick('language');
                          Navigator.of(context).pop();
                          // The native CMP screen isn't Shorebird-patchable, so
                          // gate it behind an RC kill-switch (default off) and
                          // fall back to the Flutter LanguageHome — the rollback
                          // + staged-rollout lever.
                          final cmpEnabled = _remoteConfigService.getBool(
                            RemoteConfigKeys.cmpLanguageScreenEnabled,
                          );
                          if (!cmpEnabled) {
                            Navigator.of(
                              context,
                            ).pushNamed(LanguageHome.routeName);
                            return;
                          }
                          final navigator = Navigator.of(context);
                          LanguageChannel.openLanguageScreen(
                            currentLanguage:
                                userProfileProvider.user?.languagePreference,
                            title: languageProvider.getMessage(
                              'choose_preferred_language',
                              'Choose preferred language',
                            ),
                            confirmLabel: languageProvider.getMessage(
                              'confirm',
                              'Confirm',
                            ),
                          ).then((opened) {
                            // KMP not ready / no native host — fall back to the
                            // Flutter LanguageHome (the bridge logs the failure).
                            if (!opened) {
                              navigator.pushNamed(LanguageHome.routeName);
                            }
                          });
                        },
                      ),
                      if (userProfileProvider.user?.isLoanEligible == true)
                        ListTile(
                          leading: Image.asset(
                            AssetConstants.loanMoneyBagIcon,
                            height: 24.r,
                            width: 24.r,
                          ),
                          title: Wrap(
                            children: [
                              Text(
                                languageProvider.getMessage(
                                  'loans',
                                  'Loans',
                                ),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.y20,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  "NEW",
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontFamily: 'MetropolisBlack',
                                        fontWeight: FontWeight.w600,
                                        height: 1.0,
                                        letterSpacing: -0.24,
                                        color: AppColors.y50,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            _trackSidebarCtaClick('get_loan');
                            try {
                              LoanTracking.trackLoanBannerClick(
                                source: 'drawer',
                              );
                            } catch (_) {}
                            if (userProfileProvider.user?.isTieringEnabled ??
                                false) {
                              _openWebView(
                                url: buildWebviewUrl(WebviewRoutes.loanHome),
                                title: 'Loans',
                              );
                            } else {
                              Navigator.pop(context);
                              LoanService.handleLoanAction(
                                context,
                                loanProvider,
                                'drawer',
                              );
                            }
                          },
                        ),
                      // ListTile(
                      //   leading: SvgPicture.asset(
                      //     'assets/svgs/drawer/training.svg',
                      //   ),
                      //   title: Text(
                      //     'Training',
                      //     style: Theme.of(context).textTheme.headlineSmall,
                      //   ),
                      //   onTap: () {},
                      // ),
                      // ListTile(
                      //   leading: SvgPicture.asset(
                      //     'assets/svgs/drawer/helpCenter.svg',
                      //   ),
                      //   title: Text(
                      //     'Help Center',
                      //     style: Theme.of(context).textTheme.headlineSmall,
                      //   ),
                      //   onTap: () {},
                      // ),
                      if (GlobalState().appConfig?.showSilentNotification ==
                          true)
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_off,
                            color: AppColors.n90,
                          ),
                          title: Text(
                            'Silent notifications',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () async {
                            await FileStorage.writeState('stopped');
                            await NotificationService.instance.cancelAll();
                            await GlobalState().audioPlayer.setReleaseMode(
                              ReleaseMode.stop,
                            );
                            await GlobalState().audioPlayer.stop();

                            await ClevertapSetup.logEvent(
                              TrackingEvents.silentNotificationFeatureUsed,
                              {"drawer": "Silent notification feature used"},
                            );
                          },
                        ),
                      // Debug-only: expose Debug Menu to logged-in runners.
                      // Stripped from release builds so production runners
                      // never see this.
                      if (kDebugMode)
                        ListTile(
                          leading: const Icon(
                            Icons.bug_report,
                            color: AppColors.n90,
                          ),
                          title: Text(
                            'Debug Menu',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(
                              context,
                            ).pushNamed(DebugMenu.routeName);
                          },
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (detailsMissing)
                              Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      AssetConstants.fpWarningPng,
                                      width: 22.w,
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      languageProvider.getMessage(
                                        'details_missing',
                                        'Details Missing',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(color: AppColors.r50),
                                    ),
                                  ],
                                ),
                              ),
                            if (userProfileProvider.user?.isPanVerified != true)
                              SizedBox(
                                width: 1.sw,
                                child: OutlinedButton(
                                  onPressed: userProfileProvider.loading == true
                                      ? null
                                      : () {
                                          _trackSidebarCtaClick('pan_nudge');
                                          Navigator.of(context).pop();
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            constraints: BoxConstraints(
                                              maxHeight: 0.7.sh,
                                            ),
                                            builder: (ctx) {
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: MediaQuery.of(
                                                    ctx,
                                                  ).viewInsets.bottom,
                                                ),
                                                child:
                                                    const UploadPanModalSheetV2(),
                                              );
                                            },
                                          );
                                        },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppColors.r40,
                                    ),
                                    foregroundColor: AppColors.r50,
                                    backgroundColor: AppColors.r0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        flex: 8,
                                        child: FittedBox(
                                          child:
                                              userProfileProvider.loading ==
                                                  true
                                              ? const CupertinoActivityIndicator()
                                              : Text(
                                                  languageProvider.getMessage(
                                                    'drawer_pan_upload_benefit',
                                                    'PAN Card helps reduce Income Tax',
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Flexible(
                                        flex: 2,
                                        child: Icon(
                                          Icons.chevron_right_rounded,
                                          size: 16.r,
                                          color: AppColors.r50,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            SizedBox(height: 12.h),
                            if (userProfileProvider.user?.bankVerified != true)
                              SizedBox(
                                width: 1.sw,
                                child: OutlinedButton(
                                  onPressed: userProfileProvider.loading == true
                                      ? null
                                      : () {
                                          _trackSidebarCtaClick('bank_nudge');
                                          Navigator.of(context).pop();
                                          Navigator.pushNamed(
                                            context,
                                            '/add_bank_or_upi_details',
                                          );
                                        },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppColors.r40,
                                    ),
                                    foregroundColor: AppColors.r50,
                                    backgroundColor: AppColors.r0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        flex: 8,
                                        child: FittedBox(
                                          child:
                                              userProfileProvider.loading ==
                                                  true
                                              ? const CupertinoActivityIndicator()
                                              : Text(
                                                  languageProvider.getMessage(
                                                    'add_bank_upi_details',
                                                    'Add UPI / bank account to enable payout',
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Flexible(
                                        flex: 2,
                                        child: Icon(
                                          Icons.chevron_right_rounded,
                                          size: 16.r,
                                          color: AppColors.r50,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (userProfileProvider.user?.panAadharLinked !=
                                true) ...[
                              if (!detailsMissing)
                                Padding(
                                  padding: EdgeInsets.only(top: 12.h),
                                  child: Row(
                                    children: [
                                      Image.asset(
                                        AssetConstants.fpWarningPng,
                                        width: 22.w,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        languageProvider.getMessage(
                                          'link_missing',
                                          'Link missing',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(color: AppColors.r50),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(height: 12.h),
                              SizedBox(
                                width: 1.sw,
                                child: OutlinedButton(
                                  onPressed: null,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppColors.r40,
                                    ),
                                    foregroundColor: AppColors.r50,
                                    backgroundColor: AppColors.r0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        flex: 8,
                                        child: FittedBox(
                                          child: Text(
                                            languageProvider.getMessage(
                                              'drawer_link_pan_aadhaar_benefit',
                                              'Link your PAN card with Aadhar to reduce Income Tax',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: AppColors.r50,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          'App version $appVersion+${snapshot.data!.buildNumber}',
                        );
                      } else {
                        return const Text('Loading version...');
                      }
                    },
                  ),
                ),
                if (GlobalState().currentEnv != prodEnv)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.r),
                    child: Text("Endpoint - ${GlobalState().remoteUrl}"),
                  ),
                SizedBox(height: 20.h),
              ],
            ),
    );
  }
}

class EmergencyLogoutWidget extends StatefulWidget {
  const EmergencyLogoutWidget({super.key});

  @override
  State<EmergencyLogoutWidget> createState() => _EmergencyLogoutWidgetState();
}

class _EmergencyLogoutWidgetState extends State<EmergencyLogoutWidget> {
  bool _init = true;
  late LanguageProvider _languageProvider;

  @override
  void didChangeDependencies() {
    if (_init) {
      _init = false;
      _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final rt = context.watch<RunnerRtDataProvider>();
    final isV2 = context.watch<UserProfileProvider>().optedForNewRateCard;

    if (!rt.emergencyLogoutAvailabilityReady) {
      return ListTile(
        leading: SvgPicture.asset(
          AssetConstants.emergencyBeacon,
          width: 25.r,
          colorFilter: const ColorFilter.mode(AppColors.n30, BlendMode.srcIn),
        ),
        title: Text(
          _languageProvider.getMessage('emergency_logout', 'Emergency logout'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.n30),
        ),
      );
    }

    final data = rt.emergencyLogoutAvailability;
    if (data == null) {
      if (rt.emergencyLogoutDegradedFromBcp) {
        return _buildBcpDegradedTile(context);
      }
      return const SizedBox.shrink();
    }

    final emergencyLogoutsTaken = data['emergency_logouts_taken'] ?? 0;
    final maxEmergencyLogouts = data['max_emergency_logouts'] ?? 0;
    final isLogoutAvailable = emergencyLogoutsTaken < maxEmergencyLogouts;
    final remaining = maxEmergencyLogouts - emergencyLogoutsTaken;

    if (!isV2) {
      return ListTile(
        leading: SvgPicture.asset(AssetConstants.emergencyBeacon, width: 25.r),
        title: Text(
          _languageProvider.getMessage('emergency_logout', 'Emergency logout'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        onTap: () {
          Navigator.of(context).pop();
          if (isLogoutAvailable) {
            showEmergencyLogoutConfirmationV1(
              context,
              emergencyLogoutsAvailable: remaining,
            );
          } else {
            showEmergencyLogoutUnavailable(context);
          }
        },
      );
    }

    return ListTile(
      enabled: isLogoutAvailable,
      leading: SvgPicture.asset(
        AssetConstants.emergencyBeacon,
        width: 25.r,
        colorFilter: isLogoutAvailable
            ? null
            : const ColorFilter.mode(AppColors.n30, BlendMode.srcIn),
      ),
      title: Text(
        _languageProvider.getMessage('emergency_logout', 'Emergency logout'),
        style: isLogoutAvailable
            ? Theme.of(context).textTheme.headlineSmall
            : Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppColors.n30),
      ),
      onTap: isLogoutAvailable
          ? () {
              Navigator.of(context).pop();
              final sheetWarnings = GamificationManager.instance
                  .parseSheetWarnings(
                    data['sheet_warnings'] ?? data['sheetWarnings'],
                  );
              final earningLoss = data['earning_loss'];
              showEmergencyLogoutConfirmation(
                context,
                emergencyLogoutsAvailable: remaining,
                sheetWarnings: sheetWarnings,
                earningLoss: earningLoss is num ? earningLoss : null,
              );
            }
          : null,
    );
  }

  Widget _buildBcpDegradedTile(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(AssetConstants.emergencyBeacon, width: 25.r),
      title: Text(
        _languageProvider.getMessage('emergency_logout', 'Emergency logout'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: BcpDegradedPage.routeName),
            builder: (_) => const BcpDegradedPage(
              backDisabled: false,
              source: BcpDegradedPage.sourceManual,
            ),
          ),
        );
      },
    );
  }
}
