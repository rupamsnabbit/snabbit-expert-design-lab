import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

/// Default webview base URL used as the fallback when Remote Config
/// hasn't activated yet (first launch / offline cold start). Same value
/// as the `PROD` entry in [webviewEnvUrls].
const String defaultWebviewBaseUrl = 'https://expert-webapp.snabbit.com/';

/// Named webview environments offered by the debug menu's "Select Webview
/// Environment" picker — keys are the labels, values the base URLs.
///
/// Amplify branch-preview URLs (e.g. `PAYOUTS`) can rotate per branch;
/// use the picker's `CUSTOM` option when one goes stale.
const Map<String, String> webviewEnvUrls = {
  'PROD': defaultWebviewBaseUrl,
  'STAGING': 'https://app-webview.stg.snabbit.com/',
  'PAYOUTS':
      'https://feat-payouts-navigation-bridge-v2.dlczjayuscy5t.amplifyapp.com/',
};

/// Builds a full webview URL by joining a base URL with a path from
/// [WebviewRoutes]. Base URL priority:
///   1. Debug webview override ([GlobalState.debugWebviewBaseUrl]) — honoured
///      in [kDebugMode] only, so a stale pref can't affect a release build.
///   2. Remote Config (`RemoteConfigKeys.webviewBaseUrl`).
///   3. [defaultWebviewBaseUrl].
/// Ensures exactly one `/` between base and path regardless of
/// trailing-slash state on either.
String buildWebviewUrl(String path, {Map<String, String>? query}) {
  final debugOverride = GlobalState().debugWebviewBaseUrl;

  final String base;
  if (kDebugMode && debugOverride != null && debugOverride.isNotEmpty) {
    base = debugOverride;
  } else {
    base = RemoteConfigService.instance.getString(
      RemoteConfigKeys.webviewBaseUrl,
      defaultValue: defaultWebviewBaseUrl,
    );
  }

  final normalisedBase = base.endsWith('/') ? base : '$base/';
  final normalisedPath = path.startsWith('/') ? path.substring(1) : path;
  final url = '$normalisedBase$normalisedPath';

  if (query == null || query.isEmpty) return url;

  final queryString = query.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  final separator = normalisedPath.contains('?') ? '&' : '?';
  return '$url$separator$queryString';
}

/// Folds a Remote-Config-supplied lunch path down to a usable one: a blank
/// or whitespace-only value falls back to [WebviewRoutes.lunchSlots], so an
/// empty key in Firebase can't send the banner to the bare base URL. Split
/// out of [WebviewRoutes.lunchSlotsPath] (which reads the RC singleton) so
/// both branches are unit-testable.
@visibleForTesting
String resolveLunchSlotsPath(String configured) {
  final trimmed = configured.trim();
  return trimmed.isEmpty ? WebviewRoutes.lunchSlots : trimmed;
}

/// Paths appended to the webview base URL (see
/// `RemoteConfigKeys.webviewBaseUrl`) to reach specific features inside
/// the runner web app.
///
/// Paths have no leading slash — the base URL is expected to end with
/// `/`. Kept as a stable contract on the Flutter side so pushes /
/// deeplinks can reference them by name.
///
/// TODO(webview-routes): migrate to Remote Config once routes need to be
/// rolled forward/back without an app release.
class WebviewRoutes {
  WebviewRoutes._();

  /// Payouts — Monthly earnings summary entry point from the drawer.
  static const String payoutsMonthlySummary = 'v1/payouts/monthly-summary';

  /// Payouts — Daily payouts list.
  static const String payoutsDaily = 'v1/payouts/daily';

  /// Payouts — Per-day breakdown. [date] is optional; when provided it's
  /// appended as a path segment (expected format: `YYYY-MM-DD`).
  static String payoutsDayLevelSummary({String? date}) =>
      date == null || date.isEmpty
      ? 'v1/payouts/day-level-summary'
      : 'v1/payouts/day-level-summary/$date';

  /// Payouts — Gold coins rewards.
  static const String payoutsRewardsGoldCoins =
      'v1/payouts/rewards?type=gold_coins';

