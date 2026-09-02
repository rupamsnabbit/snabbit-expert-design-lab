package com.snabbit.runner.shared.features.tiering.presentation.viewmodel

import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.navigation.DeeplinkResolver
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.navigation.NavigationHost
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.tiering.FakeTieringDataSource
import com.snabbit.runner.shared.features.tiering.domain.model.NudgeTheme
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsData
import com.snabbit.runner.shared.features.tiering.domain.model.TierNudge
import com.snabbit.runner.shared.features.tiering.domain.model.TieringProfile
import com.snabbit.runner.shared.features.tiering.presentation.TieringAnalytics
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringNudgeContent
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringUiIntent
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Covers [TieringViewModel] routing (coins card / job row / themed row / none),
 * the visibility gates (mirroring Flutter `shouldShowTiering` + the pre-intro
 * banner gate), the client-owned route map (server `navigation_route` ignored),
 * the tier-specific theme override, and the click/impression intents.
 *
 * A tiering-eligible runner is `hasViewedIntro = true` + `isTieringEnabled = true`
 * (the post-intro master gate); the banner is the pre-intro mirror.
 *
 * The VM's `init` runs a never-completing `combine().collect` on `viewModelScope`
 * (== `Dispatchers.Main`), so Main is redirected to an [UnconfinedTestDispatcher]
 * (init settles eagerly) and every created VM's scope is cancelled in [vmTest]'s
 * `finally` — before `runTest` asserts the scheduler is idle.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TieringViewModelTest {

    private val activeVms = mutableListOf<TieringViewModel>()

    /** A tiering-eligible runner (post-intro master gate satisfied). */
    private fun eligible(tier: Tier? = null) =
        TieringProfile(tier = tier, hasViewedIntro = true, isTieringEnabled = true, serviceId = 1)

    private fun vmTest(body: suspend TestScope.() -> Unit) = runTest {
        Dispatchers.setMain(UnconfinedTestDispatcher(testScheduler))
        try {
            body()
        } finally {
            activeVms.forEach { it.viewModelScope.cancel() }
            activeVms.clear()
            Dispatchers.resetMain()
        }
    }

    /**
     * Records the keep-host handoff so click tests can assert the webview target.
     * Tiering opens the generic `/app-web-view` page carrying the bifrost path in
     * `webviewPath`, so [routes] holds the (constant) page route and [webviewPaths]
     * holds the actual per-nudge destination the assertions care about.
     */
    private class RecordingNavigationHost : NavigationHost {
        val routes = mutableListOf<String>()
        val webviewPaths = mutableListOf<String>()
        override val isRootShell = false
        override fun openFlutterRoute(route: String, args: Map<String, String>) = Unit
        override fun openFlutterRouteKeepingHost(
            route: String,
            args: Map<String, String>,
            recreateKey: String,
            recreateArgs: Map<String, String>,
        ) {
            routes += route
            args["webviewPath"]?.let { webviewPaths += it }
        }

        override fun finishWithResult(result: Map<String, String>) = Unit
        override fun exit() = Unit
    }

    private class Wired(
        val analytics: FakeAnalyticsTracker,
        val navHost: RecordingNavigationHost,
        val vm: TieringViewModel,
    )

    private fun wire(
        nudge: TierNudge? = null,
        profile: TieringProfile = TieringProfile(),
        coins: TierCoinsData? = null,
        widgetName: String? = null,
    ): Wired {
        val ds = FakeTieringDataSource(
            nudgeFlow = MutableStateFlow(nudge),
            profileFlow = MutableStateFlow(profile),
            widgetNameFlow = MutableStateFlow(widgetName),
            coinsResult = coins,
        )
        val analytics = FakeAnalyticsTracker()
        val navHost = RecordingNavigationHost()
        val nav = NavigationController(
            deeplinkResolver = DeeplinkResolver(emptyList()),
            logger = FakeLogger(),
            crashReporter = CrashReporter { _, _ -> },
        ).also { it.host = navHost }
        // Empty store → English fallbacks (the same text the surfaces render pre-bundle).
        val store = LocalizationStore(FakeLogger(), CrashReporter { _, _ -> })
        val vm = TieringViewModel(ds, TieringAnalytics(analytics), store, nav).also { activeVms += it }
        return Wired(analytics, navHost, vm)
    }

    // ── Routing ────────────────────────────────────────────────

    @Test
    fun `THE_COIN_NUDGE with tier and coins renders the coins card`() = vmTest {
        val data = TierCoinsData(coinBalance = 1250)
        val content = wire(
            nudge = TierNudge(nudgeName = "THE_COIN_NUDGE"),
            profile = eligible(Tier.GOLD),
            coins = data,
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.CoinsCard>(content)
        assertEquals(Tier.GOLD, content.tier)
        assertEquals(data, content.data)
    }

    @Test
    fun `THE_COIN_NUDGE without a tier renders nothing`() = vmTest {
        val content = wire(
            nudge = TierNudge(nudgeName = "THE_COIN_NUDGE"),
            profile = eligible(tier = null),
            coins = TierCoinsData(),
        ).vm.uiState.value.homeNudge
        assertNull(content)
    }

    @Test
    fun `job nudge renders the coin-chip row with coin_amount`() = vmTest {
        val details = buildJsonObject { put("coin_amount", 2) }
        val content = wire(
            nudge = TierNudge(nudgeName = "PERFECT_JOB", nudgeDetails = details),
            profile = eligible(),
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Job>(content)
        assertEquals(2, content.coinsCount)
        assertEquals("Do a perfect job to earn Snabbit Coins", content.title)
    }

    @Test
    fun `job nudge with a zero coin_amount hides the coin chip`() = vmTest {
        // ECPO-1022: a 0 (non-positive) reward is treated like an absent one — the
        // Job content carries a null count so the chip renders nothing.
        val details = buildJsonObject { put("coin_amount", 0) }
        val content = wire(
            nudge = TierNudge(nudgeName = "PERFECT_JOB", nudgeDetails = details),
            profile = eligible(),
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Job>(content)
        assertNull(content.coinsCount)
    }

    @Test
    fun `other nudge renders the themed row with hard-coded copy`() = vmTest {
        val content = wire(
            nudge = TierNudge(nudgeName = "REFER_AND_EARN"),
            profile = eligible(),
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Themed>(content)
        assertEquals("Refer and earn more", content.title)
        assertEquals("tiering_nudge_refer_and_earn", content.titleKey)
        assertTrue(content.iconUrl.isNotEmpty())
    }

    @Test
    fun `SHOWING_TIER forces the tier-specific theme so the icon is the tier badge`() = vmTest {
        // Wire theme is GENERIC, but SHOWING_TIER / WEEKLY_TIER_SUMMARY are always
        // rendered tier-specific — the leading asset is the runner's tier badge.
        val content = wire(
            nudge = TierNudge(nudgeName = "SHOWING_TIER", theme = NudgeTheme.GENERIC),
            profile = eligible(Tier.GOLD),
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Themed>(content)
        assertTrue(content.iconUrl.contains("gold_tier"), "expected the tier badge, got ${content.iconUrl}")
    }

    @Test
    fun `null nudge yields no home nudge`() = vmTest {
        assertNull(wire(nudge = null, profile = eligible()).vm.uiState.value.homeNudge)
    }

    // ── Visibility gates (mirror Flutter shouldShowTiering) ─────

    @Test
    fun `nudge is hidden until the tier intro is accepted`() = vmTest {
        // ECPO-924: pre-intro (hasViewedIntro=false) the nudge is suppressed even
        // for a tiering-enabled runner; once accepted it renders.
        val nudge = TierNudge(nudgeName = "REFER_AND_EARN")
        assertNull(
            wire(nudge = nudge, profile = TieringProfile(hasViewedIntro = false, isTieringEnabled = true, serviceId = 1))
                .vm.uiState.value.homeNudge,
        )
        assertIs<TieringNudgeContent.Themed>(
            wire(nudge = nudge, profile = eligible()).vm.uiState.value.homeNudge,
        )
    }

    @Test
    fun `nudge is hidden until tiering is live for the runner`() = vmTest {
        // Rollout gate: intro accepted but tiering not yet live (isTieringEnabled=false).
        assertNull(
            wire(
                nudge = TierNudge(nudgeName = "REFER_AND_EARN"),
                profile = TieringProfile(hasViewedIntro = true, isTieringEnabled = false, serviceId = 1),
            ).vm.uiState.value.homeNudge,
        )
    }

    @Test
    fun `nudge and banner are hidden for a non-service-1 runner`() = vmTest {
        // Eligibility half of shouldShowTiering: serviceId must be 1.
        assertNull(
            wire(
                nudge = TierNudge(nudgeName = "REFER_AND_EARN"),
                profile = TieringProfile(hasViewedIntro = true, isTieringEnabled = true, serviceId = 2),
            ).vm.uiState.value.homeNudge,
        )
        assertFalse(
            wire(profile = TieringProfile(hasViewedIntro = false, isTieringEnabled = true, serviceId = 2))
                .vm.uiState.value.showUdaanBanner,
        )
    }

    @Test
    fun `nudge and banner are hidden for a suspended runner`() = vmTest {
        assertNull(
            wire(
                nudge = TierNudge(nudgeName = "REFER_AND_EARN"),
                profile = TieringProfile(hasViewedIntro = true, isTieringEnabled = true, serviceId = 1, isSuspended = true),
            ).vm.uiState.value.homeNudge,
        )
        assertFalse(
            wire(profile = TieringProfile(hasViewedIntro = false, isTieringEnabled = true, serviceId = 1, isSuspended = true))
                .vm.uiState.value.showUdaanBanner,
        )
    }

    @Test
    fun `banner opens the funnel to any service-1 runner pre-intro, even before tiering is live`() = vmTest {
        // Release pivot: the banner DROPPED the effective-date gate, so it shows for a
        // service-1, non-suspended, pre-intro runner even when tiering isn't live yet
        // (isTieringEnabled=false) — letting legacy / not-yet-live runners enter the funnel.
        assertTrue(
            wire(profile = TieringProfile(hasViewedIntro = false, isTieringEnabled = false, serviceId = 1))
                .vm.uiState.value.showUdaanBanner,
        )
        // Still shows when tiering IS live.
        assertTrue(
            wire(profile = TieringProfile(hasViewedIntro = false, isTieringEnabled = true, serviceId = 1))
                .vm.uiState.value.showUdaanBanner,
        )
        // Hidden once the intro is viewed.
        assertFalse(wire(profile = eligible()).vm.uiState.value.showUdaanBanner)
        // Hidden for a non-service-1 runner (serviceId defaults to null here).
        assertFalse(
            wire(profile = TieringProfile(hasViewedIntro = false, isTieringEnabled = false))
                .vm.uiState.value.showUdaanBanner,
        )
    }

    @Test
    fun `profile tier card gates on tier identity alone — no effective-date or intro gate`() = vmTest {
        // Release fix: the profile card shows for ANY new-scheme tier the instant `tier`
        // updates — independent of the effective date (isTieringEnabled) AND the intro.
        assertEquals(
            Tier.SILVER,
            wire(profile = eligible(Tier.SILVER)).vm.uiState.value.profileTierCard?.tier,
        )
        // Not live yet (isTieringEnabled=false) → STILL shows (this is the bug being fixed).
        assertEquals(
            Tier.SILVER,
            wire(profile = TieringProfile(tier = Tier.SILVER, hasViewedIntro = true, isTieringEnabled = false, serviceId = 1))
                .vm.uiState.value.profileTierCard?.tier,
        )
        // Intro not accepted → STILL shows (card is tier-identity only).
        assertEquals(
            Tier.SILVER,
            wire(profile = TieringProfile(tier = Tier.SILVER, hasViewedIntro = false, isTieringEnabled = false))
                .vm.uiState.value.profileTierCard?.tier,
        )
        // Legacy tiers (BASIC / PRO / ELITE) → no card.
        assertNull(wire(profile = eligible(Tier.PRO)).vm.uiState.value.profileTierCard)
        assertNull(wire(profile = eligible(Tier.BASIC)).vm.uiState.value.profileTierCard)
    }

    @Test
    fun `isTieringEnabled surfaces the effective-date flag (drives the profile insurance split)`() = vmTest {
        assertTrue(wire(profile = eligible(Tier.SILVER)).vm.uiState.value.isTieringEnabled)
        assertFalse(
            wire(profile = TieringProfile(tier = Tier.SILVER, hasViewedIntro = true, isTieringEnabled = false, serviceId = 1))
                .vm.uiState.value.isTieringEnabled,
        )
    }

    @Test
    fun `app-bar tier badge keeps the full date-based gate (unlike the profile card)`() = vmTest {
        // TierBadgeV2 was NOT migrated: it stays on shouldShowTiering, so it can lag the card.
        assertEquals(
            Tier.SILVER,
            wire(profile = eligible(Tier.SILVER)).vm.uiState.value.tierBadge?.tier,
        )
        // Not live yet → badge hidden (even though the profile card shows).
        assertNull(
            wire(profile = TieringProfile(tier = Tier.SILVER, hasViewedIntro = true, isTieringEnabled = false, serviceId = 1))
                .vm.uiState.value.tierBadge,
        )
        // Intro not accepted → badge hidden.
        assertNull(
            wire(profile = TieringProfile(tier = Tier.SILVER, hasViewedIntro = false, isTieringEnabled = true, serviceId = 1))
                .vm.uiState.value.tierBadge,
        )
        // Legacy tier → hidden.
        assertNull(wire(profile = eligible(Tier.PRO)).vm.uiState.value.tierBadge)
    }

    @Test
    fun `nudge is hidden for a legacy-tier runner (even when otherwise eligible)`() = vmTest {
        // Release additive guard: shouldShowTiering AND NOT a legacy tier. A promoted-but-
        // still-legacy runner (BASIC/PRO/ELITE) never sees the nudge.
        assertNull(
            wire(nudge = TierNudge(nudgeName = "REFER_AND_EARN"), profile = eligible(Tier.PRO))
                .vm.uiState.value.homeNudge,
        )
        assertNull(
            wire(nudge = TierNudge(nudgeName = "REFER_AND_EARN"), profile = eligible(Tier.BASIC))
                .vm.uiState.value.homeNudge,
        )
        // A new-scheme tier still gets it.
        assertIs<TieringNudgeContent.Themed>(
            wire(nudge = TierNudge(nudgeName = "REFER_AND_EARN"), profile = eligible(Tier.GOLD))
                .vm.uiState.value.homeNudge,
        )
    }

    // ── Client-owned routing (server navigation_route ignored) ──

    @Test
    fun `nudge click uses the client route, not the server navigation_route`() = vmTest {
        val w = wire(
            // Server sends a junk route; the client map wins.
            nudge = TierNudge(nudgeName = "REFER_AND_EARN", navigationRoute = "/server/ignored"),
            profile = eligible(),
        )
        w.vm.onIntent(TieringUiIntent.NudgeClicked)
        assertTrue("tiering_nudge_clicked" in w.analytics.trackedNames)
        // Opens the generic webview page carrying the client route as `webviewPath`.
        assertEquals(listOf("/app-web-view"), w.navHost.routes)
        assertEquals(listOf("v1/referrals/home"), w.navHost.webviewPaths)
    }

    @Test
    fun `coins card click opens the tiers-coins route`() = vmTest {
        val w = wire(
            nudge = TierNudge(nudgeName = "THE_COIN_NUDGE", navigationRoute = "/server/ignored"),
            profile = eligible(Tier.GOLD),
            coins = TierCoinsData(),
        )
        w.vm.onIntent(TieringUiIntent.NudgeClicked)
        assertEquals(listOf("v1/tiers/coins"), w.navHost.webviewPaths)
    }

    // ── Dynamic (backend-driven) nudge — unknown nudge_name ─────
    // A nudge_name the client has no case for honours the wire navigation_route +
    // image_url and localises its raw name, so the backend can ship a new nudge
    // (image + web route) without an app release.

    @Test
    fun `a dynamic nudge honours the wire navigation_route`() = vmTest {
        val w = wire(
            nudge = TierNudge(nudgeName = "LUNCH_SELECTION", navigationRoute = "/v1/lunch"),
            profile = eligible(),
        )
        w.vm.onIntent(TieringUiIntent.NudgeClicked)
        assertTrue("tiering_nudge_clicked" in w.analytics.trackedNames)
        assertEquals(listOf("/app-web-view"), w.navHost.routes)
        // The wire route is carried verbatim as `webviewPath` (Dart's buildWebviewUrl
        // normalises the leading slash).
        assertEquals(listOf("/v1/lunch"), w.navHost.webviewPaths)
    }

    @Test
    fun `a KNOWN route-less benefit ignores the wire navigation_route`() = vmTest {
        // The wire-route fallback is gated on isDynamicNudge (genuinely-unknown names) — NOT on
        // routeFor==null. A known benefit the client deliberately left route-less must stay
        // non-tappable even when the server attaches a navigation_route.
        val w = wire(
            nudge = TierNudge(nudgeName = "LUNCH_FLEXIBILITY", navigationRoute = "/wire/anything"),
            profile = eligible(),
        )
        w.vm.onIntent(TieringUiIntent.NudgeClicked)
        assertTrue(w.navHost.webviewPaths.isEmpty())
        assertFalse("tiering_nudge_clicked" in w.analytics.trackedNames)
    }

    @Test
    fun `a server job nudge outside a job state stays non-tappable`() = vmTest {
        // ECPO-927: PERFECT_JOB / EARLY_CHECK_IN are static. A server-sent PERFECT_JOB on a
        // NON-job widget state must NOT pick up the wire route (that would give a tappable row
        // with no chevron — PR #610 suppresses the job-row chevron precisely because it's
        // non-navigable).
        val w = wire(
            nudge = TierNudge(nudgeName = "PERFECT_JOB", navigationRoute = "/wire/anything"),
            profile = eligible(),
            widgetName = null, // not a job-cycle state
        )
        w.vm.onIntent(TieringUiIntent.NudgeClicked)
        assertTrue(w.navHost.webviewPaths.isEmpty())
        assertFalse("tiering_nudge_clicked" in w.analytics.trackedNames)
    }

    @Test
    fun `a dynamic nudge renders the wire image and localises its raw name`() = vmTest {
        val content = wire(
            nudge = TierNudge(
                nudgeName = "LUNCH_SELECTION",
                navigationRoute = "/v1/lunch",
                imageUrl = "https://cdn.snabbit.com/lunch.svg",
            ),
            profile = eligible(),
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Themed>(content)
        assertEquals("https://cdn.snabbit.com/lunch.svg", content.iconUrl)
        // Empty loc store → the raw nudge_name is both the localization key and the
        // fallback title (a bundled translation for the key would replace the text).
        assertEquals("LUNCH_SELECTION", content.titleKey)
        assertEquals("LUNCH_SELECTION", content.title)
    }

    @Test
    fun `a dynamic nudge tints its image only when the wire sent a theme`() = vmTest {
        val themed = wire(
            nudge = TierNudge(
                nudgeName = "LUNCH_SELECTION",
                imageUrl = "https://cdn.snabbit.com/lunch.svg",
                theme = NudgeTheme.BENEFITS,
                themeProvided = true,
            ),
            profile = eligible(),
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Themed>(themed)
        assertTrue(themed.tintImage)

        val themeless = wire(
            nudge = TierNudge(
                nudgeName = "LUNCH_SELECTION",
                imageUrl = "https://cdn.snabbit.com/lunch.svg",
                themeProvided = false,
            ),
            profile = eligible(),
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Themed>(themeless)
        assertFalse(themeless.tintImage)
    }

    @Test
    fun `a known nudge always tints, even when the wire sent no theme`() = vmTest {
        // The dynamic no-theme rule is scoped to unknown names; a known nudge's leading
        // asset is a monochrome glyph that must stay tinted regardless of themeProvided.
        val content = wire(
            nudge = TierNudge(nudgeName = "REFER_AND_EARN", themeProvided = false),
            profile = eligible(),
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Themed>(content)
        assertTrue(content.tintImage)
    }

    @Test
    fun `nudge shown fires the viewed impression`() = vmTest {
        val w = wire(nudge = TierNudge(nudgeName = "REFER_AND_EARN"), profile = eligible())
        w.vm.onIntent(TieringUiIntent.NudgeShown)
        assertTrue("tiering_nudge_viewed" in w.analytics.trackedNames)
    }

    @Test
    fun `repeated nudge-shown for the same nudge logs a single impression`() = vmTest {
        // PR #570: the same nudge is composed by more than one host (Home + the in-job overlay)
        // and re-fires NudgeShown on every tab re-entry; the VM de-dups by nudge identity so
        // `tiering_nudge_viewed` is logged once per on-screen nudge, not once per host / revisit.
        val w = wire(nudge = TierNudge(nudgeName = "REFER_AND_EARN"), profile = eligible())
        w.vm.onIntent(TieringUiIntent.NudgeShown)
        w.vm.onIntent(TieringUiIntent.NudgeShown)
        w.vm.onIntent(TieringUiIntent.NudgeShown)
        assertEquals(1, w.analytics.trackedNames.count { it == "tiering_nudge_viewed" })
    }

    @Test
    fun `banner click fires analytics and opens the tiers home route`() = vmTest {
        val w = wire(profile = TieringProfile(hasViewedIntro = false, isTieringEnabled = true, serviceId = 1))
        w.vm.onIntent(TieringUiIntent.BannerClicked(showHeaderImage = true))
        assertTrue("tiering_udaan_banner_clicked" in w.analytics.trackedNames)
        assertEquals(listOf("v1/tiers/home"), w.navHost.webviewPaths)
    }

    @Test
    fun `profile tier click fires analytics and opens the tiers home route`() = vmTest {
        val w = wire(profile = eligible(Tier.SILVER))
        w.vm.onIntent(TieringUiIntent.ProfileTierClicked)
        assertTrue("tiering_view_tier_drawer_clicked" in w.analytics.trackedNames)
        assertEquals(listOf("v1/tiers/home"), w.navHost.webviewPaths)
    }

    // ── Post-intro "Play video" row (profile card) ──────────────

    @Test
    fun `play-video row shows post-intro for a service-1 runner above BASE, even before tiering is live`() = vmTest {
        // Release gate: hasViewedIntro && service-1 && !suspended && tier != BASE. No
        // effective-date gate — so a not-yet-live (isTieringEnabled=false) runner still sees it.
        val w = wire(profile = TieringProfile(tier = Tier.SILVER, hasViewedIntro = true, isTieringEnabled = false, serviceId = 1))
        assertTrue(w.vm.uiState.value.showUdaanPlayVideoRow)
        // It replaces the banner, so the pre-intro banner is gone.
        assertFalse(w.vm.uiState.value.showUdaanBanner)
    }

    @Test
    fun `play-video row is hidden pre-intro — the banner shows instead`() = vmTest {
        val w = wire(profile = TieringProfile(tier = Tier.SILVER, hasViewedIntro = false, isTieringEnabled = true, serviceId = 1))
        assertFalse(w.vm.uiState.value.showUdaanPlayVideoRow)
        assertTrue(w.vm.uiState.value.showUdaanBanner)
    }

    @Test
    fun `play-video row is hidden for a BASE-tier runner`() = vmTest {
        assertFalse(wire(profile = eligible(Tier.BASE)).vm.uiState.value.showUdaanPlayVideoRow)
    }

    @Test
    fun `play-video row shows for a legacy non-BASE tier (gate is tier != BASE, not isLegacy)`() = vmTest {
        // The release play-video gate excludes ONLY BASE — legacy PRO/ELITE (!= BASE) still
        // see the replay row (they can re-watch the intro), unlike the nudge/card.
        assertTrue(wire(profile = eligible(Tier.PRO)).vm.uiState.value.showUdaanPlayVideoRow)
    }

    @Test
    fun `play-video row is hidden for a non-service-1 or suspended runner`() = vmTest {
        assertFalse(
            wire(profile = TieringProfile(tier = Tier.SILVER, hasViewedIntro = true, serviceId = 2))
                .vm.uiState.value.showUdaanPlayVideoRow,
        )
        assertFalse(
            wire(profile = TieringProfile(tier = Tier.SILVER, hasViewedIntro = true, serviceId = 1, isSuspended = true))
                .vm.uiState.value.showUdaanPlayVideoRow,
        )
    }

    @Test
    fun `play-video click opens the tiers INTRO webview and logs nothing`() = vmTest {
        val w = wire(profile = eligible(Tier.SILVER))
        w.vm.onIntent(TieringUiIntent.PlayVideoClicked)
        // Re-opens the intro (v1/tiers/intro), NOT the tiers home the other surfaces use.
        assertEquals(listOf("/app-web-view"), w.navHost.routes)
        assertEquals(listOf("v1/tiers/intro"), w.navHost.webviewPaths)
        // Nav-only — no analytics (Flutter parity).
        assertTrue(w.analytics.trackedNames.isEmpty())
    }

    // ── ECPO-926: perfect-job override during active job states ─

    @Test
    fun `active job state forces the perfect-job nudge over a round-robin nudge`() = vmTest {
        val content = wire(
            nudge = TierNudge(nudgeName = "REFER_AND_EARN"),
            profile = eligible(),
            widgetName = "RUNNER_JOB_IN_PROGRESS",
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Job>(content)
        assertEquals("Do a perfect job to earn Snabbit Coins", content.title)
        assertNull(content.coinsCount) // ECPO-1022: no coin_amount → no chip, no default
    }

    @Test
    fun `check-in state shows the early-check-in nudge, honouring the server coin_amount`() = vmTest {
        val details = buildJsonObject { put("coin_amount", 1) }
        val content = wire(
            nudge = TierNudge(nudgeName = "EARLY_CHECK_IN", nudgeDetails = details),
            profile = eligible(),
            widgetName = "RUNNER_JOB_CHECK_IN",
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Job>(content)
        assertEquals("Check in early to earn Snabbit Coins", content.title)
        assertEquals(1, content.coinsCount)
    }

    @Test
    fun `perfect-job nudge shows even when the server sends no tier_nudge mid-job`() = vmTest {
        // The backend ships `tier_nudge: null` in job-state current_state; the job
        // nudge is client-owned and must still show (ECPO-926 regardless-of-server).
        val content = wire(
            nudge = null,
            profile = eligible(),
            widgetName = "RUNNER_JOB_IN_PROGRESS",
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Job>(content)
        assertEquals("Do a perfect job to earn Snabbit Coins", content.title)
        assertNull(content.coinsCount) // ECPO-1022: no coin_amount → no chip, no default
    }

    @Test
    fun `early-check-in nudge shows even when the server sends no tier_nudge`() = vmTest {
        val content = wire(
            nudge = null,
            profile = eligible(),
            widgetName = "RUNNER_JOB_CHECK_IN",
        ).vm.uiState.value.homeNudge
        assertIs<TieringNudgeContent.Job>(content)
        assertEquals("Check in early to earn Snabbit Coins", content.title)
        assertNull(content.coinsCount) // ECPO-1022: no coin_amount → no chip, no default
    }

    @Test
    fun `client-owned job nudge still respects the eligibility gate`() = vmTest {
        // Even with a synthesized (server-less) job nudge, an ineligible runner sees
        // nothing — showTieringSurfaces still gates the whole surface.
        assertNull(
            wire(
                nudge = null,
                profile = TieringProfile(hasViewedIntro = true, isTieringEnabled = false, serviceId = 1),
                widgetName = "RUNNER_JOB_IN_PROGRESS",
            ).vm.uiState.value.homeNudge,
        )
    }

    // ── ECPO-927: nudges are static during the job cycle ───────

    @Test
    fun `nudge is static during the job cycle — click neither navigates nor logs`() = vmTest {
        val w = wire(
            nudge = TierNudge(
                nudgeName = "PERFECT_JOB",
                navigationRoute = "/home/perfect-jobs",
                nudgeDetails = buildJsonObject { put("coin_amount", 2) },
            ),
            profile = eligible(),
            widgetName = "RUNNER_JOB_IN_PROGRESS",
        )
        w.vm.onIntent(TieringUiIntent.NudgeClicked)
        assertTrue(w.navHost.routes.isEmpty())
        assertFalse("tiering_nudge_clicked" in w.analytics.trackedNames)
    }

    @Test
    fun `check-in nudge is also static during the job cycle`() = vmTest {
        val w = wire(
            nudge = TierNudge(
                nudgeName = "EARLY_CHECK_IN",
                navigationRoute = "/home/perfect-jobs",
                nudgeDetails = buildJsonObject { put("coin_amount", 1) },
            ),
            profile = eligible(),
            widgetName = "RUNNER_JOB_CHECK_IN",
        )
        w.vm.onIntent(TieringUiIntent.NudgeClicked)
        assertTrue(w.navHost.routes.isEmpty())
    }
}
