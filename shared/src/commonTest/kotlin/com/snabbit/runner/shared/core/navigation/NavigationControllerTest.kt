package com.snabbit.runner.shared.core.navigation

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.analytics.RecordingCrashReporter
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

private data class TestDest(val id: String) : Destination

/** Records the cross-layer commands so tests can assert without an Activity. */
private class FakeNavigationHost : NavigationHost {
    val flutterRoutes = mutableListOf<Pair<String, Map<String, String>>>()
    val keepHostRoutes = mutableListOf<KeepHostCall>()
    val results = mutableListOf<Map<String, String>>()
    var exitCalls = 0

    override var isRootShell: Boolean = false

    override fun openFlutterRoute(route: String, args: Map<String, String>) {
        flutterRoutes += route to args
    }

    override fun openFlutterRouteKeepingHost(
        route: String,
        args: Map<String, String>,
        recreateKey: String,
        recreateArgs: Map<String, String>,
    ) {
        keepHostRoutes += KeepHostCall(route, args, recreateKey, recreateArgs)
    }

    override fun finishWithResult(result: Map<String, String>) {
        results += result
    }

    override fun exit() {
        exitCalls++
    }

    data class KeepHostCall(
        val route: String,
        val args: Map<String, String>,
        val recreateKey: String,
        val recreateArgs: Map<String, String>,
    )
}

class NavigationControllerTest {

    private val logger = FakeLogger()
    private val crashReporter = RecordingCrashReporter()

    private fun controller(vararg mappings: DeeplinkMapping) =
        NavigationController(
            deeplinkResolver = DeeplinkResolver(mappings.toList()),
            logger = logger,
            crashReporter = crashReporter,
        )

    private fun controllerWithFactories(vararg factories: DestinationFactory) =
        NavigationController(
            deeplinkResolver = DeeplinkResolver(emptyList()),
            destinationFactories = factories.toList(),
            logger = logger,
            crashReporter = crashReporter,
        )

    @Test
    fun navigate_pushesOntoBackStack() {
        val c = controller()
        c.navigate(TestDest("a"))
        c.navigate(TestDest("b"))

        assertEquals(listOf(TestDest("a"), TestDest("b")), c.backStack.toList())
        assertEquals(TestDest("b"), c.current)
        assertTrue(c.canGoBack)
    }

    @Test
    fun back_withinStack_popsTop() {
        val c = controller()
        c.navigate(TestDest("a"))
        c.navigate(TestDest("b"))

        c.back()

        assertEquals(listOf(TestDest("a")), c.backStack.toList())
        assertFalse(c.canGoBack)
    }

    @Test
    fun back_atRoot_emptiesStack() {
        val c = controller()
        c.navigate(TestDest("a"))

        c.back()

        // With no host attached, an empty back stack IS the "return to Flutter" signal.
        assertTrue(c.backStack.isEmpty())
    }

    @Test
    fun back_atRoot_withHost_callsExitAndKeepsStack() {
        val c = controller()
        c.navigate(TestDest("a"))
        val host = FakeNavigationHost()
        c.host = host

        c.back()

        // At the root with a host, back exits via host.exit() (finish while still composed
        // → smooth close, no blank flash). The stack is NOT emptied here — it's cleared on
        // the host's terminal teardown.
        assertEquals(1, host.exitCalls)
        assertEquals(listOf(TestDest("a")), c.backStack.toList())
    }

    @Test
    fun replace_swapsTopOnly() {
        val c = controller()
        c.navigate(TestDest("a"))
        c.navigate(TestDest("b"))

        c.replace(TestDest("c"))

        assertEquals(listOf(TestDest("a"), TestDest("c")), c.backStack.toList())
    }

    @Test
    fun replace_onEmptyStack_adds() {
        val c = controller()

        c.replace(TestDest("a"))

        assertEquals(listOf(TestDest("a")), c.backStack.toList())
    }

    @Test
    fun resetTo_clearsAndSetsSingle() {
        val c = controller()
        c.navigate(TestDest("a"))
        c.navigate(TestDest("b"))

        c.resetTo(TestDest("root"))

        assertEquals(listOf(TestDest("root")), c.backStack.toList())
    }

