package com.snabbit.runner.shared.features.tiering.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.features.job.data.asIntOrNull
import com.snabbit.runner.shared.features.tiering.data.TieringDataSource
import com.snabbit.runner.shared.features.tiering.domain.model.NudgeTheme
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierNudge
import com.snabbit.runner.shared.features.tiering.domain.model.TieringProfile
import com.snabbit.runner.shared.features.tiering.presentation.TieringAnalytics
import com.snabbit.runner.shared.features.tiering.presentation.isDynamicNudge
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TierRowContent
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringNudgeContent
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringUiIntent
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringUiState
import com.snabbit.runner.shared.features.tiering.presentation.tierNudgeCopy
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Drives the tiering surfaces. Folds the Dart-fed `current_state.tier_nudge` +
 * `runners/me` tiering slice ([TieringDataSource]) into [TieringUiState], routing
 * the nudge to its render variant (coins card / job row / themed row) exactly like
 * the Flutter `ApplicableTieringNudge`. Intents fire analytics (impressions +
 * clicks) and open the tiers webview via the injected [NavigationController]
 * (D2: nav through the controller, no per-VM effect channel).
 *
 * Mounted by the bottom-nav hosts — `HomeTabContent`, `ProfileTabContent`, and
 * `ActiveJobOverlay` each resolve it via `koinViewModel()` and pass the state slices
 * to the stateless tiering composables (Home nudge/banner + app-bar pill, the profile
 * tier card + play-video row, the in-job nudge).
 */
