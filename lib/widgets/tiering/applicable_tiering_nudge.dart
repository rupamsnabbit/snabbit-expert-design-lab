import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/tiering/tier_coins_data.dart';
import 'package:snabbit_runner/models/tiering/tier_nudge.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/tiering/job_tiering_nudge.dart';
import 'package:snabbit_runner/widgets/tiering/tier_nudge_list_item.dart';
import 'package:snabbit_runner/widgets/tiering/tier_nudge_progress_card.dart';
import 'package:snabbit_runner/widgets/tiering/tiering_analytics.dart';

/// Renders the single `tier_nudge` from the live `current_state`
/// ([RunnerRtDataProvider.widgetInfo]) as the appropriate nudge widget:
///
/// - `THE_COIN_NUDGE` → [TierNudgeProgressCard] (coins from `nudge_details`),
/// - job-state nudges (`EARLY_CHECK_IN` / `PERFECT_JOB`) → [JobTieringNudge]
///   (count from `nudge_details.coin_amount`),
/// - everything else → [TierNudgeListItem] styled by the nudge's `theme`.
///
/// Takes no parameters — all data comes from [RunnerRtDataProvider] +
/// [UserProfileProvider]. Title copy (localization key + English fallback) and
/// the leading icon are hard-coded per `nudge_name` in [_copyFor] — a temporary
/// leadership directive until the localization bundle carries the keys. The tap
/// destination is client-owned via the tiering nudges sheet's "Where to Land"
/// column ([_routeFor]); only a nudge the client doesn't recognise falls back to
/// the server's `navigation_route`. Collapses to [SizedBox.shrink] when there's no
/// nudge (or it can't be rendered).
class ApplicableTieringNudge extends StatefulWidget {
  const ApplicableTieringNudge({super.key});

  @override
  State<ApplicableTieringNudge> createState() => _ApplicableTieringNudgeState();
}

class _ApplicableTieringNudgeState extends State<ApplicableTieringNudge> {
  /// Job-state nudges rendered as the coin-chip row.
  static const Set<String> _jobNudgeNames = {'EARLY_CHECK_IN', 'PERFECT_JOB'};

  /// Nudge rendered as the coins progress card (coins body in `nudge_details`).
  /// `WEEKLY_TIER_SUMMARY` is a static text nudge (null `nudge_details`), so it
  /// renders as a themed [TierNudgeListItem] instead — not here.
  static const Set<String> _coinsCardNudgeNames = {'THE_COIN_NUDGE'};

  /// Nudges that must always render with the TIER_SPECIFIC theme (tier badge +
  /// tier accent), regardless of the `theme` the server sends on the wire.
  static const Set<String> _tierSpecificNudgeNames = {
    'SHOWING_TIER',
    'WEEKLY_TIER_SUMMARY',
  };

  /// Title shown in the webview app bar once a nudge opens.
  static const String _webViewTitle = 'Snabbit Udaan';

  /// ECPO-927: the active-job cycle. Nudges shown here must be STATIC (must not
  /// navigate) so they don't distract the runner mid-job — their route is
  /// stripped. Superset of [_perfectJobWidgetStates] (adds check-in).
  /// TODO(ECPO-927): confirm this state set with product/QA.
  static const Set<String> _jobCycleWidgetStates = {
    'RUNNER_JOB_POST_ACCEPT',
    'RUNNER_ARRIVED',
    'RUNNER_JOB_CHECK_IN',
    'RUNNER_JOB_IN_PROGRESS',
    'RUNNER_POST_CHECKOUT',
  };

  /// ECPO-926: active-job states where the "do a perfect job" nudge replaces the
  /// server's round-robin nudge. `RUNNER_JOB_CHECK_IN` is deliberately excluded —
  /// it keeps its own `EARLY_CHECK_IN` nudge.
  /// TODO(ECPO-926): confirm this state set with product/QA.
  static const Set<String> _perfectJobWidgetStates = {
    'RUNNER_JOB_POST_ACCEPT',
    'RUNNER_ARRIVED',
    'RUNNER_JOB_IN_PROGRESS',
    'RUNNER_POST_CHECKOUT',
  };