  /// Payouts — Red cards rewards.
  static const String payoutsRewardsRedCards =
      'v1/payouts/rewards?type=red_cards';

  /// Payouts — Rate card education.
  static const String payoutsRateCardEducation =
      'v1/payouts/rate-card-education';

  /// Payouts — Shift-end summary.
  static const String payoutsShiftEndSummary = 'v1/payouts/shift-end-summary';

  /// Payouts — Vishwaas rate card.
  static const String payoutsVishwaasRateCard = 'v1/payouts/vishwaas-rate-card';

  /// Referrals — "Refer & earn" home, opened from the drawer.
  static const String referralsHome = 'v1/referrals/home';

  /// Lunch — weekly lunch-slot selection, opened from the Home lunch banner.
  /// Baked-in fallback for [lunchSlotsPath].
  static const String lunchSlots = 'v1/lunch';

  /// Live lunch-slot path — [RemoteConfigKeys.lunchWebviewPath] when set,
  /// else [lunchSlots]. The one route that honours the Remote Config TODO
  /// above, so the banner's destination can be rolled forward/back without an
  /// app release.
  static String get lunchSlotsPath => resolveLunchSlotsPath(
    RemoteConfigService.instance.getString(
      RemoteConfigKeys.lunchWebviewPath,
      defaultValue: lunchSlots,
    ),
  );

  /// Seva — Snabbit Seva home in the webview.
  static const String seva = 'v1/seva';

  /// Tiers — Snabbit Coins tier home, opened from the drawer. The web module
  /// owns the intro-vs-home landing decision (redirects to the one-time
  /// intro flow first when the runner hasn't seen it), so this always
  /// targets `/home` regardless of whether the runner is a first-timer.
  static const String tiersHome = 'v1/tiers/home';

  /// Tiers — one-time intro video/flow. Opened from the drawer "Snabbit Udaan"
  /// row's "Play video" CTA once the runner has already viewed the intro
  /// ([UserProfile.hasViewedIntro]); always targets the intro regardless of
  /// that flag so the runner can re-watch it.
  static const String tiersIntro = 'v1/tiers/intro';

  /// Tiers — Snabbit Coins screen (coin balance / ledger).
  static const String tiersCoins = 'v1/tiers/coins';

  /// Tiers — "Perfect Job" reward category detail.
  static const String tiersCategoryPerfectJob = 'v1/tiers/category/perfect-job';

  /// Tiers — "Daily Streak" reward category detail.
  static const String tiersCategoryDailyStreak =
      'v1/tiers/category/daily-streak';

  /// Tiers — "Early Login" reward category detail.
  static const String tiersCategoryEarlyLogin = 'v1/tiers/category/early-login';

  /// Insurance — health insurance home, opened from the drawer for tiering
  /// runners (replaces the legacy native claim flow).
  static const String insuranceHealth = 'v1/insurance/health';

  /// Insurance — accident (personal-accident) insurance home, opened from the
  /// drawer for tiering runners.
  static const String insuranceAccident = 'v1/insurance/accident';

  /// Loan — loan home, opened from the drawer for tiering runners (replaces
  /// the legacy native LoanService flow).
  static const String loanHome = 'v1/loan';

  /// Early payout — early-payout home, opened from the drawer for tiering
  /// runners (replaces the legacy native EarlyPayoutsScreen).
  static const String earlyPayoutHome = 'v1/early-payout';

  /// Registration — city selection (lat/lng via bifrost initData only).
  static const String citySelection = 'v1/sobt/registration/city-confirmation';

  ///[training] - for accessing training slots and progress
  static const String training = 'v1/sobt/training';

  /// Go-live — date-selection entry, opened from the onboarding "Go live"
  /// button when the go-live webview flag is on; the native flow is used
  /// otherwise (backward compatible).
  static const String goLiveSelectDate = 'v1/sobt/go-live/select-date';

  /// Registration — early_registration module form inside onboarding hub.
  static String earlyRegistrationForm(int moduleId) =>
      'v1/sobt/registration/form?module_id=$moduleId';
}