class TieringViewModel(
    private val dataSource: TieringDataSource,
    private val analytics: TieringAnalytics,
    // Resolves nudge/webview copy against the bridged i18n map (Flutter-key parity);
    // empty store → English fallbacks, so tests/previews render the same text.
    private val store: LocalizationStore,
    // Nullable so previews/tests stay DI-free (a click becomes a no-op); wired in tieringModule.
    private val nav: NavigationController? = null,
) : ViewModel() {

    private val _uiState = MutableStateFlow(TieringUiState())
    val uiState: StateFlow<TieringUiState> = _uiState.asStateFlow()

    /** Latest raw inputs — click/impression handlers read the nav route + analytics context from these. */
    private var currentNudge: TierNudge? = null
    private var currentProfile: TieringProfile = TieringProfile()

    /** Identity of the nudge the last impression was logged for — de-dups repeated `NudgeShown`s. */
    private var lastViewedNudgeKey: String? = null

    init {
        viewModelScope.launch {
            combine(
                dataSource.nudge,
                dataSource.profile,
                dataSource.widgetName,
            ) { nudge, profile, widget -> Triple(nudge, profile, widget) }
                .collect { (serverNudge, profile, widget) ->
                    // ECPO-926: during an active job, force the perfect-job nudge over the
                    // server's round-robin nudge (check-in keeps its EARLY_CHECK_IN nudge).
                    val nudge = effectiveNudge(widget, serverNudge)
                    currentNudge = nudge
                    currentProfile = profile
                    _uiState.update {
                        it.copy(
                            // Nudge: the date-based `shouldShowTiering` (ECPO-924 intro gate) AND the
                            // runner is on a NEW-scheme tier — a legacy runner never sees it. Mirrors
                            // the release ApplicableTieringNudge (`shouldShowTiering && !isLegacyTier`).
                            homeNudge = if (showTieringSurfaces(profile) && profile.tier?.isLegacyTier != true) {
                                resolveNudge(nudge, profile.tier)
                            } else {
                                null
                            },
                            // Intro banner opens the funnel to EVERY service-1, non-suspended runner
                            // who hasn't watched it — including legacy / not-yet-live runners (so they
                            // can watch it and get promoted). The release dropped the tiering-enabled
                            // (effective-date) requirement here; there is no tier gate.
                            showUdaanBanner = isServiceEligible(profile) && !profile.hasViewedIntro,
                            // Post-intro "Play video" replay row (profile card slot): same service
                            // triad, intro VIEWED, above BASE. No effective-date / isLegacy gate —
                            // mirrors the release SnabbitUdaanPlayVideoRow.
                            showUdaanPlayVideoRow = isServiceEligible(profile) &&
                                profile.hasViewedIntro && profile.tier != Tier.BASE,
                            // Profile tier card — gated on TIER IDENTITY only (new-scheme, not
                            // legacy), independent of the effective date/intro. The release fix: a
                            // just-promoted runner (new tier, future effective date) shows the new
                            // card immediately (Flutter view_tier / expert_info `!isLegacyTier`).
                            profileTierCard = resolveProfileTierCard(profile),
                            // App-bar tier pill — UNCHANGED gate (the release did NOT migrate
                            // TierBadgeV2): still the full date-based `shouldShowTiering`, so it can
                            // lag the profile card until the effective date (known split; see KDoc).
                            tierBadge = resolveTierBadge(profile),
                            // Raw effective-date flag surfaced for the Profile insurance split
                            // (Flutter `user.isTieringEnabled`); independent of the gates above.
                            isTieringEnabled = profile.isTieringEnabled,
                        )
                    }
                }
        }
    }

    fun onIntent(intent: TieringUiIntent) {
        when (intent) {
            TieringUiIntent.NudgeShown -> activeNudge()?.let { nudge ->
                // De-dup the impression by nudge identity. The SAME nudge is shown by more than one
                // host at once (Home's ApplicableTieringNudge + the in-job overlay, which force the
                // Job variant into homeNudge), and each host re-fires NudgeShown on every tab re-entry
                // (its keyed LaunchedEffect re-runs when the subtree re-composes). The VM outlives those
                // recompositions, so gating on the last-logged identity keeps ONE `tiering_nudge_viewed`
                // per on-screen nudge instead of one per host / per revisit.
                val key = nudgeImpressionKey(nudge)
                if (key != lastViewedNudgeKey) {
                    lastViewedNudgeKey = key
                    analytics.nudgeViewed(nudge, currentProfile.tier, renderType(nudge))
                }
            }
            TieringUiIntent.NudgeClicked -> activeNudge()?.let { nudge ->
                // ECPO-927: a static (routeless) nudge — e.g. any nudge during the job
                // cycle — neither navigates nor logs a click.
                val route = nudge.navigationRoute
                if (!route.isNullOrBlank()) {
                    analytics.nudgeClicked(nudge, currentProfile.tier, renderType(nudge))
                    openRoute(route, WEBVIEW_TITLE_UDAAN)
                }
            }
            is TieringUiIntent.BannerShown -> analytics.bannerViewed(showHeaderImage = intent.showHeaderImage)
            is TieringUiIntent.BannerClicked -> {
                analytics.bannerClicked(showHeaderImage = intent.showHeaderImage)
                // Banner webview title is localized (Flutter `snabbit_udaan_banner_webview_title`).
                openRoute(TIERS_HOME_ROUTE, store.getMessage(WEBVIEW_TITLE_BANNER_KEY, WEBVIEW_TITLE_UDAAN))
            }
            TieringUiIntent.ProfileTierShown -> analytics.profileTierViewed(currentProfile.tier)
            TieringUiIntent.ProfileTierClicked -> {
                analytics.profileTierClicked(currentProfile.tier)
                openRoute(TIERS_HOME_ROUTE, WEBVIEW_TITLE_UDAAN)
            }
            // App-bar tier badge — nav only (Flutter TierBadgeV2 fires no tap event); it
            // opens the tiers home titled "Levels Home" (Flutter TierBadgeV2 parity).
            TieringUiIntent.TierBadgeClicked -> openRoute(TIERS_HOME_ROUTE, WEBVIEW_TITLE_LEVELS_HOME)
            // Post-intro "Play video" row — re-opens the tiers INTRO webview (not tiers home),
            // titled "Snabbit Udaan". Nav only, no analytics (Flutter SnabbitUdaanPlayVideoRow).
            TieringUiIntent.PlayVideoClicked -> openRoute(TIERS_INTRO_ROUTE, WEBVIEW_TITLE_UDAAN)
        }
    }

    private fun activeNudge(): TierNudge? = currentNudge?.takeIf { !it.nudgeName.isNullOrEmpty() }

    /** Stable per-render identity for the viewed-impression de-dup (parity with the host's LaunchedEffect key). */
    private fun nudgeImpressionKey(nudge: TierNudge): String =
        "${nudge.nudgeName}|${renderType(nudge)}|${currentProfile.tier?.name}"

    /**
     * Resolves the nudge to render for the current widget state.
     *
     * ECPO-926/927 — the job-cycle nudges are **client-owned**: during an active
     * job the perfect-job (working stages) / early-check-in (check-in) nudge is
     * shown REGARDLESS of what the backend puts in `tier_nudge`. The server ships
     * `tier_nudge: null` in job-state `current_state`, so gating on a non-null
     * server nudge (the old behaviour) hid the nudge for the entire job — the exact
     * bug this fixes. The server's `coin_amount` is honoured when present; when absent
     * the nudge shows with NO coin chip (ECPO-1022: no hard-coded default reward). The
     * route is always null (ECPO-927: static — no navigation mid-job).
     *
     * Non-job (home) states are unchanged: server-driven, with the client-owned
     * route map ([routeFor]) and the forced tier-specific theme for SHOWING_TIER /
     * WEEKLY_TIER_SUMMARY. A null server nudge on a home state yields no nudge.
     */
    private fun effectiveNudge(widgetName: String?, serverNudge: TierNudge?): TierNudge? {
        // The client-owned job nudge for this stage, independent of the server nudge.
        val jobNudgeName = when {
            widgetName in PERFECT_JOB_STATES -> PERFECT_JOB
            widgetName == CHECK_IN_STATE -> EARLY_CHECK_IN
            else -> null
        }
        if (jobNudgeName != null) {
            // Honour the server's coin_amount when it sent one for this stage. ECPO-1022:
            // NO default reward — when the server omits it (it ships tier_nudge: null
            // mid-job) we carry no coin_amount forward, and the chip is hidden downstream.
            // asIntOrNull() (tolerant int-or-quoted-int-or-float) mirrors the Dart
            // `anyValueToInt`, so a `5.0` on the wire parses identically on both platforms.
            val coins = serverNudge?.nudgeDetails?.get(KEY_COIN_AMOUNT).asIntOrNull()
            return TierNudge(
                nudgeName = jobNudgeName,
                navigationRoute = null, // ECPO-927: static during the job cycle.
                theme = serverNudge?.theme ?: NudgeTheme.GENERIC,
                nudgeDetails = coins?.let { buildJsonObject { put(KEY_COIN_AMOUNT, it) } },
            )
        }
        if (serverNudge == null) return null
        // Route keyed on the SAME "dynamic" predicate as the tint ([isDynamicNudge]): a
        // genuinely-unknown nudge honours the wire `navigation_route` (backend can point a new
        // nudge anywhere without a release); every KNOWN nudge is client-owned via [routeFor],
        // whose deliberate `null`s (the enum-less benefits + the job nudges) stay non-tappable —
        // the wire route must NOT resurrect them (ECPO-927: job nudges are static).
        // [routeFor] takes PRECEDENCE so THE_COIN_NUDGE — which has no copySpec entry (→
        // isDynamicNudge = true) but DOES have a client route — keeps `v1/tiers/coins`, not the
        // wire route. Flutter `_effectiveNudge` parity.
        val route = routeFor(serverNudge.nudgeName)
            ?: serverNudge.navigationRoute?.takeIf { isDynamicNudge(serverNudge.nudgeName) }
        // SHOWING_TIER / WEEKLY_TIER_SUMMARY always render tier-specific (tier badge +
        // tier accent) regardless of the wire `theme` — matches Flutter `_effectiveNudge`.
        val theme = if (serverNudge.nudgeName in TIER_SPECIFIC_NUDGES) {
            NudgeTheme.TIER_SPECIFIC
        } else {
            serverNudge.theme
        }
        return serverNudge.copy(navigationRoute = route, theme = theme)
    }

    private fun resolveNudge(nudge: TierNudge?, tier: Tier?): TieringNudgeContent? {
        val name = nudge?.nudgeName?.takeIf { it.isNotEmpty() } ?: return null
        if (name == COIN_NUDGE) {
            if (tier == null) return null
            val data = dataSource.coins(nudge) ?: return null
            return TieringNudgeContent.CoinsCard(tier, data)
        }
        val copy = tierNudgeCopy(nudge, tier, store)
        if (name in JOB_NUDGES) {
            // ECPO-1022: null (→ no coin chip) when the server sent no coin_amount OR
            // it's non-positive — a 0 reward shows nothing, never a made-up default.
            // asIntOrNull() mirrors the Dart `anyValueToInt` (int / quoted-int / float).
            val coins = nudge.nudgeDetails?.get(KEY_COIN_AMOUNT).asIntOrNull()?.takeIf { it > 0 }
            return TieringNudgeContent.Job(copy.titleKey, copy.title, coins)
        }
        // Known nudges always tint their (monochrome) themed glyph. A dynamic / default
        // nudge (its icon is the wire `image_url`) tints only when the backend sent a
        // theme; a themeless one shows the raw image (no SrcIn flattening).
        val tintImage = !isDynamicNudge(name) || nudge.themeProvided
        return TieringNudgeContent.Themed(copy.titleKey, copy.title, copy.iconUrl, nudge.theme, tier, tintImage)
    }

    /**
     * The profile tier card (Flutter `ViewTierFromDrawerMenu` / `expert_info`). Post-release
     * this is gated on TIER IDENTITY alone — any NEW-scheme tier ([newSchemeTier]) — with NO
     * effective-date / intro gate. So a runner promoted into the new scheme shows the per-tier
     * card the instant their `tier` updates, even before the effective date (the bug the
     * release fixes: new-tier data inside legacy-gated chrome).
     */
    private fun resolveProfileTierCard(profile: TieringProfile): TierRowContent? =
        newSchemeTier(profile)?.let(::TierRowContent)

    /**
     * The app-bar tier pill (Flutter `TierBadgeV2`). Deliberately still the FULL date-based
     * [showTieringSurfaces] gate — the release did NOT migrate this surface — so it goes live
     * only once tiering is actually live (effective date reached) AND the intro is accepted,
     * and can lag [resolveProfileTierCard] for a just-promoted runner (a known cross-surface
     * split, mirrored from Flutter — see the release's un-migrated TierBadgeV2).
     */
    private fun resolveTierBadge(profile: TieringProfile): TierRowContent? {
        if (!showTieringSurfaces(profile)) return null
        return newSchemeTier(profile)?.let(::TierRowContent)
    }

    /** The runner's tier iff it is a NEW-scheme tier (non-null and not [Tier.isLegacyTier]); else null. */
    private fun newSchemeTier(profile: TieringProfile): Tier? =
        profile.tier?.takeIf { !it.isLegacyTier }

    /** Post-intro master gate — full mirror of Flutter `UserProfileProvider.shouldShowTiering`. */
    private fun showTieringSurfaces(profile: TieringProfile): Boolean =
        profile.hasViewedIntro && isTieringEligible(profile)

    /**
     * The service-level eligibility shared by ALL Udaan surfaces, independent of BOTH the
     * effective date and the intro: on service 1 and not suspended. The intro banner and the
     * play-video row gate on this directly — they deliberately ignore the effective date so a
     * legacy / not-yet-live runner can still enter (and replay) the funnel.
     */
    private fun isServiceEligible(profile: TieringProfile): Boolean =
        profile.serviceId == 1 && !profile.isSuspended

    /**
     * The eligibility half of `shouldShowTiering`: [isServiceEligible] PLUS tiering actually
     * live for the runner (`isTieringEnabled` — the effective date reached). The nudge + the
     * app-bar badge keep this date gate; the banner / play-video row deliberately don't.
     */
    private fun isTieringEligible(profile: TieringProfile): Boolean =
        profile.isTieringEnabled && isServiceEligible(profile)

    private fun renderType(nudge: TierNudge): String = when (nudge.nudgeName) {
        COIN_NUDGE -> TieringAnalytics.RENDER_TYPE_COINS_CARD
        in JOB_NUDGES -> TieringAnalytics.RENDER_TYPE_JOB
        else -> TieringAnalytics.RENDER_TYPE_THEMED
    }

    /**
     * Opens a tiering webview [route] (a `WebviewRoutes` path like `v1/tiers/home`)
     * in the Flutter bifrost webview — mirroring the Flutter leaves' `WebViewLauncher.open`
     * and the Profile/Home KMP handoffs. The path is NOT a native Flutter route, so it is
     * passed as the `webviewPath` arg of the generic `/app-web-view` page (Dart resolves it
     * via `buildWebviewUrl`); handing the bare path in as the route lands on Flutter Home
     * instead. Keep-host so system-back returns to the bottom-nav shell that owns the surface.
     */
    private fun openRoute(route: String?, title: String) {
        val target = route?.takeIf { it.isNotBlank() } ?: return
        nav?.requestFlutterRouteKeepingHost(
            route = APP_WEB_VIEW_ROUTE,
            args = mapOf(WEBVIEW_PATH_ARG to target, WEBVIEW_TITLE_ARG to title),
            recreateKey = HOST_RECREATE_KEY,
            recreateArgs = mapOf(HOST_TAB_ARG to HOST_TAB_HOME),
        )
    }

    /**
     * Client-owned webview destination per `nudge_name` — the tiering sheet's
     * "Where to Land" column. The server's `navigation_route` is intentionally
     * ignored (matches Flutter `_routeFor`). null → non-tappable.
     */
    private fun routeFor(name: String?): String? = when (name) {
        "LAUNCH", "SHOWING_TIER", "WEEKLY_TIER_SUMMARY" -> TIERS_HOME_ROUTE
        COIN_NUDGE -> "v1/tiers/coins"
        "PERFECT_JOBS" -> "v1/tiers/category/perfect-job"
        "ATTENDANCE_STREAK" -> "v1/tiers/category/daily-streak"
        "EARLY_LOGIN" -> "v1/tiers/category/early-login"
        "REFER_AND_EARN" -> "v1/referrals/home"
        "RATE_CARD" -> "v1/payouts/rate-card-education"
        "SEVA_ACCESS" -> "v1/seva"
        "LOAN_ELIGIBLE" -> "v1/loan"
        "EARLY_PAYOUT" -> "v1/early-payout"
        "ACCIDENTAL_INSURANCE" -> "v1/insurance/accident"
        "INSURANCE_SETUP", "NETWORK_HOSPITALS", "HEALTH_INSURANCE_CASHLESS" -> "v1/insurance/health"
        // Job nudges + the enum-less benefits (LUNCH_FLEXIBILITY, PATH_TO_PROMOTION,
        // RED_CARD_WAIVER, PRIORITY_SUPPORT, MERCH_DISCOUNT, BIRTHDAY_GIFT,
        // WELCOME_VOUCHERS) have no landing → non-tappable.
        else -> null
    }

    private companion object {
        const val COIN_NUDGE = "THE_COIN_NUDGE"
        const val PERFECT_JOB = "PERFECT_JOB"
        const val EARLY_CHECK_IN = "EARLY_CHECK_IN"
        val JOB_NUDGES = setOf(EARLY_CHECK_IN, PERFECT_JOB)

        // Always tier-specific (tier badge + accent) regardless of the wire theme.
        val TIER_SPECIFIC_NUDGES = setOf("SHOWING_TIER", "WEEKLY_TIER_SUMMARY")
        const val KEY_COIN_AMOUNT = "coin_amount"
        const val TIERS_HOME_ROUTE = "v1/tiers/home"

        // The tiers INTRO webview (WebviewRoutes.tiersIntro) — the "Play video" row's
        // re-watch destination, distinct from the tiers HOME the other surfaces open.
        const val TIERS_INTRO_ROUTE = "v1/tiers/intro"

        // Webview handoff — the tiering routes are bifrost webview PATHS, not native
        // Flutter routes; they open via the generic `/app-web-view` page carrying the
        // path as `webviewPath` (Dart builds the URL). Mirrors ProfileFlutterRoutes /
        // HomeTabContent. `title` matches Flutter ApplicableTieringNudge `_webViewTitle`.
        const val APP_WEB_VIEW_ROUTE = "/app-web-view"
        const val WEBVIEW_PATH_ARG = "webviewPath"
        const val WEBVIEW_TITLE_ARG = "title"
        // Webview app-bar titles (Flutter parity): most tiering surfaces open "Snabbit
        // Udaan"; the app-bar tier badge opens "Levels Home". The banner's title is the
        // one Flutter localizes (WEBVIEW_TITLE_BANNER_KEY).
        const val WEBVIEW_TITLE_UDAAN = "Snabbit Udaan"
        const val WEBVIEW_TITLE_LEVELS_HOME = "Levels Home"
        const val WEBVIEW_TITLE_BANNER_KEY = "snabbit_udaan_banner_webview_title"

        // ECPO-926/927: active-job working states → the client-owned PERFECT_JOB nudge;
        // the check-in state → EARLY_CHECK_IN. Both are shown regardless of the server
        // `tier_nudge` (it ships null mid-job) and are static (no navigation).
        // TODO(ECPO-926/927): confirm these state sets with product/QA.
        val PERFECT_JOB_STATES = setOf(
            "RUNNER_JOB_POST_ACCEPT",
            "RUNNER_ARRIVED",
            "RUNNER_JOB_IN_PROGRESS",
            "RUNNER_POST_CHECKOUT",
        )
        const val CHECK_IN_STATE = "RUNNER_JOB_CHECK_IN"

        const val HOST_RECREATE_KEY = "bottom_nav_shell"
        const val HOST_TAB_ARG = "initialTab"
        const val HOST_TAB_HOME = "Home"
    }
}