    @Test
    fun handleResolvedDeeplink_known_pushesAndReturnsTrue() {
        val c = controller(
            DeeplinkMapping { value, _ -> if (value == "job") TestDest("job") else null },
        )

        val handled = c.handleResolvedDeeplink("job", emptyMap())

        assertTrue(handled)
        assertEquals(listOf(TestDest("job")), c.backStack.toList())
    }

    @Test
    fun handleResolvedDeeplink_unknown_returnsFalseAndLeavesStack() {
        val c = controller(
            DeeplinkMapping { value, _ -> if (value == "job") TestDest("job") else null },
        )

        val handled = c.handleResolvedDeeplink("unknown", emptyMap())

        assertFalse(handled)
        assertTrue(c.backStack.isEmpty())
    }

    @Test
    fun openByKey_known_pushesAndReturnsTrue() {
        val c = controllerWithFactories(
            DestinationFactory { key, args -> if (key == "job") TestDest(args["id"] ?: "none") else null },
        )

        val opened = c.openByKey("job", mapOf("id" to "7"))

        assertTrue(opened)
        assertEquals(listOf(TestDest("7")), c.backStack.toList())
    }

    @Test
    fun openByKey_unknown_returnsFalseAndLeavesStack() {
        val c = controllerWithFactories(
            DestinationFactory { key, _ -> if (key == "job") TestDest("job") else null },
        )

        val opened = c.openByKey("unknown", emptyMap())

        assertFalse(opened)
        assertTrue(c.backStack.isEmpty())
    }

    @Test
    fun requestFlutterRoute_callsHost() {
        val c = controller()
        val host = FakeNavigationHost()
        c.host = host

        c.requestFlutterRoute("/chat", mapOf("source" to "native"))

        assertEquals(listOf("/chat" to mapOf("source" to "native")), host.flutterRoutes)
    }

    @Test
    fun requestFlutterRoute_withNoHost_doesNotCrash() {
        val c = controller()
        c.requestFlutterRoute("/chat") // host == null → no-op, must not throw
    }

    @Test
    fun requestFlutterRouteKeepingHost_callsHostAndPreservesBackStack() {
        val c = controller()
        c.navigate(TestDest("b"))
        val host = FakeNavigationHost()
        c.host = host

        c.requestFlutterRouteKeepingHost(
            route = "/chat",
            args = mapOf("source" to "native"),
            recreateKey = "jobDetails",
            recreateArgs = mapOf("id" to "42"),
        )

        assertEquals(
            listOf(
                FakeNavigationHost.KeepHostCall(
                    "/chat",
                    mapOf("source" to "native"),
                    "jobDetails",
                    mapOf("id" to "42"),
                ),
            ),
            host.keepHostRoutes,
        )
        // The native back stack is untouched — B stays alive behind the handoff.
        assertEquals(listOf(TestDest("b")), c.backStack.toList())
    }

    @Test
    fun requestFlutterRouteKeepingHost_withNoHost_doesNotCrash() {
        val c = controller()
        // host == null → no-op, must not throw.
        c.requestFlutterRouteKeepingHost(
            route = "/chat",
            recreateKey = "jobDetails",
        )
    }

    @Test
    fun finishWithResult_withHost_deliversResultAndKeepsStack() {
        val c = controller()
        c.navigate(TestDest("a"))
        val host = FakeNavigationHost()
        c.host = host

        c.finishWithResult(mapOf("picked" to "x"))

        assertEquals(listOf(mapOf("picked" to "x")), host.results)
        // Stack is NOT emptied here (kept composed for a smooth close, no flash); it's
        // cleared on the host's terminal teardown.
        assertEquals(listOf(TestDest("a")), c.backStack.toList())
    }

    @Test
    fun finishWithResult_withNoHost_clearsStack() {
        val c = controller()
        c.navigate(TestDest("a"))

        c.finishWithResult(mapOf("picked" to "x"))

        // No host → empty stack is the return-to-Flutter signal.
        assertTrue(c.backStack.isEmpty())
    }

    @Test
    fun reportFailure_logsAndReports() {
        val c = controller()

        c.reportFailure("boom")

        assertTrue(logger.entries.any { it.level == FakeLogger.Level.ERROR })
        assertEquals(1, crashReporter.reports.size)
        assertEquals("boom", crashReporter.reports.first().throwable.message)
    }

    @Test
    fun clear_emptiesBackStack() {
        val c = controller()
        c.navigate(TestDest("a"))
        c.navigate(TestDest("b"))

        c.clear()

        assertTrue(c.backStack.isEmpty())
    }

