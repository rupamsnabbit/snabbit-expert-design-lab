package com.snabbit.runner.shared.features.blocklist.presentation.list
import com.snabbit.runner.shared.features.blocklist.domain.model.BlockedCustomer
import com.snabbit.runner.shared.features.blocklist.data.remote.FakeBlockListRepository
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class BlockListViewModelTest {

    /**
     * Builds a [BlockListViewModel] on an [UnconfinedTestDispatcher] scope: coroutines it launches
     * (load on init, unblock) run eagerly to completion against the non-suspending fakes, so
     * assertions can read state directly (mirrors LanguageViewModelTest).
     */
    private fun TestScope.viewModel(
        dataSource: BlockListRepository = FakeBlockListRepository(),
        strings: BlockListStrings = BlockListStrings(),
        remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, default -> default },
    ): BlockListViewModel = BlockListViewModel(
        dataSource = dataSource,
        strings = strings,
        scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
        remoteConfig = remoteConfig,
    )

    @Test
    fun load_populatesCustomers_maxLimitUnknown() = runTest {
        val vm = viewModel()

        val state = vm.uiState.value
        assertFalse(state.isLoading)
        assertEquals(3, state.customers.size)
        assertEquals(3, state.blockedCount)
        assertNull(state.maxLimit) // no client-side cap — the header hides the "/max"
        assertNull(state.errorMessage)
    }

    @Test
    fun load_failure_setsError_andLeavesListEmpty() = runTest {
        val vm = viewModel(dataSource = FakeBlockListRepository(error = RuntimeException("network")))

        val state = vm.uiState.value
        assertFalse(state.isLoading)
        assertTrue(state.customers.isEmpty())
        assertEquals("Couldn't load your block list", state.errorMessage)
    }

    @Test
    fun unblock_success_removesCustomer_sendsItsJobId() = runTest {
        val dataSource = FakeBlockListRepository()
        val vm = viewModel(dataSource = dataSource)

        vm.onIntent(BlockListUiIntent.Unblock(2))

        val state = vm.uiState.value
        assertEquals(listOf<Pair<Int, Int?>>(2 to 102), dataSource.unblockCalls) // customerId + its jobId
        assertEquals(listOf(1, 3), state.customers.map { it.customerId })
        assertEquals(2, state.blockedCount)
        assertNull(state.maxLimit) // no client-side cap — stays unknown
        assertNull(state.unblockingCustomerId)
        assertNull(state.errorMessage)
    }

    @Test
    fun unblock_failure_surfacesError_andKeepsCustomer() = runTest {
        val dataSource = FakeBlockListRepository(unblockError = RuntimeException("nope"))
        val vm = viewModel(dataSource = dataSource)

        vm.onIntent(BlockListUiIntent.Unblock(2))

        val state = vm.uiState.value
        assertEquals(3, state.customers.size) // still present
        assertEquals("Couldn't unblock. Please try again.", state.errorMessage)
        assertNull(state.unblockingCustomerId)
    }

    @Test
    fun errorShown_clearsTransientError() = runTest {
        val vm = viewModel(dataSource = FakeBlockListRepository(unblockError = RuntimeException("nope")))
        vm.onIntent(BlockListUiIntent.Unblock(1))
        assertEquals("Couldn't unblock. Please try again.", vm.uiState.value.errorMessage)

        vm.onIntent(BlockListUiIntent.ErrorShown)

        assertNull(vm.uiState.value.errorMessage)
    }

    @Test
    fun reblockFailure_afterUnblockingLastRow_isTransientError_notLoadFailure() = runTest {
        // The unblock-to-block flow frees the last slot (row removed) but the re-block then fails,
        // which the shared machine reports as Removed(error). The now-empty list + error must read as
        // a transient toast, not the "couldn't load" panel.
        val dataSource = FakeBlockListRepository(
            customers = listOf(BlockedCustomer(customerId = 7, name = "Solo", jobId = 700)),
        )
        val vm = viewModel(dataSource = dataSource)

        vm.runUnblock(7) { UnblockResult.Removed("Couldn't block. Please try again.") }

        val state = vm.uiState.value
        assertTrue(state.customers.isEmpty()) // last row dropped
        assertEquals("Couldn't block. Please try again.", state.errorMessage)
        assertTrue(state.errorIsTransient) // toast, not the load-error panel
    }

    @Test
    fun unblock_customerWithNoJob_sendsNullJobId() = runTest {
        val dataSource = FakeBlockListRepository(
            customers = listOf(BlockedCustomer(customerId = 7, name = "No Job", jobId = null)),
        )
        val vm = viewModel(dataSource = dataSource)

        vm.onIntent(BlockListUiIntent.Unblock(7))

        assertEquals(listOf<Pair<Int, Int?>>(7 to null), dataSource.unblockCalls)
        assertTrue(vm.uiState.value.customers.isEmpty())
    }

    @Test
    fun load_populatesMaxLimit_fromRemoteConfig() = runTest {
        // The RC mirror pushes the cap as a string (`expert_max_blocked_customers`); the VM parses it.
        val vm = viewModel(remoteConfig = rcWithMaxBlocked("5"))

        assertEquals(5, vm.uiState.value.maxLimit) // header renders "n/5"
    }

    @Test
    fun load_maxLimitNull_whenRemoteConfigBlankNonNumericOrNonPositive() = runTest {
        // Empty (unset), non-numeric, and ≤0 all mean "unknown" → header shows just "n".
        assertNull(viewModel(remoteConfig = rcWithMaxBlocked("")).uiState.value.maxLimit)
        assertNull(viewModel(remoteConfig = rcWithMaxBlocked("abc")).uiState.value.maxLimit)
        assertNull(viewModel(remoteConfig = rcWithMaxBlocked("0")).uiState.value.maxLimit)
    }

    /** A gateway returning [value] for the block-cap key and the caller's fallback for anything else. */
    private fun rcWithMaxBlocked(value: String) = object : RemoteConfigGateway {
        override fun getBool(key: String, default: Boolean) = default
        override fun getString(key: String, default: String) =
            if (key == "expert_max_blocked_customers") value else default
    }
}
