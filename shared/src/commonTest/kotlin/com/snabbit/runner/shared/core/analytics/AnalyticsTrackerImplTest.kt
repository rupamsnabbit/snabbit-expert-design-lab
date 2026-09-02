package com.snabbit.runner.shared.core.analytics

import com.snabbit.runner.shared.core.FakeLogger
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AnalyticsTrackerImplTest {

    private fun tracker(
        providers: List<AnalyticsProvider>,
        debug: Boolean = false,
        // Default routes every event to every provider, so the fan-out tests
        // below exercise tracker behaviour, not routing. Routing-specific
        // tests pass an explicit table.
        routes: AnalyticsRouteTable = AnalyticsRouteTable(
            table = emptyMap(),
            default = providers.map { it.tag }.toSet(),
            onUnrouted = {},
        ),
    ): Pair<AnalyticsTrackerImpl, Triple<FakeLogger, RecordingCrashReporter, List<AnalyticsProvider>>> {
        val log = FakeLogger()
        val crash = RecordingCrashReporter()
        val t = AnalyticsTrackerImpl(
            providers = providers,
            routes = routes,
            debugLogging = debug,
            logger = log,
            crashReporter = crash,
        )
        return t to Triple(log, crash, providers)
    }

    @Test
    fun track_routesOnlyToDestinationProviders() {
        // Routing is consulted: an event whose destinations are {AppsFlyer}
        // reaches AppsFlyer but NOT Mixpanel.
        val af = FakeAnalyticsProvider("AppsFlyer")
        val mp = FakeAnalyticsProvider("Mixpanel")
        val routes = AnalyticsRouteTable(
            table = mapOf("af_only" to setOf("AppsFlyer")),
            default = emptySet(),
            onUnrouted = {},
        )
        val (t, _) = tracker(providers = listOf(af, mp), routes = routes)

        t.track("af_only")

        assertEquals(1, af.calls.size)
        assertTrue(mp.calls.isEmpty())
    }

    @Test
    fun track_withExplicitTargets_bypassesTheRouteTable() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val ct = FakeAnalyticsProvider("CleverTap")
        // route table would send "web_x" nowhere (empty); targets override it.
        val routes = AnalyticsRouteTable(table = emptyMap(), default = emptySet(), onUnrouted = {})
        val (t, _) = tracker(providers = listOf(af, ct), routes = routes)

        t.track("web_x", emptyMap(), targets = setOf("CleverTap"))

        assertTrue(af.calls.isEmpty())
        assertEquals(1, ct.calls.size)
    }

    @Test
    fun track_withUnknownExplicitTarget_reportsAndDropsSilentlyOnProvider() {
        val ct = FakeAnalyticsProvider("CleverTap")
        val routes = AnalyticsRouteTable(table = emptyMap(), default = emptySet(), onUnrouted = {})
        val (t, ctx) = tracker(providers = listOf(ct), routes = routes)
        val (_, crash, _) = ctx

        // 'Mixpanl' typo — no registered provider matches.
        t.track("web_x", emptyMap(), targets = setOf("Mixpanl", "CleverTap"))

        // CleverTap still receives; the unknown target surfaces via crashReporter.
        assertEquals(1, ct.calls.size)
        assertEquals(1, crash.reports.size)
        val report = crash.reports.single()
        assertTrue(report.throwable is IllegalStateException)
        assertEquals("track", report.meta["op"])
        assertEquals("web_x", report.meta["name"])
        assertTrue(report.meta["unknown"]?.contains("Mixpanl") == true)
    }

    @Test
    fun track_withAllKnownExplicitTargets_doesNotReport() {
        val ct = FakeAnalyticsProvider("CleverTap")
        val mp = FakeAnalyticsProvider("Mixpanel")
        val routes = AnalyticsRouteTable(table = emptyMap(), default = emptySet(), onUnrouted = {})
        val (t, ctx) = tracker(providers = listOf(ct, mp), routes = routes)
        val (_, crash, _) = ctx

        t.track("web_x", emptyMap(), targets = setOf("Mixpanel", "CleverTap"))

        assertEquals(1, ct.calls.size)
        assertEquals(1, mp.calls.size)
        assertTrue(crash.reports.isEmpty())
    }

    @Test
    fun track_unroutedEvent_reachesNoProviderAndFiresOnUnrouted() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val unrouted = mutableListOf<String>()
        val routes = AnalyticsRouteTable(
            table = emptyMap(),
            default = emptySet(),
            onUnrouted = { unrouted.add(it) },
        )
        val (t, _) = tracker(providers = listOf(af), routes = routes)

        t.track("orphan")

        assertTrue(af.calls.isEmpty())
        assertEquals(listOf("orphan"), unrouted)
    }

    @Test
    fun track_fansToAllRegisteredProvidersUnconditionally() {
        // With the default all-destinations route table, every event reaches
        // every registered provider.
        val af = FakeAnalyticsProvider("AppsFlyer")
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(af, mp))

        t.track("any_event")

        assertEquals(1, af.calls.size)
        assertEquals(1, mp.calls.size)
        assertTrue(af.calls.first() is FakeAnalyticsProvider.Call.Track)
    }

    @Test
    fun track_sanitisesProps() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val (t, _) = tracker(providers = listOf(af))

        t.track(
            name = "e",
            props = mapOf("i" to 7, "n" to null, "s" to "ok"),
        )

        val track = af.calls.single() as FakeAnalyticsProvider.Call.Track
        // null stripped, Int widened to Long.
        assertEquals(mapOf("i" to 7L, "s" to "ok"), track.props)
    }

    @Test
    fun track_providerExceptionIsIsolated() {
        val af = FakeAnalyticsProvider("AppsFlyer", throwOn = setOf("boom"))
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, ctx) = tracker(providers = listOf(af, mp))

        t.track("boom")

        // AF threw; Mixpanel still got it.
        val (log, crash, _) = ctx
        assertEquals(1, mp.calls.size)
        assertEquals(1, crash.reports.size)
        assertEquals("AppsFlyer", crash.reports.first().meta["provider"])
        assertEquals("track", crash.reports.first().meta["op"])
        assertTrue(log.entries.any { it.level == FakeLogger.Level.ERROR })
    }

    @Test
    fun track_fansToAllProvidersExactlyOnce() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val mp = FakeAnalyticsProvider("Mixpanel")
        val ct = FakeAnalyticsProvider("CleverTap")
        val (t, _) = tracker(providers = listOf(ct, af, mp))

        t.track("e")

        assertEquals(1, af.calls.size)
        assertEquals(1, mp.calls.size)
        assertEquals(1, ct.calls.size)
    }

    @Test
    fun identify_fansToAllRegisteredProviders() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(af, mp))

        t.identify("expert-42")

        val afCall = af.calls.single() as FakeAnalyticsProvider.Call.Identify
        val mpCall = mp.calls.single() as FakeAnalyticsProvider.Call.Identify
        assertEquals("expert-42", afCall.userId)
        assertEquals("expert-42", mpCall.userId)
    }

    @Test
    fun identify_nullClears() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val (t, _) = tracker(providers = listOf(af))

        t.identify(null)

        val call = af.calls.single() as FakeAnalyticsProvider.Call.Identify
        assertEquals(null, call.userId)
    }

    @Test
    fun reset_fansToAllRegisteredProviders() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(af, mp))

        t.reset()

        assertTrue(af.calls.any { it is FakeAnalyticsProvider.Call.Reset })
        assertTrue(mp.calls.any { it is FakeAnalyticsProvider.Call.Reset })
    }

    @Test
    fun onUserLogin_fansToAllRegisteredProviders() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val ct = FakeAnalyticsProvider("CleverTap")
        val (t, _) = tracker(providers = listOf(af, ct))

        t.onUserLogin(mapOf("Identity" to 7))

        assertTrue(af.calls.single() is FakeAnalyticsProvider.Call.OnUserLogin)
        assertTrue(ct.calls.single() is FakeAnalyticsProvider.Call.OnUserLogin)
    }

    @Test
    fun setUserProperty_fansToAllRegisteredProviders() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(af, mp))

        t.setUserProperty("city", "Mumbai")

        val afCall = af.calls.single() as FakeAnalyticsProvider.Call.SetUserProperty
        val mpCall = mp.calls.single() as FakeAnalyticsProvider.Call.SetUserProperty
        assertEquals("city" to "Mumbai", afCall.key to afCall.value)
        assertEquals("city" to "Mumbai", mpCall.key to mpCall.value)
    }

    @Test
    fun setUserProperty_providerExceptionIsIsolated() {
        val af = FakeAnalyticsProvider("AppsFlyer", throwOn = setOf("city"))
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, ctx) = tracker(providers = listOf(af, mp))

        t.setUserProperty("city", "Mumbai")

        // AF threw; Mixpanel still got it.
        val (log, crash, _) = ctx
        assertEquals(1, mp.calls.size)
        assertEquals(1, crash.reports.size)
        assertEquals("AppsFlyer", crash.reports.first().meta["provider"])
        assertEquals("setUserProperty", crash.reports.first().meta["op"])
        assertEquals("city", crash.reports.first().meta["name"])
        assertTrue(log.entries.any { it.level == FakeLogger.Level.ERROR })
    }

    @Test
    fun setUserProperties_fansSanitisedMapToAllProviders() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(af, mp))

        t.setUserProperties(mapOf("city" to "Mumbai", "tier" to 2, "team" to null))

        // null stripped, Int widened to Long — same sanitisation as track().
        val expected = mapOf("city" to "Mumbai", "tier" to 2L)
        assertEquals(expected, (af.calls.single() as FakeAnalyticsProvider.Call.SetUserProperties).props)
        assertEquals(expected, (mp.calls.single() as FakeAnalyticsProvider.Call.SetUserProperties).props)
    }

    @Test
    fun setUserProperties_emptyAfterSanitisation_doesNothing() {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val (t, _) = tracker(providers = listOf(af))

        t.setUserProperties(mapOf("a" to null, "b" to null))

        assertTrue(af.calls.isEmpty())
    }

    @Test
    fun setUserProperties_providerExceptionIsIsolated() {
        val af = FakeAnalyticsProvider("AppsFlyer", throwOn = setOf("city"))
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, ctx) = tracker(providers = listOf(af, mp))

        t.setUserProperties(mapOf("city" to "Mumbai", "tier" to 2))

        val (log, crash, _) = ctx
        assertEquals(1, mp.calls.size)
        assertEquals(1, crash.reports.size)
        assertEquals("AppsFlyer", crash.reports.first().meta["provider"])
        assertEquals("setUserProperties", crash.reports.first().meta["op"])
        assertTrue(log.entries.any { it.level == FakeLogger.Level.ERROR })
    }

    @Test
    fun bootstrap_startsRegisteredProviders() = runTest {
        val af = FakeAnalyticsProvider("AppsFlyer")
        val (t, _) = tracker(providers = listOf(af))

        t.bootstrap()

        assertTrue(af.calls.any { it is FakeAnalyticsProvider.Call.Start })
    }

    @Test
    fun bootstrap_startFailureIsIsolated() = runTest {
        val failing = FakeAnalyticsProvider("AppsFlyer", throwOnStart = true)
        val ok = FakeAnalyticsProvider("Mixpanel")
        val (t, ctx) = tracker(providers = listOf(failing, ok))

        t.bootstrap()

        // Failing provider didn't record Start; ok provider did.
        assertFalse(failing.calls.any { it is FakeAnalyticsProvider.Call.Start })
        assertTrue(ok.calls.any { it is FakeAnalyticsProvider.Call.Start })

        val (_, crash, _) = ctx
        assertEquals(1, crash.reports.size)
        assertEquals("AppsFlyer", crash.reports.first().meta["provider"])
        assertEquals("providerStart", crash.reports.first().meta["op"])
    }

    @Test
    fun bootstrap_noProvidersIsNoOp() = runTest {
        val (t, _) = tracker(providers = emptyList())
        t.bootstrap()
        // No exceptions; nothing to assert beyond reaching here.
    }

    @Test
    fun track_mergesRegisteredSuperProperties() {
        // The whole point: a KMP/CMP-origin event (track called directly,
        // no Dart merge) still carries registered super-props.
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(mp))
        t.registerSuperProperties(mapOf("runner_id" to 42, "cluster_id" to "BLR"))

        t.track("home_screen_load", mapOf("source" to "icon"))

        val track = mp.calls.single() as FakeAnalyticsProvider.Call.Track
        // super-props (Int widened by sanitize) + call-site prop, all present.
        assertEquals(mapOf("runner_id" to 42L, "cluster_id" to "BLR", "source" to "icon"), track.props)
    }

    @Test
    fun track_callSitePropsWinOverSuperProperties() {
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(mp))
        t.registerSuperProperties(mapOf("cluster_id" to "BLR"))

        t.track("e", mapOf("cluster_id" to "MUM"))

        val track = mp.calls.single() as FakeAnalyticsProvider.Call.Track
        assertEquals("MUM", track.props["cluster_id"])
    }

    @Test
    fun registerSuperProperties_laterCallWinsAndAccumulates() {
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(mp))
        t.registerSuperProperties(mapOf("cluster_id" to "BLR", "region_id" to "S1"))
        t.registerSuperProperties(mapOf("cluster_id" to "MUM")) // overrides just cluster_id

        t.track("e")

        val track = mp.calls.single() as FakeAnalyticsProvider.Call.Track
        assertEquals(mapOf("cluster_id" to "MUM", "region_id" to "S1"), track.props)
    }

    @Test
    fun registerSuperProperties_emptyIsNoOp() {
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(mp))
        t.registerSuperProperties(mapOf("cluster_id" to "BLR"))
        t.registerSuperProperties(emptyMap())

        t.track("e")

        val track = mp.calls.single() as FakeAnalyticsProvider.Call.Track
        assertEquals(mapOf("cluster_id" to "BLR"), track.props)
    }

    @Test
    fun clearSuperProperties_dropsThemFromSubsequentEvents() {
        val mp = FakeAnalyticsProvider("Mixpanel")
        val (t, _) = tracker(providers = listOf(mp))
        t.registerSuperProperties(mapOf("runner_id" to 42))

        t.clearSuperProperties()
        t.track("post_logout_event", mapOf("source" to "icon"))

        val track = mp.calls.single() as FakeAnalyticsProvider.Call.Track
        // runner_id gone; only the call-site prop survives.
        assertEquals(mapOf("source" to "icon"), track.props)
    }
}