  /// Resolves the nudge to render:
  /// - ECPO-926: during active-job states (check-in excluded) force `PERFECT_JOB`
  ///   in place of the server's round-robin nudge.
  /// - Sets [TierNudge.navigationRoute] from the client-owned sheet mapping
  ///   ([_routeFor]) for a KNOWN nudge, discarding the server's `navigation_route`;
  ///   only a genuinely-unknown nudge ([_isDynamicNudge]) keeps the wire
  ///   `navigation_route`. The leaf widgets and analytics both read this field, so
  ///   they stay in sync.
  /// - ECPO-927: any nudge shown during the job cycle is made STATIC — its route
  ///   is dropped so the leaf renders it non-tappable (no navigation during a job).
  /// - Forces the TIER_SPECIFIC theme for [_tierSpecificNudgeNames]
  ///   (`SHOWING_TIER` / `WEEKLY_TIER_SUMMARY`) regardless of the wire `theme`.
  TierNudge _effectiveNudge(String? widgetName, TierNudge serverNudge) {
    var nudge = serverNudge;
    if (_perfectJobWidgetStates.contains(widgetName) &&
        serverNudge.nudgeName != 'PERFECT_JOB') {
      // ECPO-1022: carry the server's coin_amount forward only when it sent one;
      // no default reward. Absent → null nudge_details → the coin pill is hidden.
      final coins = anyValueToInt(serverNudge.nudgeDetails?['coin_amount']);
      nudge = TierNudge(
        nudgeName: 'PERFECT_JOB',
        theme: serverNudge.theme,
        nudgeDetails: coins != null ? {'coin_amount': coins} : null,
      );
    }
    final route = _jobCycleWidgetStates.contains(widgetName)
        ? null // ECPO-927: static — no navigation during a job.
        // Keyed on the same "dynamic" predicate KMP uses ([_isDynamicNudge]): a
        // KNOWN nudge is client-owned via [_routeFor] (its deliberate nulls — the
        // enum-less benefits + job nudges — stay non-tappable); only a genuinely-
        // unknown nudge falls back to the wire `navigation_route`. `_routeFor` takes
        // precedence so `THE_COIN_NUDGE` (unknown to `_copyFor`, so `_isDynamicNudge`
        // is true, but it has a client route) keeps `tiersCoins`. KMP `effectiveNudge`
        // parity.
        : (_routeFor(nudge.nudgeName) ??
            (_isDynamicNudge(nudge.nudgeName)
                ? serverNudge.navigationRoute
                : null));
    // SHOWING_TIER / WEEKLY_TIER_SUMMARY always use the tier-specific theme.
    final theme = _tierSpecificNudgeNames.contains(nudge.nudgeName)
        ? NudgeTheme.tierSpecific
        : nudge.theme;
    return TierNudge(
      nudgeName: nudge.nudgeName,
      navigationRoute: route,
      imageUrl: nudge.imageUrl,
      theme: theme,
      nudgeDetails: nudge.nudgeDetails,
    );
  }

  /// `nudge_name|render_type` of the last impression logged — guards against
  /// re-firing the `viewed` event on every provider rebuild.
  String? _lastImpressionKey;

  /// Fires a one-shot `viewed` impression when the rendered nudge (name +
  /// render variant) changes. Fired inline from [build]; the `_lastImpressionKey`
  /// guard makes it once-per-appearance rather than once-per-rebuild.
  void _logImpression(TierNudge nudge, Tier? tier, String renderType) {
    final key = '${nudge.nudgeName}|$renderType';
    if (key == _lastImpressionKey) return;
    _lastImpressionKey = key;
    TieringAnalytics.nudgeViewed(nudge, tier, renderType);
  }

  /// Spacing above a rendered nudge. Applied only when a real nudge is shown so
  /// the empty (`SizedBox.shrink`) paths add no vertical space to the host.
  Widget _padded(Widget child) => Padding(
        padding: EdgeInsets.only(top: 16.h),
        child: child,
      );