    @Test
    fun navigateForResult_completesWithResultFromPopWithResult() = runTest {
        val c = controller()
        c.navigate(TestDest("a"))

        val deferred = async { c.navigateForResult(TestDest("picker")) }
        testScheduler.runCurrent() // run the push + suspend at await
        assertEquals(TestDest("picker"), c.current)

        c.popWithResult(mapOf("picked" to "x"))

        assertEquals(mapOf("picked" to "x"), deferred.await())
        assertEquals(listOf(TestDest("a")), c.backStack.toList())
    }

    @Test
    fun navigateForResult_completesNull_onPlainBack() = runTest {
        val c = controller()
        c.navigate(TestDest("a"))

        val deferred = async { c.navigateForResult(TestDest("picker")) }
        testScheduler.runCurrent()

        c.back() // backed out without a result

        assertNull(deferred.await())
        assertEquals(listOf(TestDest("a")), c.backStack.toList())
    }

    @Test
    fun popUntil_popsToMatchingDestination() {
        val c = controller()
        c.navigate(TestDest("a"))
        c.navigate(TestDest("b"))
        c.navigate(TestDest("c"))

        c.popUntil { it == TestDest("a") }

        assertEquals(listOf(TestDest("a")), c.backStack.toList())
    }

    @Test
    fun pushAndRemoveUntil_removesUntilPredicateThenPushes() {
        val c = controller()
        c.navigate(TestDest("a"))
        c.navigate(TestDest("b"))
        c.navigate(TestDest("c"))

        c.pushAndRemoveUntil(TestDest("d")) { it == TestDest("a") }

        assertEquals(listOf(TestDest("a"), TestDest("d")), c.backStack.toList())
    }

    @Test
    fun maybePop_popsWhenNotAtRoot_elseFalseNoExit() {
        val c = controller()
        c.navigate(TestDest("a"))

        assertFalse(c.maybePop()) // at root → no pop, no exit
        assertEquals(listOf(TestDest("a")), c.backStack.toList())

        c.navigate(TestDest("b"))
        assertTrue(c.maybePop()) // pops b
        assertEquals(listOf(TestDest("a")), c.backStack.toList())
    }

    @Test
    fun popUntil_noMatch_stopsAtRootAndReports() {
        val c = controller()
        c.navigate(TestDest("a"))
        c.navigate(TestDest("b"))
        c.navigate(TestDest("c"))

        c.popUntil { false } // never matches

        // Stops at the root instead of draining to empty (which would hit the host's
        // blank-frame finish path), and reports the misuse.
        assertEquals(listOf(TestDest("a")), c.backStack.toList())
        assertTrue(crashReporter.reports.any { it.throwable.message?.contains("popUntil") == true })
    }

    @Test
    fun openByKey_whileNativeSessionActive_reportsNestedSessionButStillOpens() {
        val c = controllerWithFactories(
            DestinationFactory { key, _ -> if (key == "job") TestDest("job") else null },
        )
        c.navigate(TestDest("home")) // a native session already exists

        val opened = c.openByKey("job", emptyMap())

        // Behaviour is unchanged for now (it still appends), but the unsupported nested
        // native<->Flutter session is reported so it's visible until session-scoping lands.
        assertTrue(opened)
        assertEquals(listOf(TestDest("home"), TestDest("job")), c.backStack.toList())
        assertTrue(
            crashReporter.reports.any {
                it.throwable.message?.contains("native session is already active") == true
            },
        )
    }

    @Test
    fun navigateForResult_twoConcurrentAwaiters_completeIndependently() = runTest {
        val c = controller()
        c.navigate(TestDest("root"))

        val awaiterA = async { c.navigateForResult(TestDest("A")) }
        testScheduler.runCurrent() // [root, A], A awaiting @1
        val awaiterB = async { c.navigateForResult(TestDest("B")) }
        testScheduler.runCurrent() // [root, A, B], B awaiting @2

        c.popWithResult(mapOf("who" to "B")) // pops B WITH a result
        assertEquals(mapOf("who" to "B"), awaiterB.await())

        c.back() // pops A WITHOUT a result → its awaiter gets null via reconcile
        assertNull(awaiterA.await())
        assertEquals(listOf(TestDest("root")), c.backStack.toList())
    }
}
