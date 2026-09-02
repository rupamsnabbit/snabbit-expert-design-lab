package com.snabbit.runner.shared.features.job.presentation.contact

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import com.snabbit.runner.shared.features.job.data.contact.CallingDataSource
import com.snabbit.runner.shared.features.job.data.contact.CustomerContactLauncher
import com.snabbit.runner.shared.features.job.data.contact.FakeCallingDataSource
import com.snabbit.runner.shared.features.job.data.contact.FakeCustomerContactLauncher

@OptIn(ExperimentalCoroutinesApi::class)
class CustomerContactHandlerTest {

    private fun TestScope.handler(
        calling: CallingDataSource = FakeCallingDataSource(),
        launcher: CustomerContactLauncher = FakeCustomerContactLauncher(),
    ): DefaultCustomerContactHandler = DefaultCustomerContactHandler(
        calling = calling,
        launcher = launcher,
        scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
    )

    @Test
    fun call_success_placesMaskedCall_emitsFeedback_noFallback() = runTest {
        val calling = FakeCallingDataSource(result = true)
        val launcher = FakeCustomerContactLauncher()
        val h = handler(calling, launcher)

        h.call("9998887777")

        assertEquals(listOf("9998887777"), calling.calls)
        assertEquals(ContactFeedback.CallInitiated, h.feedback.first())
        assertTrue(launcher.dialed.isEmpty()) // no dialer fallback on success
    }

    @Test
    fun call_apiReturnsFalse_fallsBackToDialer() = runTest {
        val calling = FakeCallingDataSource(result = false)
        val launcher = FakeCustomerContactLauncher()
        val h = handler(calling, launcher)

        h.call("9998887777")

        assertEquals(listOf("9998887777"), launcher.dialed)
    }

    @Test
    fun call_apiThrows_fallsBackToDialer() = runTest {
        val calling = FakeCallingDataSource(error = RuntimeException("boom"))
        val launcher = FakeCustomerContactLauncher()
        val h = handler(calling, launcher)

        h.call("9998887777")

        assertEquals(listOf("9998887777"), launcher.dialed)
    }

    @Test
    fun call_blankPhone_emitsUnavailable_noApiNoDialer() = runTest {
        val calling = FakeCallingDataSource()
        val launcher = FakeCustomerContactLauncher()
        val h = handler(calling, launcher)

        h.call("   ")

        assertEquals(ContactFeedback.CallNumberUnavailable, h.feedback.first())
        assertTrue(calling.calls.isEmpty())
        assertTrue(launcher.dialed.isEmpty())
    }

    @Test
    fun openMaps_delegatesToLauncher_ignoresNull() = runTest {
        val launcher = FakeCustomerContactLauncher()
        val h = handler(launcher = launcher)

        h.openMaps(12.9, 77.6)
        h.openMaps(null, 77.6)
        h.openMaps(12.9, null)

        assertEquals(listOf(12.9 to 77.6), launcher.mapsOpened)
    }

    @Test
    fun openChat_delegatesToLauncher() = runTest {
        val launcher = FakeCustomerContactLauncher()
        val h = handler(launcher = launcher)

        h.openChat()

        assertEquals(1, launcher.chatOpenedCount)
    }
}