  /// Collapses the nudge and clears the impression guard, so a nudge that
  /// disappears and later reappears identical re-fires its `viewed` event
  /// (once-per-appearance, not once-per-session).
  Widget _shrink() {
    _lastImpressionKey = null;
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RunnerRtDataProvider, UserProfileProvider>(
      builder: (context, rtData, profile, _) {
        final serverNudge = rtData.tierNudge;

        if (!profile.shouldShowTiering ||
            serverNudge == null ||
            profile.user?.tier?.isLegacyTier == true) {
          return _shrink();
        }

        final serverName = serverNudge.nudgeName;
        if (serverName == null || serverName.isEmpty) {
          return _shrink();
        }

        final tier = profile.user?.tier;

        // ECPO-926 (force perfect-job) + ECPO-927 (static during the job cycle).
        final nudge = _effectiveNudge(rtData.widgetInfo?.name, serverNudge);
        final name = nudge.nudgeName!;

        // Coins nudge → the coins progress card (data from nudge_details).
        if (_coinsCardNudgeNames.contains(name)) {
          final details = nudge.nudgeDetails;
          if (tier == null || details == null) return _shrink();
          _logImpression(nudge, tier, TieringAnalytics.renderTypeCoinsCard);
          return _padded(TierNudgeProgressCard(
            tier: tier,
            data: TierCoinsData.fromJson(details),
            route: nudge.navigationRoute,
            webViewTitle: _webViewTitle,
            onTap: () => TieringAnalytics.nudgeClicked(
                nudge, tier, TieringAnalytics.renderTypeCoinsCard),
          ));
        }

        // Hard-coded title copy + leading icon for this nudge_name.
        final copy = _copyFor(nudge, tier);

        // Job-state nudges → the coin-chip row.
        if (_jobNudgeNames.contains(name)) {
          _logImpression(nudge, tier, TieringAnalytics.renderTypeJob);
          // ECPO-1022: null (→ pill hidden) when absent OR non-positive — a 0
          // reward shows nothing, never a made-up default.
          final jobCoins = anyValueToInt(nudge.nudgeDetails?['coin_amount']);
          return _padded(JobTieringNudge(
            titleKey: copy.titleKey,
            titleFallback: copy.fallback,
            additionalData: copy.values,
            coinsCount: (jobCoins != null && jobCoins > 0) ? jobCoins : null,
            route: nudge.navigationRoute,
            webViewTitle: _webViewTitle,
            onTap: () => TieringAnalytics.nudgeClicked(
                nudge, tier, TieringAnalytics.renderTypeJob),
          ));
        }

        // Everything else → the themed list-item row. TIER_SPECIFIC shows the
        // tier's own badge icon (untinted); other themes show the nudge's
        // dedicated icon — falling back to the wire image_url — tinted to the
        // theme accent. A null navigation_route renders non-tappable.
        _logImpression(nudge, tier, TieringAnalytics.renderTypeThemed);
        final isTierSpecific = nudge.theme == NudgeTheme.tierSpecific;
        final style = _styleFor(nudge.theme, tier);
        return _padded(TierNudgeListItem(
          titleKey: copy.titleKey,
          titleFallback: copy.fallback,
          additionalData: copy.values,
          leadingImage: isTierSpecific
              ? _tierBadgeUrl(tier)
              : (copy.icon ?? nudge.imageUrl ?? ''),
          leadingImageColor: isTierSpecific ? null : style.imageTint,
          route: nudge.navigationRoute,
          gradient: style.gradient,
          borderColor: style.border,
          titleColor: style.title,
          webViewTitle: _webViewTitle,
          onTap: () => TieringAnalytics.nudgeClicked(
              nudge, tier, TieringAnalytics.renderTypeThemed),
        ));
      },
    );
  }
}

/// Hard-coded title copy + leading icon for a nudge, keyed by `nudge_name`.
///
/// Temporary leadership directive: until the localization bundle carries the
/// `nudge_name` keys, both the key and its English fallback are hard-coded (from
/// the tiering-nudges sheet — the source of truth). [values] fills the
/// `{{token}}` placeholders in [fallback] via `LanguageProvider.getFormattedMessage`.
class _NudgeCopy {
  const _NudgeCopy({
    required this.titleKey,
    required this.fallback,
    this.icon,
    this.values = const {},
  });

  /// Localization key, e.g. `tiering_nudge_refer_and_earn`.
  final String titleKey;

  /// English fallback shown until [titleKey] lands in the active locale. May
  /// contain `{{token}}` placeholders filled from [values].
  final String fallback;

  /// Dedicated leading icon (a [RemoteConfigAssets] URL). Null → the caller
  /// falls back to the wire `image_url`.
  final String? icon;

  /// Values substituted into [fallback]'s `{{token}}` placeholders.
  final Map<String, dynamic> values;
}

