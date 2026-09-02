package com.snabbit.runner.shared.features.home.presentation

import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.features.shift.attendance.FakeAttendanceRepository
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.features.gamification.data.GamificationProjector
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.features.job.data.contact.FakeCallingDataSource
import com.snabbit.runner.shared.features.job.data.contact.FakeCustomerContactLauncher
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.shift.core.data.ShiftProjector
import com.snabbit.runner.shared.features.shift.FakeLocationProvider
import com.snabbit.runner.shared.features.gamification.presentation.postaction.PostActionCoordinator
import com.snabbit.runner.shared.features.shift.FakeShiftRepository
import com.snabbit.runner.shared.features.shift.lunch.FakeLunchRepository
import com.snabbit.runner.shared.features.shift.lunch.data.LunchProjector
import com.snabbit.runner.shared.features.shift.lunch.domain.model.BreakColorState
import com.snabbit.runner.shared.features.shift.core.domain.model.AttendanceStatus
import com.snabbit.runner.shared.core.navigation.DeeplinkResolver
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.navigation.NavigationHost
import com.snabbit.runner.shared.features.home.banners.FakeHomeBannersRemote
import com.snabbit.runner.shared.features.home.banners.data.HomeBannersStore
import com.snabbit.runner.shared.features.home.banners.fakeHomeBannersStore
import com.snabbit.runner.shared.features.home.domain.model.Banner
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.home.domain.model.MapFloatingState
import com.snabbit.runner.shared.features.home.presentation.ui.MapCoords
import com.snabbit.runner.shared.features.home.suspended.FakeSuspendedRepository
import com.snabbit.runner.shared.features.home.seeyoutomorrow.data.SeeYouTomorrowProjector
import com.snabbit.runner.shared.features.home.suspended.data.SuspendedProjector
import com.snabbit.runner.shared.features.home.suspended.domain.model.UnsuspendResult
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import com.snabbit.runner.shared.features.profile.sampleRunnerProfile
import com.snabbit.runner.shared.features.seva.FakeSevaRepository
import com.snabbit.runner.shared.features.seva.domain.model.SevaKind
import com.snabbit.runner.shared.features.seva.domain.model.SevaPoint
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftPhase
import com.snabbit.runner.shared.core.location.LocationProvider
import com.snabbit.runner.shared.core.location.LocationResult
import com.snabbit.runner.shared.core.location.SnabbitLocation
import com.snabbit.runner.shared.core.location.TrackingConfig
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.datetime.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Records analytics `track` calls for assertion; other methods are no-ops. */
private class RecordingAnalytics : AnalyticsTracker {
    val tracked = mutableListOf<String>()
    val events = mutableListOf<Pair<String, Map<String, Any?>>>()
    override fun track(name: String, props: Map<String, Any?>, targets: Set<String>?) {
        tracked += name
        events += name to props
    }
    override fun identify(userId: String?) = Unit
    override fun reset() = Unit
    override fun setUserProperty(key: String, value: Any?) = Unit
    override fun onUserLogin(profile: Map<String, Any?>) = Unit
    override fun setUserProperties(props: Map<String, Any?>) = Unit
}

/** Mutable clock the tests advance by hand (never reads wall time). */
private class TestClock(var nowMs: Long = 0L) : CurrentTimeMs {
    override fun invoke(): Long = nowMs
}

