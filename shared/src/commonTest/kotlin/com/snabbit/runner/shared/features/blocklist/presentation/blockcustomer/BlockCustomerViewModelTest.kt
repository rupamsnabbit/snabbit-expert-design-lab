package com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer
import com.snabbit.runner.shared.features.blocklist.data.repository.MaxCustomersBlockedException
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

@OptIn(ExperimentalCoroutinesApi::class)
class BlockCustomerViewModelTest {

    private fun TestScope.viewModel(
        dataSource: BlockListRepository = FakeBlockListRepository(),
        customerId: Int = 42,
        jobId: Int? = 900,
        onBlocked: () -> Unit = {},
        remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, default -> default },
    ): BlockCustomerViewModel = BlockCustomerViewModel(
        customerId = customerId,
        jobId = jobId,
        dataSource = dataSource,
        strings = BlockCustomerStrings(),
        scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
        onBlocked = onBlocked,
        remoteConfig = remoteConfig,
    )

    @Test
    fun confirmBlock_success_blocksAndFiresOnBlocked() = runTest {
        val dataSource = FakeBlockListRepository()
        var blockedCount = 0
        val vm = viewModel(dataSource = dataSource, onBlocked = { blockedCount++ })

        vm.onIntent(BlockCustomerUiIntent.ConfirmBlock)

        assertEquals(listOf<Pair<Int, Int?>>(42 to 900), dataSource.blockCalls)
        assertFalse(vm.uiState.value.isSubmitting)
        assertEquals(BlockCustomerStep.Confirm, vm.uiState.value.step)
        assertEquals(1, blockedCount) // host callback fired once
    }

    @Test
    fun confirmBlock_maxReached_switchesToMaxStep_andLoadsList() = runTest {
        val dataSource = FakeBlockListRepository(blockError = MaxCustomersBlockedException())
        val vm = viewModel(dataSource = dataSource)

        vm.onIntent(BlockCustomerUiIntent.ConfirmBlock)

        assertEquals(BlockCustomerStep.MaxReached, vm.uiState.value.step)
        assertFalse(vm.uiState.value.isSubmitting)
        val listState = vm.blockListState.value
        assertFalse(listState.isLoading)
        assertEquals(3, listState.customers.size) // list loaded for the unblock surface
        assertNull(listState.maxLimit) // no client-side cap — stays unknown
    }

    @Test
    fun confirmBlock_genericError_showsError_staysOnConfirm() = runTest {
        val dataSource = FakeBlockListRepository(blockError = RuntimeException("boom"))
        val vm = viewModel(dataSource = dataSource)

        vm.onIntent(BlockCustomerUiIntent.ConfirmBlock)

        val state = vm.uiState.value
        assertEquals(BlockCustomerStep.Confirm, state.step)
        assertFalse(state.isSubmitting)
        assertEquals("Something went wrong. Please try again.", state.errorMessage)
    }

    @Test
    fun unblock_inMaxStep_freesSlotThenReblocks_andFiresOnBlocked() = runTest {
        // Enter MaxReached first (block hits the cap, list loads).
        val dataSource = FakeBlockListRepository(blockError = MaxCustomersBlockedException())
        var blockedCount = 0
        val vm = viewModel(dataSource = dataSource, onBlocked = { blockedCount++ })
        vm.onIntent(BlockCustomerUiIntent.ConfirmBlock)
        assertEquals(BlockCustomerStep.MaxReached, vm.uiState.value.step)

        // Now block succeeds; unblock customer #2 (jobId 102 from the sample) → re-block the pending one.
        dataSource.blockError = null
        vm.onIntent(BlockCustomerUiIntent.Unblock(2))

        assertEquals(listOf<Pair<Int, Int?>>(2 to 102), dataSource.unblockCalls)
        assertEquals(listOf<Pair<Int, Int?>>(42 to 900), dataSource.blockCalls) // pending re-blocked
        assertNull(vm.blockListState.value.unblockingCustomerId)
        assertEquals(1, blockedCount)
    }

    @Test
    fun errorShown_clearsErrors() = runTest {
        val vm = viewModel(dataSource = FakeBlockListRepository(blockError = RuntimeException("boom")))
        vm.onIntent(BlockCustomerUiIntent.ConfirmBlock)
        assertEquals("Something went wrong. Please try again.", vm.uiState.value.errorMessage)

        vm.onIntent(BlockCustomerUiIntent.ErrorShown)

        assertNull(vm.uiState.value.errorMessage)
    }

    @Test
    fun maxReached_composedList_showsCap_fromRemoteConfig() = runTest {
        // The cap threads Job → BlockCustomer → the composed BlockList VM: the MaxReached list header
        // shows "n/max" from the mirrored RC value.
        val dataSource = FakeBlockListRepository(blockError = MaxCustomersBlockedException())
        val vm = viewModel(dataSource = dataSource, remoteConfig = rcWithMaxBlocked("5"))

        vm.onIntent(BlockCustomerUiIntent.ConfirmBlock)

        assertEquals(BlockCustomerStep.MaxReached, vm.uiState.value.step)
        assertEquals(5, vm.blockListState.value.maxLimit)
    }

    /** A gateway returning [value] for the block-cap key and the caller's fallback for anything else. */
    private fun rcWithMaxBlocked(value: String) = object : RemoteConfigGateway {
        override fun getBool(key: String, default: Boolean) = default
        override fun getString(key: String, default: String) =
            if (key == "expert_max_blocked_customers") value else default
    }
}