/// Resolves the hard-coded copy for every possible `nudge_name`. The tiering
/// nudges sheet is the source of truth for the fallback text and the leading
/// icon; the amount/tier nudges interpolate `nudge_details` into the fallback.
///
/// An unknown `nudge_name` falls through to [TierNudge.nudgeName] as both key
/// and fallback (the pre-hard-coding behaviour), with no dedicated icon.
_NudgeCopy _copyFor(TierNudge nudge, Tier? tier) {
  final name = nudge.nudgeName ?? '';
  final details = nudge.nudgeDetails;
  switch (name) {
    // ── Tier introduction / transparency ─────────────────────────────────────
    case 'LAUNCH':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_launch',
        fallback: 'See how Levels work',
        icon: RemoteConfigAssets.genericSeeBenefits,
      );
    case 'SHOWING_TIER':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_showing_tier',
        fallback: 'Congratulations! You are a {{tier}} expert',
        icon: RemoteConfigAssets.genericTierSummary,
        values: {'tier': tier?.normalizedDescription ?? ''},
      );
    case 'WEEKLY_TIER_SUMMARY':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_weekly_tier_summary',
        fallback: "See this week's rewards",
        icon: RemoteConfigAssets.genericTierSummary,
      );

    // ── Job-state nudges (coin-chip row; icon fixed to tierJob by
    //    JobTieringNudge). No sheet row — copy authored; replace when design
    //    provides it.
    case 'EARLY_CHECK_IN':
      return const _NudgeCopy(
        titleKey: 'tiering_nudge_early_check_in',
        fallback: 'Check in early to earn Snabbit Coins',
      );
    case 'PERFECT_JOB':
      return const _NudgeCopy(
        titleKey: 'tiering_nudge_perfect_job',
        fallback: 'Do a perfect job to earn Snabbit Coins',
      );

    // ── Motivation ───────────────────────────────────────────────────────────
    case 'PERFECT_JOBS':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_perfect_jobs',
        fallback: 'Do perfect jobs to earn more Snabbit Coins',
        icon: RemoteConfigAssets.motivationRank,
      );
    case 'ATTENDANCE_STREAK':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_attendance_streak',
        fallback: 'Maintain streak of attendance to get Snabbit Coins',
        icon: RemoteConfigAssets.motivationRank,
      );
    case 'REFER_AND_EARN':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_refer_and_earn',
        fallback: 'Refer and earn more',
        icon: RemoteConfigAssets.motivationRank,
      );
    case 'RATE_CARD':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_rate_card',
        fallback: 'Check your rate card',
        icon: RemoteConfigAssets.motivationRank,
      );
    case 'EARLY_LOGIN':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_early_login',
        fallback: 'Login early to get Snabbit coins',
        icon: RemoteConfigAssets.motivationRank,
      );

    // ── Benefits ─────────────────────────────────────────────────────────────
    case 'INSURANCE_SETUP':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_insurance_setup',
        fallback: 'Check your Insurance details',
        icon: RemoteConfigAssets.benefitHealthInsurance,
      );
    case 'NETWORK_HOSPITALS':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_network_hospitals',
        fallback: 'Check our network hospitals',
        icon: RemoteConfigAssets.benefitHealthInsurance,
      );
    case 'SEVA_ACCESS':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_seva_access',
        fallback: 'Explore Seva spaces near you',
        icon: RemoteConfigAssets.benefitSeva,
      );
    case 'LOAN_ELIGIBLE':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_loan_eligible',
        fallback: "Did you know? You're eligible for a {{amount}} loan",
        icon: RemoteConfigAssets.benefitLoan,
        values: {'amount': _amountText(details?['loan_amount'])},
      );
    case 'HEALTH_INSURANCE_CASHLESS':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_health_insurance_cashless',
        fallback: 'Use cashless treatment at partner hospitals',
        icon: RemoteConfigAssets.benefitHealthInsurance,
      );
    case 'ACCIDENTAL_INSURANCE':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_accidental_insurance',
        fallback: 'Check your Accidental Cover of {{amount}}',
        icon: RemoteConfigAssets.benefitAccidental,
        values: {'amount': _amountText(details?['insurance_amount'])},
      );
    case 'EARLY_PAYOUT':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_early_payout',
        fallback: 'You can take early payout without interest',
        icon: RemoteConfigAssets.benefitEarlyPayout,
      );

    // ── Benefits without a backend enum in the sheet yet. Enum names below are
    //    BEST-GUESSES — reconcile with backend before relying on delivery.
    case 'LUNCH_FLEXIBILITY':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_lunch_flexibility',
        fallback: 'Set your lunch slot for this week',
        icon: RemoteConfigAssets.benefitLunch,
      );
    case 'PATH_TO_PROMOTION':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_path_to_promotion',
        fallback: "You're eligible — apply to become a Trainer or Lead",
        icon: RemoteConfigAssets.benefitPromotion,
      );
    case 'RED_CARD_WAIVER':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_red_card_waiver',
        fallback: 'Do you know? You can waive some red cards',
        icon: RemoteConfigAssets.benefitRedCardWaiver,
      );
    case 'PRIORITY_SUPPORT':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_priority_support',
        fallback: 'Your issues now get priority, call saathi',
        icon: RemoteConfigAssets.benefitCustomerPriority,
      );
    case 'MERCH_DISCOUNT':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_merch_discount',
        fallback: 'Your merch discount is live, shop now',
        icon: RemoteConfigAssets.benefitMerch,
      );
    case 'BIRTHDAY_GIFT':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_birthday_gift',
        fallback: "You get birthday gift if you're pink diamond",
        icon: RemoteConfigAssets.benefitBirthday,
      );
    case 'WELCOME_VOUCHERS':
      return _NudgeCopy(
        titleKey: 'tiering_nudge_welcome_vouchers',
        fallback: 'You get gift voucher on becoming pink diamond expert',
        icon: RemoteConfigAssets.benefitVouchers,
      );

    default:
      // Unknown nudge — show the raw name (pre-hard-coding behaviour), no icon.
      return _NudgeCopy(titleKey: name, fallback: name);
  }
}