/** Records keep-host Flutter hops so banner-tap tests can assert the route + args. */
private class RecordingNavigationHost : NavigationHost {
    val keepHostRoutes = mutableListOf<Pair<String, Map<String, String>>>()
    override val isRootShell: Boolean = false
    override fun openFlutterRoute(route: String, args: Map<String, String>) = Unit
    override fun openFlutterRouteKeepingHost(
        route: String,
        args: Map<String, String>,
        recreateKey: String,
        recreateArgs: Map<String, String>,
    ) {
        keepHostRoutes += route to args
    }
    override fun finishWithResult(result: Map<String, String>) = Unit
    override fun exit() = Unit
}

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {

    private data class Wired(
        val store: RunnerStateStore,
        val vm: HomeViewModel,
        val repo: FakeAttendanceRepository,
        val lunchRepo: FakeLunchRepository,
        val location: LocationProvider,
        val analytics: RecordingAnalytics,
        val clock: TestClock,
        val sevaRepo: FakeSevaRepository,
        val shiftRepo: FakeShiftRepository,
        val launcher: FakeCustomerContactLauncher,
        val calling: FakeCallingDataSource,
        val suspendedRepo: FakeSuspendedRepository,
        val bannerRepo: FakeHomeBannersRemote,
        val bannerStore: HomeBannersStore,
        val navHost: RecordingNavigationHost,
    )

    /** [LocationProvider] whose [trackLocation] emits one [fix] — lets a test
     *  drive the map-centre + seva-fetch paths that depend on a live GPS fix. */
    private class StreamingLocationProvider(private val fix: SnabbitLocation) : LocationProvider {
        override suspend fun getCurrentLocation(config: TrackingConfig) = LocationResult.Success(fix)
        override suspend fun getLastKnownLocation() = LocationResult.Success(fix)
        override fun trackLocation(config: TrackingConfig): Flow<LocationResult> =
            flowOf(LocationResult.Success(fix))
        override fun stopTracking() = Unit
    }

    /** VMs created during a test, cancelled in [vmTest]'s teardown (their
     *  `viewModelScope` runs never-completing init collects that would otherwise
     *  keep `runTest` from completing). */
    private val activeVms = mutableListOf<HomeViewModel>()

    /**
     * `runTest` wrapper for [HomeViewModel] tests: installs a test [Dispatchers.Main]
     * (so `viewModelScope` runs on the test scheduler) and cancels every VM created via
     * [wire] afterwards — the equivalent of the ViewModel being cleared. Replaces the
     * old "inject `backgroundScope`" trick now that the VM owns its `viewModelScope`.
     */
    private fun vmTest(body: suspend TestScope.() -> Unit) = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            body()
        } finally {
            activeVms.forEach { it.viewModelScope.cancel() }
            activeVms.clear()
            Dispatchers.resetMain()
        }
    }

    /**
     * Wires real use cases backed by a [FakeAttendanceRepository] so the MVI middleware
     * path is exercised end-to-end through the domain layer. The projectors still take
     * [TestScope.backgroundScope] (plain classes with an injected scope); the
     * [HomeViewModel] owns its `viewModelScope` and is registered for teardown.
     */
    private fun wire(
        scope: TestScope,
        location: LocationProvider = FakeLocationProvider(),
        remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, default -> default },
        profileStore: RunnerProfileStore = RunnerProfileStore(FakeLogger()),
        bannerRepo: FakeHomeBannersRemote = FakeHomeBannersRemote(),
        calling: FakeCallingDataSource = FakeCallingDataSource(),
        openRedCardsPage: () -> Unit = {},
        openSaathiSupportPage: () -> Unit = {},
    ): Wired {
        val store = RunnerStateStore(FakeLogger())
        val bg = scope.backgroundScope
        val repo = FakeAttendanceRepository()
        val shiftRepo = FakeShiftRepository()
        val lunchRepo = FakeLunchRepository()
        val sevaRepo = FakeSevaRepository()
        val suspendedRepo = FakeSuspendedRepository()
        val analytics = RecordingAnalytics()
        val clock = TestClock()
        val launcher = FakeCustomerContactLauncher()
        val navHost = RecordingNavigationHost()
        val bannerStore = fakeHomeBannersStore(bannerRepo)
        val nav = NavigationController(
            deeplinkResolver = DeeplinkResolver(emptyList()),
            logger = FakeLogger(),
            crashReporter = CrashReporter { _, _ -> },
        ).also { it.host = navHost }
        val vm = HomeViewModel(
            readModel = ShiftProjector(store, bg, FakeLogger()),
            gamification = GamificationProjector(store, bg, clock, CrashReporter { _, _ -> }),
            attendanceRepository = repo,
            shiftRepository = shiftRepo,
            postActionCoordinator = PostActionCoordinator(),
            lunchReadModel = LunchProjector(store, bg, FakeLogger()),
            lunchRepository = lunchRepo,
            sevaRepository = sevaRepo,
            suspendedReadModel = SuspendedProjector(store, profileStore, bg),
            suspendedRepository = suspendedRepo,
            seeYouTomorrowReadModel = SeeYouTomorrowProjector(store, bg),
            homeBannersStore = bannerStore,
            locationProvider = location,
            analytics = analytics,
            currentTimeMs = clock,
            customerContactLauncher = launcher,
            callingDataSource = calling,
            remoteConfig = remoteConfig,
            // Must be explicit: the default is `defaultLogger()` == AndroidLogger, whose
            // android.util.Log calls throw "not mocked" under the JVM unit-test runner
            // the moment any test exercises a logging path.
            logger = FakeLogger(),
            nav = nav,
            profileStore = profileStore,
            openRedCardsPage = openRedCardsPage,
            openSaathiSupportPage = openSaathiSupportPage,
        )
        activeVms += vm
        return Wired(store, vm, repo, lunchRepo, location, analytics, clock, sevaRepo, shiftRepo, launcher, calling, suspendedRepo, bannerRepo, bannerStore, navHost)
    }

    @Test fun initialState_isPreShift_noCards_bannersSettleToFallback() = vmTest {
        val (_, vm) = wire(this); runCurrent()
        assertEquals(ShiftPhase.PreShift, vm.uiState.value.phase)
        assertTrue(vm.uiState.value.heroCards.isEmpty())
        assertTrue(vm.uiState.value.bodyCards.isEmpty())
        // Default fake returns Ok(empty): the shimmer has settled to the
        // Refer fallback by the time runCurrent() drains the init fetch.
        assertFalse(vm.uiState.value.bannersLoading)
        assertEquals("refer_fallback", vm.uiState.value.moreFromSnabbit.single().id)
    }

    // ── BE-driven banners (LLD docs/design/home-banners) ─────────────────

    /** A valid BE banner for banner-path tests. */
    private fun banner(
        id: String = "promo_1",
        clickPath: String = "/referral-home",
        clickArgs: Map<String, String> = emptyMap(),
    ) = Banner(
        id = id,
        title = "Title",
        subtitle = "Sub",
        ctaLabel = "Go",
        bgImageUrl = "https://cdn.example.com/bg.png",
        clickPath = clickPath,
        clickArgs = clickArgs,
    )

    @Test fun bannersFetchSuccess_replacesShimmer_keepsBeOrder() = vmTest {
        val bannerRepo = FakeHomeBannersRemote(
            result = FakeHomeBannersRemote.ok(
                banners = listOf(FakeHomeBannersRemote.bannerDto("b1"), FakeHomeBannersRemote.bannerDto("b2")),
            ),
        )
        val (_, vm) = wire(this, bannerRepo = bannerRepo); runCurrent()

        assertEquals(listOf("b1", "b2"), vm.uiState.value.moreFromSnabbit.map { it.id })
        assertFalse(vm.uiState.value.bannersLoading)
    }

    /** One state powers Home and the Updates badge: a refresh started anywhere
     *  in the shell (OnAppResumed) must repaint the carousel, not just the dot. */
    @Test fun bannersRefreshedFromTheShell_reachHome() = vmTest {
        val bannerRepo = FakeHomeBannersRemote(
            result = FakeHomeBannersRemote.ok(banners = listOf(FakeHomeBannersRemote.bannerDto("b1"))),
        )
        val wired = wire(this, bannerRepo = bannerRepo); runCurrent()
        assertEquals(listOf("b1"), wired.vm.uiState.value.moreFromSnabbit.map { it.id })

        bannerRepo.result = FakeHomeBannersRemote.ok(
            banners = listOf(FakeHomeBannersRemote.bannerDto("b2")),
        )
        wired.bannerStore.refresh()
        runCurrent()

        assertEquals(listOf("b2"), wired.vm.uiState.value.moreFromSnabbit.map { it.id })
        assertEquals(2, bannerRepo.calls)
    }

    @Test fun bannersFetchError_keepsReferFallback_noSnackbar() = vmTest {
        val bannerRepo = FakeHomeBannersRemote(
            result = Result.Err(FakeHomeBannersRemote.transportError()),
        )
        val wired = wire(this, bannerRepo = bannerRepo)
        val effects = mutableListOf<HomeUiEffect>()
        val job = launch { wired.vm.effects.collect { effects += it } }
        runCurrent()

        assertEquals("refer_fallback", wired.vm.uiState.value.moreFromSnabbit.first().id)
        assertFalse(wired.vm.uiState.value.bannersLoading) // shimmer settled
        assertTrue(effects.isEmpty()) // banners degrade silently — never a snackbar
        job.cancel()
    }

    @Test fun bannersFetchEmpty_fallsBackToRefer() = vmTest {
        val (_, vm) = wire(this, bannerRepo = FakeHomeBannersRemote(result = FakeHomeBannersRemote.ok()))
        runCurrent()

        assertEquals("refer_fallback", vm.uiState.value.moreFromSnabbit.first().id)
        assertFalse(vm.uiState.value.bannersLoading)
    }

    @Test fun laterRefreshFailure_keepsLastGoodList_notFallback() = vmTest {
        val bannerRepo = FakeHomeBannersRemote(result = FakeHomeBannersRemote.ok(banners = listOf(FakeHomeBannersRemote.bannerDto("b1"))))
        val wired = wire(this, bannerRepo = bannerRepo); runCurrent()
        assertEquals(listOf("b1"), wired.vm.uiState.value.moreFromSnabbit.map { it.id })

        bannerRepo.result = Result.Err(FakeHomeBannersRemote.transportError())
        wired.vm.onIntent(HomeUiIntent.Load)
        runCurrent()

        // Failed refetch keeps the last good BE list — no fallback downgrade.
        assertEquals(listOf("b1"), wired.vm.uiState.value.moreFromSnabbit.map { it.id })
    }

    @Test fun loadIntent_refetchesBanners() = vmTest {
        val wired = wire(this); runCurrent()
        assertEquals(1, wired.bannerRepo.calls) // init fetch

        wired.vm.onIntent(HomeUiIntent.Load)
        runCurrent()

        assertEquals(2, wired.bannerRepo.calls)
    }

    @Test fun tapBanner_flutterPath_opensKeepHostRouteWithArgs_andTracks() = vmTest {
        val bannerRepo = FakeHomeBannersRemote(
            result = FakeHomeBannersRemote.ok(
                banners = listOf(
                    FakeHomeBannersRemote.bannerDto(
                        id = "web",
                        clickPath = "/app-web-view",
                        clickArgs = mapOf("webviewPath" to "v1/x"),
                    ),
                ),
            ),
        )
        val wired = wire(this, bannerRepo = bannerRepo); runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapBanner("web"))
        runCurrent()

        assertEquals(
            listOf("/app-web-view" to mapOf("webviewPath" to "v1/x")),
            wired.navHost.keepHostRoutes,
        )
        assertTrue(wired.analytics.tracked.contains("home_banner_clicked"))
        assertTrue(wired.analytics.tracked.contains("home_banner_cta_click"))
    }

    @Test fun tapBanner_fallbackBanner_opensReferralHome() = vmTest {
        // Fetch fails → fallback stays; its tap routes via ProfileRouteDecider —
        // referrals-v2 RC off (default) → the native ReferralsHome page.
        val wired = wire(
            this,
            bannerRepo = FakeHomeBannersRemote(result = Result.Err(FakeHomeBannersRemote.transportError())),
        )
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapBanner("refer_fallback"))
        runCurrent()

        assertEquals("/referral-home", wired.navHost.keepHostRoutes.single().first)
    }

    @Test fun tapBanner_fallbackBanner_referralsV2On_opensWebview() = vmTest {
        // Referrals-v2 RC on → the same webview route as the Profile tile /
        // Refer tab (drawer parity via ProfileRouteDecider), with home_banner
        // attribution.
        val rc = object : RemoteConfigGateway {
            override fun getBool(key: String, default: Boolean) =
                key == "expert_is_referrals_v2_enabled" || default
            override fun getString(key: String, default: String) = default
        }
        val wired = wire(
            this,
            remoteConfig = rc,
            bannerRepo = FakeHomeBannersRemote(result = Result.Err(FakeHomeBannersRemote.transportError())),
        )
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapBanner("refer_fallback"))
        runCurrent()

        val (route, args) = wired.navHost.keepHostRoutes.single()
        assertEquals("/app-web-view", route)
        assertEquals("v1/referrals/home", args["webviewPath"])
        assertEquals("home_banner", args["entryPoint"])
    }

    @Test fun tapBanner_deciderEarnings_rateCardV2_opensMonthlySummaryWebview() = vmTest {
        // `decider:earnings` resolves rate-card v2 AT TAP TIME from runners/me —
        // a v2-effective runner gets the monthly-summary webview, not PayoutHome.
        val profileStore = RunnerProfileStore(FakeLogger()).apply {
            setProfile(sampleRunnerProfile(isRateCardV2Effective = true))
        }
        val bannerRepo = FakeHomeBannersRemote(
            result = FakeHomeBannersRemote.ok(
                banners = listOf(FakeHomeBannersRemote.bannerDto(id = "earn", clickPath = "decider:earnings")),
            ),
        )
        val wired = wire(this, profileStore = profileStore, bannerRepo = bannerRepo); runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapBanner("earn"))
        runCurrent()

        val (route, args) = wired.navHost.keepHostRoutes.single()
        assertEquals("/app-web-view", route)
        assertEquals("v1/payouts/monthly-summary", args["webviewPath"])
    }

    @Test fun tapBanner_deciderEarnings_noV2_opensPayoutHome() = vmTest {
        val bannerRepo = FakeHomeBannersRemote(
            result = FakeHomeBannersRemote.ok(
                banners = listOf(FakeHomeBannersRemote.bannerDto(id = "earn", clickPath = "decider:earnings")),
            ),
        )
        val wired = wire(this, bannerRepo = bannerRepo); runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapBanner("earn"))
        runCurrent()

        assertEquals("/payout-home", wired.navHost.keepHostRoutes.single().first)
    }

    @Test fun tapBanner_unknownOrStalePath_noNavNoCrash() = vmTest {
        val bannerRepo = FakeHomeBannersRemote(
            result = FakeHomeBannersRemote.ok(
                banners = listOf(
                    FakeHomeBannersRemote.bannerDto(id = "weird", clickPath = "not-a-route"),
                    FakeHomeBannersRemote.bannerDto(id = "cmp_unknown", clickPath = "cmp:nope"),
                    FakeHomeBannersRemote.bannerDto(id = "decider_unknown", clickPath = "decider:nope"),
                ),
            ),
        )
        val wired = wire(this, bannerRepo = bannerRepo); runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapBanner("weird"))           // unknown shape → no-op
        wired.vm.onIntent(HomeUiIntent.TapBanner("cmp_unknown"))     // reserved cmp: scheme (unimplemented) → no-op
        wired.vm.onIntent(HomeUiIntent.TapBanner("decider_unknown")) // unknown decider key → no-op
        wired.vm.onIntent(HomeUiIntent.TapBanner("stale_id"))        // not in list → no-op
        runCurrent()

        assertTrue(wired.navHost.keepHostRoutes.isEmpty())
    }

    /** RC gateway returning [number] for the Saathi helpline key, defaults for everything else.
     *  [supportWebview] flips `expert_enable_saathi_ticketing`. */
    private fun saathiRc(number: String, supportWebview: Boolean = false) = object : RemoteConfigGateway {
        override fun getBool(key: String, default: Boolean) =
            if (key == "expert_enable_saathi_ticketing") supportWebview else default
        override fun getString(key: String, default: String) =
            if (key == "expert_saathi_helpline_number") number else default
    }

    @Test fun tapSaathi_ivrSuccess_initiatesCall_noDialer_showsInitiated() = vmTest {
        // IVR 2xx → the backend places the call; NO dialer opens; success feedback shows (Flutter parity).
        val wired = wire(this, remoteConfig = saathiRc("+919876500000"), calling = FakeCallingDataSource(result = true))
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapSaathi)
        runCurrent()

        assertEquals(listOf("+919876500000"), wired.calling.calls)
        assertTrue(wired.launcher.dialed.isEmpty())
        assertEquals(SaathiCallFeedback.CallInitiated, wired.vm.uiState.value.saathiCallFeedback)
        assertTrue(wired.analytics.tracked.contains("home_saathi_button_clicked"))
        assertTrue(wired.analytics.tracked.contains("top_bar_cta_click"))
    }

    @Test fun tapSaathi_ivrFailure_fallsBackToDialer_noFeedback() = vmTest {
        // Non-2xx → fall back to the device dialer (prior behaviour); no success toast on the fallback.
        val wired = wire(this, remoteConfig = saathiRc("+919876500000"), calling = FakeCallingDataSource(result = false))
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapSaathi)
        runCurrent()

        assertEquals(listOf("+919876500000"), wired.calling.calls)
        assertEquals(listOf("+919876500000"), wired.launcher.dialed)
        assertNull(wired.vm.uiState.value.saathiCallFeedback)
    }

    @Test fun tapSaathi_ivrThrows_fallsBackToDialer() = vmTest {
        // A thrown transport error is caught (catch-Throwable→false) → dialer fallback, no crash.
        val wired = wire(this, remoteConfig = saathiRc("+919876500000"), calling = FakeCallingDataSource(error = RuntimeException("boom")))
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapSaathi)
        runCurrent()

        assertEquals(listOf("+919876500000"), wired.calling.calls)
        assertEquals(listOf("+919876500000"), wired.launcher.dialed)
        assertNull(wired.vm.uiState.value.saathiCallFeedback)
    }

    @Test fun tapSaathi_blankNumber_showsUnavailable_noPost_noDial() = vmTest {
        // Blank RC number → graceful "unavailable" feedback, never a POST or a blank dial (Flutter guard).
        val wired = wire(this, remoteConfig = saathiRc(""))
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapSaathi)
        runCurrent()

        assertTrue(wired.calling.calls.isEmpty())
        assertTrue(wired.launcher.dialed.isEmpty())
        assertEquals(SaathiCallFeedback.NumberUnavailable, wired.vm.uiState.value.saathiCallFeedback)
        assertTrue(wired.analytics.tracked.contains("home_saathi_button_clicked"))
    }

    @Test fun tapSaathi_doubleTap_placesSingleCall() = vmTest {
        // Single-flight guard: a second tap while the IVR POST is still in flight is ignored.
        val wired = wire(this, remoteConfig = saathiRc("+919876500000"), calling = FakeCallingDataSource(result = true))
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapSaathi)   // launches the POST job (body not yet run)
        wired.vm.onIntent(HomeUiIntent.TapSaathi)   // guarded out — saathiCallJob still active
        runCurrent()

        assertEquals(1, wired.calling.calls.size)
    }

    @Test fun tapSaathi_webviewFlagOn_opensSupportWebview_noCall_noDialer() = vmTest {
        // Flag ON → the pill routes to the v1/support webview; the IVR/dialer path never runs.
        var opened = 0
        val wired = wire(
            this,
            remoteConfig = saathiRc("+919876500000", supportWebview = true),
            calling = FakeCallingDataSource(result = true),
            openSaathiSupportPage = { opened++ },
        )
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapSaathi)
        runCurrent()

        assertEquals(1, opened)
        assertTrue(wired.calling.calls.isEmpty())
        assertTrue(wired.launcher.dialed.isEmpty())
        assertNull(wired.vm.uiState.value.saathiCallFeedback)
        assertTrue(wired.analytics.tracked.contains("home_saathi_button_clicked"))
        assertTrue(wired.analytics.tracked.contains("top_bar_cta_click"))
    }

    @Test fun tapSaathi_webviewFlagOn_blankNumber_stillOpensWebview() = vmTest {
        // The webview path is independent of the helpline number — a blank/absent RC number
        // must not surface the "unavailable" toast once the flag is on.
        var opened = 0
        val wired = wire(
            this,
            remoteConfig = saathiRc("", supportWebview = true),
            openSaathiSupportPage = { opened++ },
        )
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapSaathi)
        runCurrent()

        assertEquals(1, opened)
        assertNull(wired.vm.uiState.value.saathiCallFeedback)
    }

    @Test fun tapSaathi_rcUnavailable_keepsIvrCall_pillNeverDark() = vmTest {
        // Safe default: a gateway that resolves every key to the caller's default (RC down / not
        // yet mirrored) keeps the shipped IVR behaviour rather than routing to the webview.
        var opened = 0
        val wired = wire(
            this,
            calling = FakeCallingDataSource(result = true),
            openSaathiSupportPage = { opened++ },
        )
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapSaathi)
        runCurrent()

        assertEquals(0, opened)
        assertEquals(listOf("02244582683"), wired.calling.calls)
        assertEquals(SaathiCallFeedback.CallInitiated, wired.vm.uiState.value.saathiCallFeedback)
    }

    @Test fun saathiCallFeedbackShown_clearsFeedback() = vmTest {
        val wired = wire(this, remoteConfig = saathiRc(""))
        runCurrent()

        wired.vm.onIntent(HomeUiIntent.TapSaathi)   // blank → NumberUnavailable feedback
        runCurrent()
        assertEquals(SaathiCallFeedback.NumberUnavailable, wired.vm.uiState.value.saathiCallFeedback)

        wired.vm.onIntent(HomeUiIntent.SaathiCallFeedbackShown)
        runCurrent()
        assertNull(wired.vm.uiState.value.saathiCallFeedback)
    }

    @Test fun homeScrolled_tracksHomeScreenScrolled() = vmTest {
        val wired = wire(this); runCurrent()
        wired.vm.onIntent(HomeUiIntent.HomeScrolled)
        runCurrent()
        assertTrue(wired.analytics.tracked.contains("home_screen_scrolled"))
    }

    @Test fun pushedTomorrowEnvelope_rendersTomorrowCardInHero() = vmTest {
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_TOMORROW","widget_data":{
              "date":"Tue, 7 Feb","shift_time":"7am-12pm",
              "earning_loss_amount":800,"is_next_working_day_sunday":false}}
        """.trimIndent())
        runCurrent()
        val card = assertIs<HomeCard.Attendance.TomorrowProvisional>(vm.uiState.value.heroCards.single())
        assertEquals("Tue, 7 Feb", card.day.dateLabel)
        assertEquals("₹800", card.day.potentialEarnLabel)
    }

    @Test fun load_callsStoreRequestRefresh() = vmTest {
        val (store, vm) = wire(this)
        var refreshes = 0; store.bind { refreshes++ }
        vm.onIntent(HomeUiIntent.Load)
        assertEquals(1, refreshes)
    }

    @Test fun gamificationTotals_foldIntoCounts() = vmTest {
        val (store, vm) = wire(this)
        store.pushState("""{"widget_name":"X","widget_data":{},"gold_coins_total":61,"red_cards_total":3}""")
        runCurrent()
        assertEquals(61, vm.uiState.value.coinsCount)
        assertEquals(3, vm.uiState.value.redCardsCount)
    }

    @Test fun gamificationTotals_holdWhenEnvelopeOmitsThem() = vmTest {
        val (store, vm) = wire(this)
        store.pushState("""{"widget_name":"X","widget_data":{},"gold_coins_total":61,"red_cards_total":3}""")
        runCurrent()
        // A later envelope (e.g. an MQTT/widget update) drops the gamification
        // siblings — the counts must hold, not flicker to 0.
        store.pushState("""{"widget_name":"Y","widget_data":{}}""")
        runCurrent()
        assertEquals(61, vm.uiState.value.coinsCount)
        assertEquals(3, vm.uiState.value.redCardsCount)
    }

    @Test fun tapRedCards_firesAnalyticsAndOpensPage() = vmTest {
        var opened = 0
        val wired = wire(this, openRedCardsPage = { opened++ })
        wired.vm.onIntent(HomeUiIntent.TapRedCards)
        runCurrent()
        assertEquals(1, opened)
        assertTrue(wired.analytics.events.any { (name, props) ->
            name == "top_bar_cta_click" && props["cta_text"] == "red_cards"
        })
    }

    // ── Rewards-pill visibility gate (coins + red card) ──────────────────

    /** V2 profile — the gate-open baseline. */
    private fun v2Profile() = sampleRunnerProfile(rateCardVersion = "V2")

    private val redCardRcOn = RemoteConfigGateway { key, default ->
        if (key == "expert_show_red_card_pill") true else default
    }

    @Test fun rewardsGate_opensForV2NotSuspended() = vmTest {
        val profileStore = RunnerProfileStore(FakeLogger())
        val (_, vm) = wire(this, profileStore = profileStore, remoteConfig = redCardRcOn)
        profileStore.setProfile(v2Profile())
        runCurrent()
        assertTrue(vm.uiState.value.rewardsPillsVisible)
        assertTrue(vm.uiState.value.redCardPillVisible)
    }

    @Test fun rewardsGate_closedBeforeProfileLoads() = vmTest {
        val (_, vm) = wire(this, remoteConfig = redCardRcOn)
        runCurrent()
        assertFalse(vm.uiState.value.rewardsPillsVisible)
        assertFalse(vm.uiState.value.redCardPillVisible)
    }

    @Test fun rewardsGate_closedOnRateCardV1() = vmTest {
        val profileStore = RunnerProfileStore(FakeLogger())
        val (_, vm) = wire(this, profileStore = profileStore, remoteConfig = redCardRcOn)
        profileStore.setProfile(sampleRunnerProfile(rateCardVersion = null))
        runCurrent()
        assertFalse(vm.uiState.value.rewardsPillsVisible)
        assertFalse(vm.uiState.value.redCardPillVisible)
    }

    @Test fun rewardsGate_closedWhenSuspended() = vmTest {
        val profileStore = RunnerProfileStore(FakeLogger())
        val (store, vm) = wire(this, profileStore = profileStore, remoteConfig = redCardRcOn)
        profileStore.setProfile(v2Profile())
        store.pushState(suspendedEnvelope)
        runCurrent()
        assertFalse(vm.uiState.value.rewardsPillsVisible)
        assertFalse(vm.uiState.value.redCardPillVisible)
    }

    @Test fun redCardPill_hiddenWhenRcFlagOff_coinsGateStillOpen() = vmTest {
        val profileStore = RunnerProfileStore(FakeLogger())
        val (_, vm) = wire(this, profileStore = profileStore) // default RC → false
        profileStore.setProfile(v2Profile())
        runCurrent()
        assertTrue(vm.uiState.value.rewardsPillsVisible)
        assertFalse(vm.uiState.value.redCardPillVisible)
    }

    @Test fun tapIntents_areNoOps() = vmTest {
        val (_, vm) = wire(this)
        val before = vm.uiState.value
        listOf(HomeUiIntent.TapBell, HomeUiIntent.TapSos, HomeUiIntent.TapSaathi,
            HomeUiIntent.TapCoins, HomeUiIntent.TapBanner("refer")).forEach(vm::onIntent)
        assertEquals(before, vm.uiState.value)
    }

    @Test fun absentEnvelopeWithTomorrowFields_rendersTwoStackedCards() = vmTest {
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_ABSENT","widget_data":{
              "date":"Tue, 7 Feb","attendance_type":"ABSENT",
              "tomorrow_date":"Wed, 8 Feb","tomorrow_shift_time":"7am-12pm"}}
        """.trimIndent())
        runCurrent()
        assertEquals(2, vm.uiState.value.heroCards.size)
        val today = assertIs<HomeCard.Attendance.TodayStatus>(vm.uiState.value.heroCards[0])
        assertEquals(AttendanceStatus.Absent, today.status)
        assertIs<HomeCard.Attendance.TomorrowProvisional>(vm.uiState.value.heroCards[1])
    }

    @Test fun tapAbsentTomorrow_opensEarningLossSheet_withCardAmount() = vmTest {
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_TOMORROW","widget_data":{
              "date":"Tue, 7 Feb","shift_time":"7am-12pm",
              "earning_loss_amount":800,"is_next_working_day_sunday":false}}
        """.trimIndent())
        runCurrent()

        vm.onIntent(HomeUiIntent.TapAbsentTomorrow)

        val sheet = assertIs<HomeSheet.EarningLoss>(vm.uiState.value.sheet)
        assertEquals("₹800", sheet.amount)
    }

    @Test fun tapAbsentTomorrow_withoutCard_opensSheetWithNullAmount() = vmTest {
        val (_, vm) = wire(this); runCurrent()

        vm.onIntent(HomeUiIntent.TapAbsentTomorrow)

        val sheet = assertIs<HomeSheet.EarningLoss>(vm.uiState.value.sheet)
        assertEquals(null, sheet.amount)
    }

    @Test fun dismissSheet_clearsSheet() = vmTest {
        val (store, vm) = wire(this)
        store.pushState("""{"widget_name":"RUNNER_ATTENDANCE_TOMORROW","widget_data":{"date":"X","shift_time":"Y"}}""")
        runCurrent()
        vm.onIntent(HomeUiIntent.TapAbsentTomorrow)
        assertIs<HomeSheet.EarningLoss>(vm.uiState.value.sheet)

        vm.onIntent(HomeUiIntent.DismissSheet)

        assertEquals(null, vm.uiState.value.sheet)
    }

    @Test fun confirmMarkProvisional_dismissesSheet_invokesUseCase_noRefreshOnSuccess() = vmTest {
        val (store, vm, repo) = wire(this)
        store.pushState("""{"widget_name":"RUNNER_ATTENDANCE_TOMORROW","widget_data":{"date":"X","shift_time":"Y"}}""")
        runCurrent()
        var refreshes = 0; store.bind { refreshes++ }
        vm.onIntent(HomeUiIntent.TapAbsentTomorrow)

        vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true))
        runCurrent()

        assertNull(vm.uiState.value.sheet)
        assertNull(vm.uiState.value.inFlight)
        assertEquals(1, repo.calls.size)
        assertEquals(FakeAttendanceRepository.Op.MarkProvisional, repo.calls.single().op)
        assertEquals(true, repo.calls.single().present)
        // WS5: post-action state (new attendance status) now arrives via MQTT — no refresh.
        assertEquals(0, refreshes)
    }

    @Test fun confirmMarkProvisional_emitsSnackbarEffect_onError() = vmTest {
        val (_, vm, repo) = wire(this)
        repo.enqueue(Result.Err(RunnerActionError.NoConnection))

        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { vm.effects.collect { collected += it } }
        runCurrent()
        vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = false))
        runCurrent()
        job.cancel()

        assertEquals(1, collected.size)
        val snack = assertIs<HomeUiEffect.ShowSnackbar>(collected.single())
        assertEquals(RunnerActionError.NoConnection, snack.error)
        assertNull(vm.uiState.value.inFlight)
    }

    // ── X.3 transient error_screen_load (Part 2) ─────────────────────────────

    @Test fun confirmMarkProvisional_error_firesErrorScreenLoad_networkFlag() = vmTest {
        val (_, vm, repo, _, _, analytics) = wire(this)
        repo.enqueue(Result.Err(RunnerActionError.NoConnection)); runCurrent()
        vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = false)); runCurrent()

        val loads = analytics.events.filter { it.first == "error_screen_load" }
        assertEquals(1, loads.size) // exactly once — no double fire
        val props = loads.single().second
        assertEquals("mark_attendance_failed", props["error_type"])
        assertEquals("snackbar", props["error_format"])
        assertEquals("attendance", props["error_context"])
        assertEquals(true, props["is_network_error"])
        assertEquals(false, props["retry_available"])
    }

    @Test fun confirmMarkProvisional_serverError_isNotNetwork() = vmTest {
        val (_, vm, repo, _, _, analytics) = wire(this)
        repo.enqueue(Result.Err(RunnerActionError.Server)); runCurrent()
        vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = false)); runCurrent()
        val props = analytics.events.single { it.first == "error_screen_load" }.second
        assertEquals("mark_attendance_failed", props["error_type"])
        assertEquals(false, props["is_network_error"])
    }

    @Test fun acceptLunch_error_firesLunchActionFailed() = vmTest {
        val w = wire(this)
        w.lunchRepo.enqueueAccept(Result.Err(RunnerActionError.Server)); runCurrent()
        w.vm.onIntent(HomeUiIntent.AcceptLunch); runCurrent()
        val props = w.analytics.events.single { it.first == "error_screen_load" }.second
        assertEquals("lunch_action_failed", props["error_type"])
        assertEquals("home", props["error_context"])
        assertEquals("snackbar", props["error_format"])
    }

    @Test fun unsuspendFailed_firesUnsuspendFailed_notNetwork() = vmTest {
        val w = wire(this)
        w.suspendedRepo.result = UnsuspendResult.Failed(statusCode = 500); runCurrent()
        w.vm.onIntent(HomeUiIntent.RequestComeBack); runCurrent()
        val loads = w.analytics.events.filter { it.first == "error_screen_load" }
        assertEquals(1, loads.size)
        val props = loads.single().second
        assertEquals("unsuspend_failed", props["error_type"])
        assertEquals("snackbar", props["error_format"])
        assertEquals("home", props["error_context"])
        // `Failed` collapses transport into Unknown(statusCode) → no connectivity signal.
        assertEquals(false, props["is_network_error"])
    }

    @Test fun confirmMarkProvisional_success_firesNoErrorScreenLoad() = vmTest {
        val (_, vm, _, _, _, analytics) = wire(this); runCurrent()
        vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)); runCurrent()
        assertTrue("error_screen_load" !in analytics.tracked)
    }

    @Test fun confirmMarkProvisional_secondCallWhileInFlight_isNoOp() = vmTest {
        // Block the first call indefinitely via a never-completing repo, then
        // assert a second tap is ignored (single-flight guard).
        val store = RunnerStateStore(FakeLogger())
        val blockingRepo = object : com.snabbit.runner.shared.features.shift.attendance.domain.repository.AttendanceRepository {
            var marks = 0
            override suspend fun markProvisional(
                present: Boolean,
            ): Result<com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome?, RunnerActionError> {
                marks++
                kotlinx.coroutines.delay(Long.MAX_VALUE / 2); return Result.Ok(null)
            }
            override suspend fun changeAttendance(
                present: Boolean,
                shiftDateIst: String,
            ): Result<com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome?, RunnerActionError> =
                Result.Ok(null)
        }
        val shiftRepo = FakeShiftRepository()
        val lunchRepo = FakeLunchRepository()
        val vm = HomeViewModel(
            readModel = ShiftProjector(store, backgroundScope, FakeLogger()),
            gamification = GamificationProjector(store, backgroundScope, TestClock(), CrashReporter { _, _ -> }),
            attendanceRepository = blockingRepo,
            shiftRepository = shiftRepo,
            postActionCoordinator = PostActionCoordinator(),
            lunchReadModel = LunchProjector(store, backgroundScope, FakeLogger()),
            lunchRepository = lunchRepo,
            sevaRepository = FakeSevaRepository(),
            suspendedReadModel = SuspendedProjector(store, RunnerProfileStore(FakeLogger()), backgroundScope),
            suspendedRepository = FakeSuspendedRepository(),
            seeYouTomorrowReadModel = SeeYouTomorrowProjector(store, backgroundScope),
            homeBannersStore = fakeHomeBannersStore(),
            locationProvider = FakeLocationProvider(),
            analytics = RecordingAnalytics(),
            currentTimeMs = TestClock(),
            callingDataSource = FakeCallingDataSource(),
        )
        activeVms += vm

        vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)); runCurrent()
        vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)); runCurrent()

        assertEquals(1, blockingRepo.marks)
        assertIs<HomeUiIntent.ConfirmMarkProvisional>(vm.uiState.value.inFlight)
    }

    @Test fun tapChangeAttendance_onAbsent_opensConfirmSheet_withDateAndShift() = vmTest {
        // No-penalty Change sheet ships date + shift window (Figma 318-44202).
        // Penalty / red-card cluster lands with the nudge port — separate PR.
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_ABSENT","widget_data":{
              "date":"Tue, 7 Feb","shift_time":"7am-12pm","change_atn":true,
              "attendance_type":"NO_SHOW","no_show_red_card_count":5}}
        """.trimIndent())
        runCurrent()

        vm.onIntent(HomeUiIntent.TapChangeAttendance)

        val sheet = assertIs<HomeSheet.ChangeAttendanceConfirm>(vm.uiState.value.sheet)
        assertEquals("Tue, 7 Feb", sheet.dateLabel)
        assertEquals("7AM-12PM", sheet.shiftWindowLabel)
    }

    @Test fun confirmChangeAttendance_invokesUseCase_withShiftDate_noRefreshOnSuccess() = vmTest {
        val (store, vm, repo) = wire(this)
        // start_date_ist is required by the backend — handler emits an error
        // and short-circuits without it; envelope must carry the field.
        store.pushState("""{"widget_name":"RUNNER_ATTENDANCE_CONFIRMED","widget_data":{"date":"X","change_atn":true,"start_date_ist":"2026-02-07"}}""")
        runCurrent()
        var refreshes = 0; store.bind { refreshes++ }
        vm.onIntent(HomeUiIntent.TapChangeAttendance)

        vm.onIntent(HomeUiIntent.ConfirmChangeAttendance(present = false))
        runCurrent()

        assertNull(vm.uiState.value.sheet)
        assertNull(vm.uiState.value.inFlight)
        assertEquals(FakeAttendanceRepository.Op.ChangeAttendance, repo.calls.single().op)
        assertEquals(false, repo.calls.single().present)
        assertEquals("2026-02-07", repo.calls.single().shiftDateIst)
        // WS5: post-action state now arrives via MQTT — no current_state refresh.
        assertEquals(0, refreshes)
    }

    @Test fun confirmChangeAttendance_withoutShiftDate_emitsErrorAndSkipsCall() = vmTest {
        val (store, vm, repo) = wire(this)
        // Same envelope as above but missing start_date_ist — handler should
        // short-circuit and emit a snackbar without firing the use case.
        store.pushState("""{"widget_name":"RUNNER_ATTENDANCE_CONFIRMED","widget_data":{"date":"X","change_atn":true}}""")
        runCurrent()

        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { vm.effects.collect { collected += it } }
        runCurrent()
        vm.onIntent(HomeUiIntent.ConfirmChangeAttendance(present = false))
        runCurrent()
        job.cancel()

        assertEquals(0, repo.calls.size)
        assertEquals(1, collected.size)
        assertIs<HomeUiEffect.ShowSnackbar>(collected.single())
    }

    @Test fun tapChangeAttendance_onPresent_opensEarningLossSheet_inChangeMode() = vmTest {
        val (store, vm) = wire(this)
        store.pushState("""{"widget_name":"RUNNER_ATTENDANCE_CONFIRMED","widget_data":{"date":"X","change_atn":true,"start_date_ist":"2026-02-07"}}""")
        runCurrent()

        vm.onIntent(HomeUiIntent.TapChangeAttendance)

        val sheet = assertIs<HomeSheet.EarningLoss>(vm.uiState.value.sheet)
        assertEquals(HomeSheet.EarningLoss.Mode.ChangeToday, sheet.mode)
    }

    @Test fun tapChangeAttendance_onPresent_withFalseAttendanceWarning_opensConfirmSheet() = vmTest {
        // RUNNER_LOGIN_HOTSPOT is the genuine today / live-shift state (Dart
        // job_login.dart:330): a Present runner with an active FALSE_ATTENDANCE
        // warning gets the penalty ChangeAttendance sheet, NOT EarningLoss. The
        // penalty is today-only — CONFIRMED (provisional) never reaches this
        // branch (see the regression test below).
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_LOGIN_HOTSPOT",
             "widget_data":{"date":"Wed, 8 Feb","shift_time":"7am-12pm","change_atn":true,"start_date_ist":"2026-02-07","address":"HSR"},
             "sheet_warnings":[{"lifecycle_action_type":"FALSE_ATTENDANCE",
               "cta_overrides":[{"cta_id":"mark_absent","red_cards":3}]}]}
        """.trimIndent())
        runCurrent()

        vm.onIntent(HomeUiIntent.TapChangeAttendance)

        val sheet = assertIs<HomeSheet.ChangeAttendanceConfirm>(vm.uiState.value.sheet)
        assertEquals("Wed, 8 Feb", sheet.dateLabel)
        assertEquals(false, sheet.isProvisional)
    }

    @Test fun tapChangeAttendance_provisionalConfirmed_withFalseAttendanceWarning_opensEarningLoss() = vmTest {
        // Regression (ECPO change-attendance drift): a CONFIRMED (tomorrow's
        // provisional-present) shift must NOT show the FALSE_ATTENDANCE red-card
        // penalty, even when the warning is live — it's a today-only penalty.
        // Same Present card + warning as the login test above; only the envelope
        // (provisional vs today) differs, so it routes to EarningLoss instead.
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_CONFIRMED",
             "widget_data":{"date":"Wed, 8 Feb","shift_time":"7am-12pm","change_atn":true,"start_date_ist":"2026-02-07"},
             "sheet_warnings":[{"lifecycle_action_type":"FALSE_ATTENDANCE",
               "cta_overrides":[{"cta_id":"mark_absent","red_cards":3}]}]}
        """.trimIndent())
        runCurrent()

        vm.onIntent(HomeUiIntent.TapChangeAttendance)

        val sheet = assertIs<HomeSheet.EarningLoss>(vm.uiState.value.sheet)
        assertEquals(HomeSheet.EarningLoss.Mode.ChangeToday, sheet.mode)
    }

    @Test fun tapChangeAttendance_provisionalAbsentTomorrow_marksConfirmSheetProvisional() = vmTest {
        // The other provisional case: RUNNER_ATTENDANCE_ABSENT with type=="TOMORROW".
        // Absent status routes to ChangeAttendanceConfirm (not EarningLoss); the sheet
        // must be flagged provisional so HomeScreen suppresses the FALSE_ATTENDANCE
        // penalty end-to-end, even with the warning live.
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_ABSENT",
             "widget_data":{"date":"Wed, 8 Feb","shift_time":"7am-12pm","change_atn":true,"attendance_type":"ABSENT","type":"TOMORROW","start_date_ist":"2026-02-07"},
             "sheet_warnings":[{"lifecycle_action_type":"FALSE_ATTENDANCE",
               "cta_overrides":[{"cta_id":"mark_absent","red_cards":3}]}]}
        """.trimIndent())
        runCurrent()

        vm.onIntent(HomeUiIntent.TapChangeAttendance)

        val sheet = assertIs<HomeSheet.ChangeAttendanceConfirm>(vm.uiState.value.sheet)
        assertEquals(true, sheet.isProvisional)
    }

    @Test fun paBeforeLogoutEnvelope_routesToLogoutPhase_doesNotAutoOpenSheet() = vmTest {
        // PA_BEFORE_LOGOUT envelope → ShiftPhase.Logout → Map archetype with
        // the floating Logout pill (no hero cards in this archetype). The
        // MarkTomorrowAttendance sheet only opens when the runner taps the
        // pill — never auto.
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"PA_BEFORE_LOGOUT","widget_data":{
              "date":"Tue, 7 Feb","shift_time":"7:00 PM - 8:00 PM",
              "tomorrow_date":"Wed, 8 Feb","tomorrow_shift_time":"7:00 AM - 12:00 PM"}}
        """.trimIndent())
        runCurrent()

        assertEquals(ShiftPhase.Logout, vm.uiState.value.phase)
        assertNull(vm.uiState.value.sheet)
    }

    // ── Pre-logout reminder (ECPO-819) ───────────────────────────────────

    @Test fun waitEnvelope_withLogoutReminder_showsDisabledLogoutPill() = vmTest {
        // From shift end − 30 min the wait envelope carries the warning flag —
        // the pill flips to the Logout widget with the CTA disabled.
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{
              "show_logout_warning_widgets":true,"shift_end_time":"08:00 pm"}}
        """.trimIndent())
        runCurrent()
        assertEquals(ShiftPhase.SearchingForJobs, vm.uiState.value.phase)
        val pill = assertIs<MapFloatingState.Logout>(vm.uiState.value.mapWidget)
        assertEquals("08:00 PM", pill.shiftEndLabel)
        assertEquals(false, pill.ctaEnabled)
    }

    @Test fun waitEnvelope_withoutReminder_showsSearchingPill() = vmTest {
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{
              "show_logout_warning_widgets":false,"shift_end_time":"08:00 pm"}}
        """.trimIndent())
        runCurrent()
        assertIs<MapFloatingState.SearchingForJobs>(vm.uiState.value.mapWidget)
    }

    @Test fun waitEnvelope_reminderWithoutEndTime_fallsBackToSearchingPill() = vmTest {
        // Malformed envelope (flag without a time) — "Shift ends at " reads
        // broken, so keep the searching pill.
        val (store, vm) = wire(this)
        store.pushState("""
            {"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{
              "show_logout_warning_widgets":true}}
        """.trimIndent())
        runCurrent()
        assertIs<MapFloatingState.SearchingForJobs>(vm.uiState.value.mapWidget)
    }

    // ── Break (lunch) lifecycle ──────────────────────────────────────────
    // The active envelope: break runs 10:00–10:30, green/amber/red bands at
    // 30/15/5 min remaining. `base` == break start.
    private val activeEnvelope = """
        {"widget_name":"LUNCH","widget_data":{
          "cooldown_start_time":"2026-06-29T09:58:00Z","cooldown_duration":2,
          "start_time":"2026-06-29T10:00:00Z","duration":30,
          "green_state_duration":30,"amber_state_duration":15,"red_state_duration":5}}
    """.trimIndent()
    private val breakStartMs = Instant.parse("2026-06-29T10:00:00Z").toEpochMilliseconds()

    @Test fun requestEnvelope_forcesMapArchetype_showsLunchPill_andOpensRequestSheet() = vmTest {
        val (store, vm) = wire(this)
        store.pushState("""{"widget_name":"LUNCH_REQUEST","widget_data":{}}""")
        runCurrent()
        assertEquals(ShiftPhase.SearchingForJobs, vm.uiState.value.phase)
        assertIs<MapFloatingState.LunchRequest>(vm.uiState.value.mapWidget)
        assertIs<HomeSheet.LunchRequest>(vm.uiState.value.sheet)
        assertTrue(vm.uiState.value.bodyCards.isEmpty())
    }

    @Test fun acceptLunch_callsRepo_noRefresh() = vmTest {
        val w = wire(this)
        w.store.pushState("""{"widget_name":"LUNCH_REQUEST","widget_data":{}}""")
        runCurrent()
        var refreshes = 0; w.store.bind { refreshes++ }
        w.vm.onIntent(HomeUiIntent.AcceptLunch)
        runCurrent()
        assertTrue(w.lunchRepo.calls.contains(FakeLunchRepository.Call.Accept))
        // WS5: post-action lunch state now arrives via MQTT — no current_state refresh.
        assertEquals(0, refreshes)
        assertNull(w.vm.uiState.value.sheet)
    }

    @Test fun denyLunch_callsRepo() = vmTest {
        val w = wire(this)
        w.store.pushState("""{"widget_name":"LUNCH_REQUEST","widget_data":{}}""")
        runCurrent()
        w.vm.onIntent(HomeUiIntent.DenyLunch)
        runCurrent()
        assertTrue(w.lunchRepo.calls.contains(FakeLunchRepository.Call.Deny))
    }

    @Test fun activeEnvelope_atStart_rendersGreenBreakCard_noPill() = vmTest {
        val w = wire(this)
        w.clock.nowMs = breakStartMs // remaining == full 1800s → Green band
        w.store.pushState(activeEnvelope)
        runCurrent()
        assertEquals(ShiftPhase.SearchingForJobs, w.vm.uiState.value.phase)
        assertNull(w.vm.uiState.value.mapWidget)
        val card = assertIs<HomeCard.Lunch>(w.vm.uiState.value.bodyCards.single())
        assertEquals(1800, card.remainingSeconds)
        assertEquals(1800, card.totalSeconds)
        assertEquals(BreakColorState.Green, card.colorState)
        assertEquals(false, card.isStartingSoon)
    }

    @Test fun activeEnvelope_duringCooldownSubWindow_showsStartingSoon() = vmTest {
        val w = wire(this)
        // cooldown runs 09:58–10:00 (cooldown_duration=2); 1 min into it here,
        // so 1 of the 2 cooldown minutes remain — NOT a cross-section of the
        // 30-minute break clock.
        w.clock.nowMs = breakStartMs - 60_000L
        w.store.pushState(activeEnvelope)
        runCurrent()
        val card = assertIs<HomeCard.Lunch>(w.vm.uiState.value.bodyCards.single())
        assertEquals(true, card.isStartingSoon)
        assertEquals(60, card.remainingSeconds)
        assertEquals(120, card.totalSeconds)
        assertEquals(BreakColorState.Initial, card.colorState)
    }

    @Test fun activeEnvelope_noCooldownStart_fallsBackToRemainingAsTotal() = vmTest {
        val w = wire(this)
        // No `cooldown_start_time` at all → cooldownEndMs collapses to
        // breakStartMs; still 30s before that here, so it's a degenerate
        // starting-soon window with no known total (fallback: total == remaining).
        w.clock.nowMs = breakStartMs - 30_000L
        w.store.pushState(
            """{"widget_name":"LUNCH","widget_data":{"start_time":"2026-06-29T10:00:00Z","duration":30}}""",
        )
        runCurrent()
        val card = assertIs<HomeCard.Lunch>(w.vm.uiState.value.bodyCards.single())
        assertEquals(true, card.isStartingSoon)
        assertEquals(30, card.remainingSeconds)
        assertEquals(30, card.totalSeconds)
    }

    @Test fun activeEnvelope_amberBand() = vmTest {
        val w = wire(this)
        w.clock.nowMs = breakStartMs + 1_200_000L // remaining 600s ≤ amber(900), > red(300)
        w.store.pushState(activeEnvelope)
        runCurrent()
        val card = assertIs<HomeCard.Lunch>(w.vm.uiState.value.bodyCards.single())
        assertEquals(BreakColorState.Amber, card.colorState)
    }

    @Test fun activeEnvelope_redBand() = vmTest {
        val w = wire(this)
        w.clock.nowMs = breakStartMs + 1_700_000L // remaining 100s ≤ red(300)
        w.store.pushState(activeEnvelope)
        runCurrent()
        val card = assertIs<HomeCard.Lunch>(w.vm.uiState.value.bodyCards.single())
        assertEquals(BreakColorState.Red, card.colorState)
    }

    // WS5: `activeBreak_schedulesSingleWarmupRefresh_shortlyBeforeEnd` removed with
    // the break-end warm-up refresh — the post-break state is now pushed over MQTT.

    @Test fun requestEndBreak_opensConfirmSheet_doesNotEndYet() = vmTest {
        val w = wire(this)
        w.clock.nowMs = breakStartMs
        w.store.pushState(activeEnvelope)
        runCurrent()
        w.vm.onIntent(HomeUiIntent.RequestEndBreak)
        assertIs<HomeSheet.EndBreakConfirm>(w.vm.uiState.value.sheet)
        assertTrue(w.lunchRepo.endBreakCalls.isEmpty())
    }

    @Test fun confirmEndBreak_tracksAnalytics_endsWithCoords_closesSheet() = vmTest {
        val w = wire(this)
        w.clock.nowMs = breakStartMs
        w.store.pushState(activeEnvelope)
        runCurrent()
        w.vm.onIntent(HomeUiIntent.RequestEndBreak)
        w.vm.onIntent(HomeUiIntent.ConfirmEndBreak)
        runCurrent()
        assertTrue(w.analytics.tracked.contains("break_confirm_end_button_clicked"))
        assertTrue(w.analytics.tracked.contains("end_break_confirmation_bs_cta_click"))
        val end = w.lunchRepo.endBreakCalls.single()
        assertEquals(FakeLocationProvider.DEFAULT_LOC.latitude, end.lat)
        assertEquals(FakeLocationProvider.DEFAULT_LOC.longitude, end.lng)
        assertNull(w.vm.uiState.value.sheet)
    }

    // ── Seva markers ─────────────────────────────────────────────────────
    private fun sevaPoint(
        id: String,
        name: String = "Loo",
        road: String = "Rd",
        distance: Int = 100,
    ) = SevaPoint(
        id = id, name = name, category = "Cafe", lat = 1.0, lng = 2.0,
        road = road, distanceMeters = distance, kind = SevaKind.Washroom,
    )

    /** Lands the runner on the Map archetype (SearchingForJobs) — the only state that
     *  renders seva markers, so the only state that fetches them (ECPO-905). */
    private fun Wired.enterMapArchetype() = store.pushState(
        """{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{"show_logout_warning_widgets":false,"shift_end_time":"08:00 pm"}}""",
    )

    @Test fun initFix_fetchesNearbySeva_populatesPoints() = vmTest {
        val w = wire(this)
        w.sevaRepo.enqueue(Result.Ok(listOf(sevaPoint("W1"))))
        w.enterMapArchetype()
        runCurrent()
        assertEquals(listOf("W1"), w.vm.uiState.value.sevaPoints.map { it.id })
        // Fetched with the current fix (FakeLocationProvider default = DEFAULT_LOC).
        assertEquals(FakeLocationProvider.DEFAULT_LOC.latitude, w.sevaRepo.calls.single().lat)
    }

    // ECPO-905: seva markers render only on the Map archetype; on HeroLayout states
    // (e.g. PreShift / RUNNER_LOGIN_HOTSPOT) the fetch would be discarded, so it must
    // not fire — then it must fire the moment we enter the map.
    @Test fun heroArchetype_skipsSevaFetch_thenFetchesOnEnteringMap() = vmTest {
        val w = wire(this)
        w.sevaRepo.enqueue(Result.Ok(listOf(sevaPoint("W1"))))
        runCurrent() // PreShift (HeroLayout) — no map, no fetch.
        assertTrue(w.sevaRepo.calls.isEmpty())
        w.enterMapArchetype()
        runCurrent()
        assertEquals(1, w.sevaRepo.calls.size)
        assertEquals(listOf("W1"), w.vm.uiState.value.sevaPoints.map { it.id })
    }

    // ECPO-904: on the Map archetype two triggers race — entering the map and the
    // first location fix — while `lastSevaFetchCenter` is still null (only set after
    // the call returns), so the move-gate can't suppress the fix. The single-flight
    // guard must collapse the two concurrent triggers into one request.
    @Test fun concurrentTriggers_whileFetchInFlight_singleFlightSuppressesDuplicate() = vmTest {
        // Streaming provider emits a fix, so both triggers fire on entering the map.
        // Gating the fetch holds it in flight across the fix, which is exactly when
        // the duplicate used to slip through.
        val w = wire(this, location = StreamingLocationProvider(FakeLocationProvider.DEFAULT_LOC))
        val gate = w.sevaRepo.gateCalls()
        w.sevaRepo.enqueue(Result.Ok(listOf(sevaPoint("W1"))))
        w.enterMapArchetype()
        runCurrent()
        // First fetch recorded; the concurrent trigger was suppressed while in flight.
        assertEquals(1, w.sevaRepo.calls.size)
        gate.complete(Unit) // let the in-flight fetch finish
        runCurrent()
        assertEquals(1, w.sevaRepo.calls.size)
        assertEquals(listOf("W1"), w.vm.uiState.value.sevaPoints.map { it.id })
    }

    @Test fun sevaFetchError_leavesPointsEmpty() = vmTest {
        val w = wire(this)
        w.sevaRepo.enqueue(Result.Err(RunnerActionError.Server))
        w.enterMapArchetype()
        runCurrent()
        assertTrue(w.vm.uiState.value.sevaPoints.isEmpty())
    }

    @Test fun noLocationFix_skipsSevaFetch() = vmTest {
        val w = wire(
            this,
            location = FakeLocationProvider(
                current = LocationResult.Failure("no fix"),
                lastKnown = LocationResult.Failure("no fix"),
            ),
        )
        w.enterMapArchetype() // on the map, so the coords gate (not the archetype gate) is what skips
        runCurrent()
        assertTrue(w.sevaRepo.calls.isEmpty())
        assertTrue(w.vm.uiState.value.sevaPoints.isEmpty())
    }

    @Test fun tapSeva_withKnownId_showsHelperCardFromPoint() = vmTest {
        val w = wire(this)
        w.sevaRepo.enqueue(Result.Ok(listOf(sevaPoint("W1", name = "Loo", road = "Main St", distance = 142))))
        w.enterMapArchetype()
        runCurrent()

        w.vm.onIntent(HomeUiIntent.TapSeva("W1"))

        val seva = assertIs<MapFloatingState.Seva>(w.vm.uiState.value.sevaAnnouncement)
        assertEquals("Loo", seva.customerName)
        assertEquals("Seva", seva.tagLabel)
        assertEquals("Main St", seva.address)
        assertEquals("142 meters away", seva.distanceLabel)
        assertEquals(1.0, seva.lat)
        assertEquals(2.0, seva.lng)
    }

    @Test fun navigateSeva_emitsOpenDirectionsEffect() = vmTest {
        val w = wire(this)
        w.sevaRepo.enqueue(Result.Ok(listOf(sevaPoint("W1"))))
        w.enterMapArchetype()
        runCurrent()

        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.NavigateSeva(1.0, 2.0))
        runCurrent()
        job.cancel()

        assertEquals(HomeUiEffect.OpenDirections(1.0, 2.0), collected.single())
    }

    @Test fun tapHotspot_cardBody_withCoords_emitsOpenDirectionsEffect() = vmTest {
        val w = wire(this)
        runCurrent()

        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.TapHotspot(1.0, 2.0))
        runCurrent()
        job.cancel()

        assertEquals(HomeUiEffect.OpenDirections(1.0, 2.0), collected.single())
    }

    @Test fun tapHotspot_cardBody_withNullCoords_isNoOp() = vmTest {
        val w = wire(this)
        runCurrent()

        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.TapHotspot(null, null))
        runCurrent()
        job.cancel()

        assertTrue(collected.isEmpty())
    }

    @Test fun tapHotspotMap_withCoords_emitsOpenDirectionsEffect() = vmTest {
        val w = wire(this)
        runCurrent()

        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.TapHotspotMap(1.0, 2.0))
        runCurrent()
        job.cancel()

        assertEquals(HomeUiEffect.OpenDirections(1.0, 2.0), collected.single())
    }

    @Test fun tapSeva_withUnknownId_isNoOp() = vmTest {
        val w = wire(this)
        w.sevaRepo.enqueue(Result.Ok(listOf(sevaPoint("W1"))))
        w.enterMapArchetype()
        runCurrent()

        w.vm.onIntent(HomeUiIntent.TapSeva("nope"))

        assertNull(w.vm.uiState.value.sevaAnnouncement)
    }

    @Test fun locationFix_setsMapCenter() = vmTest {
        val loc = SnabbitLocation(
            latitude = 19.07, longitude = 72.87, accuracy = 5f, timestamp = 0L, collectedAt = 0L,
        )
        val w = wire(this, location = StreamingLocationProvider(loc))
        runCurrent()
        assertEquals(MapCoords(19.07, 72.87), w.vm.uiState.value.mapCenter)
    }

    /** The AWOL hotspot-distance tracker consumes THIS stream instead of opening a
     *  second FusedLocationProvider request for the same screen — so the live fix has
     *  to be published, not just folded into the cards projection. */
    @Test fun locationFix_isPublishedOnRunnerLocation() = vmTest {
        val loc = SnabbitLocation(
            latitude = 19.07, longitude = 72.87, accuracy = 5f, timestamp = 0L, collectedAt = 0L,
        )
        val w = wire(this, location = StreamingLocationProvider(loc))
        runCurrent()
        assertEquals(loc, w.vm.runnerLocation.value)
    }

    /** The cached last-known seed lands on the same StateFlow, so a consumer that
     *  subscribes later (the AWOL tile mounting mid-session) paints immediately off
     *  the replayed value instead of waiting for the next GPS update. */
    @Test fun cachedLastKnownFix_seedsRunnerLocation() = vmTest {
        // FakeLocationProvider: last-known succeeds, trackLocation emits nothing.
        val w = wire(this)
        runCurrent()
        assertEquals(FakeLocationProvider.DEFAULT_LOC, w.vm.runnerLocation.value)
    }

    // ── Suspended card (RUNNER_SUSPENDED) ─────────────────────────────────
    private val suspendedEnvelope = """{"widget_name":"RUNNER_SUSPENDED","widget_data":{}}"""

    @Test fun suspendedEnvelope_takesOverHero_withSuspendedCard() = vmTest {
        val w = wire(this)
        w.store.pushState(suspendedEnvelope)
        runCurrent()
        val card = assertIs<HomeCard.Suspended>(w.vm.uiState.value.heroCards.single())
        assertEquals(false, card.isAadhaarRekyc) // no profile pushed → flag defaults false
        assertTrue(w.vm.uiState.value.bodyCards.isEmpty())
        assertNull(w.vm.uiState.value.mapWidget)
        assertNull(w.vm.uiState.value.sheet)
    }

    @Test fun requestComeBack_reactivated_locksCta_tracksSuccess_refreshes() = vmTest {
        val w = wire(this) // FakeSuspendedRepository defaults to Reactivated
        w.store.pushState(suspendedEnvelope)
        runCurrent()
        var refreshes = 0; w.store.bind { refreshes++ }

        w.vm.onIntent(HomeUiIntent.RequestComeBack)
        runCurrent()

        assertTrue(w.vm.uiState.value.suspendRequestSubmitted)
        assertNull(w.vm.uiState.value.inFlight)
        assertEquals(1, w.suspendedRepo.calls)
        assertTrue(w.analytics.tracked.contains("expert_wants_to_join_back"))
        assertEquals(1, refreshes)
    }

    @Test fun requestComeBack_denied_locksCta_noSnackbar() = vmTest {
        val w = wire(this)
        w.suspendedRepo.result = UnsuspendResult.Denied(reason = "already_active", message = "Not suspended")
        w.store.pushState(suspendedEnvelope)
        runCurrent()

        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.RequestComeBack)
        runCurrent()
        job.cancel()

        assertTrue(w.vm.uiState.value.suspendRequestSubmitted)
        assertNull(w.vm.uiState.value.inFlight)
        assertTrue(collected.isEmpty())
        assertTrue(w.analytics.tracked.contains("expert_wants_to_join_back"))
    }

    @Test fun requestComeBack_failed_keepsCtaTappable_emitsGenericSnackbar() = vmTest {
        val w = wire(this)
        w.suspendedRepo.result = UnsuspendResult.Failed(statusCode = 500) // no BE message
        w.store.pushState(suspendedEnvelope)
        runCurrent()

        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.RequestComeBack)
        runCurrent()
        job.cancel()

        assertEquals(false, w.vm.uiState.value.suspendRequestSubmitted)
        assertNull(w.vm.uiState.value.inFlight)
        val snack = assertIs<HomeUiEffect.ShowSnackbar>(collected.single())
        // No BE message → falls back to the typed-error copy (Unknown → errorUnknown).
        assertIs<RunnerActionError.Unknown>(snack.error)
        assertNull(snack.message)
    }

    @Test fun requestComeBack_failedWithBeMessage_showsServerMessage() = vmTest {
        val w = wire(this)
        w.suspendedRepo.result = UnsuspendResult.Failed(statusCode = 503, message = "Service unavailable")
        w.store.pushState(suspendedEnvelope)
        runCurrent()

        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.RequestComeBack)
        runCurrent()
        job.cancel()

        val snack = assertIs<HomeUiEffect.ShowSnackbar>(collected.single())
        assertEquals("Service unavailable", snack.message) // Dart parity: show BE body verbatim
    }

    @Test fun requestComeBack_secondCallAfterSubmitted_isNoOp() = vmTest {
        val w = wire(this)
        w.store.pushState(suspendedEnvelope)
        runCurrent()
        w.vm.onIntent(HomeUiIntent.RequestComeBack); runCurrent()
        assertTrue(w.vm.uiState.value.suspendRequestSubmitted)

        w.vm.onIntent(HomeUiIntent.RequestComeBack); runCurrent()

        assertEquals(1, w.suspendedRepo.calls) // guarded — not re-fired
    }

    @Test fun updateAadhaar_emitsNavigateToAadhaarReKycEffect() = vmTest {
        val w = wire(this); runCurrent()
        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.UpdateAadhaar)
        runCurrent()
        job.cancel()
        assertEquals(HomeUiEffect.NavigateToAadhaarReKyc, collected.single())
    }

    @Test fun tapGoToEarnings_nonRateCardV2_emitsPayoutHomeFlag() = vmTest {
        val w = wire(this) // no profile pushed → isRateCardV2Effective defaults false
        w.store.pushState(suspendedEnvelope)
        runCurrent()
        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.TapGoToEarnings)
        runCurrent()
        job.cancel()
        assertEquals(HomeUiEffect.NavigateToEarnings(rateCardV2Effective = false), collected.single())
    }

    @Test fun tapGoToEarnings_rateCardV2_emitsWebviewFlag() = vmTest {
        val profileStore = RunnerProfileStore(FakeLogger())
        profileStore.setProfile(sampleRunnerProfile(isRateCardV2Effective = true))
        val w = wire(this, profileStore = profileStore)
        w.store.pushState(suspendedEnvelope)
        runCurrent()
        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.TapGoToEarnings)
        runCurrent()
        job.cancel()
        assertEquals(HomeUiEffect.NavigateToEarnings(rateCardV2Effective = true), collected.single())
    }

    // ── See-you-tomorrow card (RUNNER_SEE_YOU_TOMORROW) ───────────────────
    private val seeYouTomorrowEnvelope =
        """{"widget_name":"RUNNER_SEE_YOU_TOMORROW","widget_data":{}}"""

    @Test fun seeYouTomorrowEnvelope_takesOverHero_withSeeYouTomorrowCard() = vmTest {
        val w = wire(this)
        w.store.pushState(seeYouTomorrowEnvelope)
        runCurrent()
        assertEquals(HomeCard.SeeYouTomorrow, w.vm.uiState.value.heroCards.single())
        assertTrue(w.vm.uiState.value.bodyCards.isEmpty())
        assertNull(w.vm.uiState.value.mapWidget)
        assertNull(w.vm.uiState.value.sheet)
    }

    @Test fun seeYouTomorrow_tapGoToEarnings_readsRateCardV2FromProfile() = vmTest {
        // Not suspended → suspended projector flag is null; the earnings flag must
        // fall back to the live profile snapshot.
        val profileStore = RunnerProfileStore(FakeLogger())
        profileStore.setProfile(sampleRunnerProfile(isRateCardV2Effective = true))
        val w = wire(this, profileStore = profileStore)
        w.store.pushState(seeYouTomorrowEnvelope)
        runCurrent()
        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()
        w.vm.onIntent(HomeUiIntent.TapGoToEarnings)
        runCurrent()
        job.cancel()
        assertEquals(HomeUiEffect.NavigateToEarnings(rateCardV2Effective = true), collected.single())
    }

    @Test fun tapReferAndEarn_routesToReferralHome() = vmTest {
        val w = wire(this)
        w.store.pushState(seeYouTomorrowEnvelope)
        runCurrent()
        w.vm.onIntent(HomeUiIntent.TapReferAndEarn)
        runCurrent()
        // referrals-v2 RC off (default) → native ReferralsHome, same as the Refer banner.
        assertEquals("/referral-home", w.navHost.keepHostRoutes.single().first)
    }

    @Test fun tapReferAndEarn_referralsV2On_attributesSeeYouTomorrowEntryPoint() = vmTest {
        // v2 webview path is the only one that carries entry_point — assert this
        // surface is distinguished from the banner refer tap.
        val rc = object : RemoteConfigGateway {
            override fun getBool(key: String, default: Boolean) =
                key == "expert_is_referrals_v2_enabled" || default
            override fun getString(key: String, default: String) = default
        }
        val w = wire(this, remoteConfig = rc)
        w.store.pushState(seeYouTomorrowEnvelope)
        runCurrent()
        w.vm.onIntent(HomeUiIntent.TapReferAndEarn)
        runCurrent()
        val (route, args) = w.navHost.keepHostRoutes.single()
        assertEquals("/app-web-view", route)
        assertEquals("see_you_tomorrow", args["entryPoint"])
    }

    // ───────────────── Two-stage logout (PA_BEFORE_LOGOUT) ─────────────────

    /** `PA_BEFORE_LOGOUT` — the only envelope that sets `tomorrowAttendanceRequired`,
     *  which is what arms `pendingLogoutAfterAttendance` on a Logout tap. */
    private fun Wired.pushPaBeforeLogout() = store.pushState(
        """
        {"widget_name":"PA_BEFORE_LOGOUT","widget_data":{
          "tomorrow_date":"Tue, 7 Feb","tomorrow_shift_time":"7am-12pm",
          "shift_time":"07:50 pm - 08:00 pm","earning_loss_amount":800,
          "is_next_working_day_sunday":false}}
        """.trimIndent(),
    )

    @Test fun tapLogout_onPaBeforeLogout_opensSheet_thenSuccessfulMark_chainsLogout() = vmTest {
        val w = wire(this)
        w.pushPaBeforeLogout(); runCurrent()

        w.vm.onIntent(HomeUiIntent.TapLogout); runCurrent()
        assertIs<HomeSheet.MarkTomorrowAttendance>(w.vm.uiState.value.sheet)
        // Sheet only — no logout yet; the runner still has to answer the question.
        assertTrue(w.shiftRepo.calls.none { it is FakeShiftRepository.Call.Logout })

        w.vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)); runCurrent()
        // Mark succeeded → the logout the runner originally asked for is chained.
        assertEquals(1, w.shiftRepo.calls.count { it is FakeShiftRepository.Call.Logout })
    }

    /**
     * Regression: a FAILED mark used to leave `pendingLogoutAfterAttendance` armed —
     * `launchAction` closed the sheet on every outcome but cleared the flag only on
     * `Ok`. Because `MarkTomorrowAttendance` is not dismissible there was no way to
     * clear it by hand, so the NEXT successful provisional mark — days later, from an
     * ordinary tomorrow card — silently chained `shiftLogout()` on a live shift.
     */
    @Test fun tapLogout_thenFailedMark_doesNotArmLogoutForALaterUnrelatedMark() = vmTest {
        val w = wire(this)
        w.pushPaBeforeLogout(); runCurrent()

        w.vm.onIntent(HomeUiIntent.TapLogout); runCurrent()
        assertIs<HomeSheet.MarkTomorrowAttendance>(w.vm.uiState.value.sheet)

        // The mark fails on a flaky network. Sheet closes, snackbar shown.
        w.repo.enqueue(Result.Err(RunnerActionError.NoConnection))
        w.vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)); runCurrent()
        assertNull(w.vm.uiState.value.sheet)
        assertTrue(w.shiftRepo.calls.none { it is FakeShiftRepository.Call.Logout })
        assertFalse(w.vm.uiState.value.pendingLogoutAfterAttendance)

        // Later: an ordinary, unrelated provisional mark that SUCCEEDS.
        w.vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)); runCurrent()

        // Must NOT log the runner out — they never asked for it this time.
        assertTrue(w.shiftRepo.calls.none { it is FakeShiftRepository.Call.Logout })
    }

    /** Dart PA_BEFORE_LOGOUT parity: a rate-card-v2 runner is taken to the
     *  shift-end earnings summary after the attendance-chained logout. */
    @Test fun paBeforeLogout_chainedLogout_rateCardV2_navigatesToShiftEndEarnings() = vmTest {
        val profileStore = RunnerProfileStore(FakeLogger())
        profileStore.setProfile(sampleRunnerProfile(isRateCardV2Effective = true))
        val w = wire(this, profileStore = profileStore)
        w.pushPaBeforeLogout(); runCurrent()
        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()

        w.vm.onIntent(HomeUiIntent.TapLogout); runCurrent()
        w.vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)); runCurrent()
        job.cancel()

        assertEquals(1, w.shiftRepo.calls.count { it is FakeShiftRepository.Call.Logout })
        assertTrue(collected.contains(HomeUiEffect.NavigateToShiftEndEarnings))
    }

    /** v1 runners get no earnings step — mirrors Dart hiding the "View Today's
     *  Earnings" button when `!optedForNewRateCard`. */
    @Test fun paBeforeLogout_chainedLogout_nonRateCardV2_noEarningsNav() = vmTest {
        val w = wire(this) // no profile → isRateCardV2Effective defaults false
        w.pushPaBeforeLogout(); runCurrent()
        val collected = mutableListOf<HomeUiEffect>()
        val job = backgroundScope.launch { w.vm.effects.collect { collected += it } }
        runCurrent()

        w.vm.onIntent(HomeUiIntent.TapLogout); runCurrent()
        w.vm.onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)); runCurrent()
        job.cancel()

        assertEquals(1, w.shiftRepo.calls.count { it is FakeShiftRepository.Call.Logout })
        assertFalse(collected.contains(HomeUiEffect.NavigateToShiftEndEarnings))
    }
}