/// True when [name] matches no case in [_copyFor] — a genuinely-unknown nudge.
/// Only these honour the wire `navigation_route` in [_effectiveNudge]; every known
/// name (including the deliberately route-less job nudges + enum-less benefits)
/// stays client-owned. Mirrors the KMP `isDynamicNudge`, and reuses [_copyFor] as
/// the single source of the known-name set so the two can't drift: every known case
/// returns a `tiering_nudge_*` key, so a `titleKey` still equal to the raw [name]
/// means the default (unknown) branch was taken.
bool _isDynamicNudge(String? name) =>
    name != null &&
    name.isNotEmpty &&
    _copyFor(TierNudge(nudgeName: name), null).titleKey == name;

/// The client-owned webview destination for a nudge, keyed by `nudge_name`
/// (the tiering nudges sheet's "Where to Land" column — the source of truth).
/// The server's `navigation_route` is intentionally ignored for these KNOWN names;
/// only a genuinely-unknown nudge ([_isDynamicNudge]) falls back to the wire
/// `navigation_route` in [_effectiveNudge].
///
/// Returns null (→ deliberately non-tappable; the wire route does NOT revive them):
/// - the job-cycle nudges (`EARLY_CHECK_IN` / `PERFECT_JOB`) — also stripped by
///   ECPO-927 while a job is active;
/// - the seven benefit rows the sheet leaves without a backend enum (lunch,
///   path-to-promotion, red-card waiver, priority support, merch, birthday,
///   welcome vouchers).
String? _routeFor(String? name) {
  switch (name) {
    // Tier introduction / transparency.
    case 'LAUNCH':
    case 'SHOWING_TIER':
    case 'WEEKLY_TIER_SUMMARY':
      return WebviewRoutes.tiersHome;
    case 'THE_COIN_NUDGE':
      return WebviewRoutes.tiersCoins;

    // Motivation → reward-category detail screens.
    case 'PERFECT_JOBS':
      return WebviewRoutes.tiersCategoryPerfectJob;
    case 'ATTENDANCE_STREAK':
      return WebviewRoutes.tiersCategoryDailyStreak;
    case 'EARLY_LOGIN':
      return WebviewRoutes.tiersCategoryEarlyLogin;
    case 'REFER_AND_EARN':
      return WebviewRoutes.referralsHome;
    case 'RATE_CARD':
      return WebviewRoutes.payoutsRateCardEducation;

    // Benefits.
    case 'SEVA_ACCESS':
      return WebviewRoutes.seva;
    case 'LOAN_ELIGIBLE':
      return WebviewRoutes.loanHome;
    case 'EARLY_PAYOUT':
      return WebviewRoutes.earlyPayoutHome;
    case 'ACCIDENTAL_INSURANCE':
      return WebviewRoutes.insuranceAccident;
    case 'INSURANCE_SETUP':
    case 'NETWORK_HOSPITALS':
    case 'HEALTH_INSURANCE_CASHLESS':
      return WebviewRoutes.insuranceHealth;

    default:
      return null;
  }
}

/// Renders an amount from `nudge_details` (`loan_amount` / `insurance_amount`)
/// for the `{{amount}}` placeholder. A number (or numeric string) is formatted
/// as Indian currency; a value the backend already formatted (e.g. "₹3,00,000")
/// is passed through unchanged.
String _amountText(dynamic raw) {
  if (raw == null) return '';
  final parsed = anyValueToInt(raw);
  return parsed != null ? formatIndianCurrency(parsed) : raw.toString();
}

/// Resolved styling for a themed [TierNudgeListItem].
class _NudgeStyle {
  const _NudgeStyle({
    required this.gradient,
    required this.border,
    required this.title,
    required this.imageTint,
  });

  final Gradient gradient;
  final Color border;
  final Color title;
  final Color imageTint;
}

/// Left-to-right gradient from white to [end] (a solid white when [end] is n0).
LinearGradient _whiteTo(Color end) => LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [AppColors.n0, end],
    );

_NudgeStyle _styleFor(NudgeTheme theme, Tier? tier) {
  switch (theme) {
    case NudgeTheme.generic:
      return _NudgeStyle(
        gradient: _whiteTo(AppColors.n0),
        border: AppColors.nudgeGenericBorder,
        title: AppColors.nudgeGenericTitle,
        imageTint: AppColors.nudgeGenericBorder,
      );
    case NudgeTheme.benefits:
      return _NudgeStyle(
        gradient: _whiteTo(AppColors.nudgeBenefitsTint),
        border: AppColors.nudgeBenefitsAccent,
        title: AppColors.nudgeBenefitsTitle,
        imageTint: AppColors.nudgeBenefitsAccent,
      );
    case NudgeTheme.motivation:
      return _NudgeStyle(
        gradient: _whiteTo(AppColors.nudgeMotivationTint),
        border: AppColors.nudgeMotivationAccent,
        title: AppColors.nudgeMotivationAccent,
        imageTint: AppColors.nudgeMotivationAccent,
      );
    case NudgeTheme.tierSpecific:
      return _tierSpecificStyle(tier);
  }
}

/// Tier-specific theme: border == title == image tint == the tier accent, with
/// a white → tint background. Legacy/unknown tiers fall back to the generic look.
_NudgeStyle _tierSpecificStyle(Tier? tier) {
  switch (tier) {
    case Tier.BASE:
      return _tierStyle(
          AppColors.nudgeTierBaseAccent, AppColors.nudgeTierBaseTint);
    case Tier.SILVER:
      return _tierStyle(
          AppColors.nudgeTierSilverAccent, AppColors.nudgeTierSilverTint);
    case Tier.GOLD:
      return _tierStyle(
          AppColors.nudgeTierGoldAccent, AppColors.nudgeTierGoldTint);
    case Tier.DIAMOND:
      return _tierStyle(
          AppColors.nudgeTierDiamondAccent, AppColors.nudgeTierDiamondTint);
    case Tier.PINK_DIAMOND:
      return _tierStyle(AppColors.nudgeTierPinkDiamondAccent,
          AppColors.nudgeTierPinkDiamondTint);
    case Tier.PRO:
    case Tier.ELITE:
    case Tier.BASIC:
    case null:
      return _styleFor(NudgeTheme.generic, null);
  }
}

_NudgeStyle _tierStyle(Color accent, Color tint) => _NudgeStyle(
      gradient: _whiteTo(tint),
      border: accent,
      title: accent,
      imageTint: accent,
    );

/// The tier's own badge icon (from [RemoteConfigAssets]) for the TIER_SPECIFIC
/// theme — shown untinted. Empty for tiers without a dedicated badge.
String _tierBadgeUrl(Tier? tier) {
  switch (tier) {
    case Tier.BASE:
      return RemoteConfigAssets.baseTier;
    case Tier.SILVER:
      return RemoteConfigAssets.silverTier;
    case Tier.GOLD:
      return RemoteConfigAssets.goldTier;
    case Tier.DIAMOND:
      return RemoteConfigAssets.diamondTier;
    case Tier.PINK_DIAMOND:
      return RemoteConfigAssets.pinkDiamondTier;
    case Tier.PRO:
    case Tier.ELITE:
    case Tier.BASIC:
    case null:
      return '';
  }
}
