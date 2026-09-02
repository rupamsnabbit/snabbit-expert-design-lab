package com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository
import com.snabbit.runner.shared.features.blocklist.data.repository.MaxCustomersBlockedException
import com.snabbit.runner.shared.features.blocklist.presentation.list.BlockListUiIntent
import com.snabbit.runner.shared.features.blocklist.presentation.list.BlockListUiState
import com.snabbit.runner.shared.features.blocklist.presentation.list.BlockListViewModel
import com.snabbit.runner.shared.features.blocklist.presentation.list.UnblockResult

/**
 * Drives the block-customer sheet — the "Are you sure you want to block?" flow.
 *
 * Plain class + injected [scope] (the "callers pass CoroutineScope" convention, as
 * [com.snabbit.runner.shared.features.language.presentation.LanguageViewModel]). Mirrors the Flutter `BlockBottomSheet`:
 *  - **Yes** → block the customer. On success, fire [onBlocked] (the host closes the sheet +
 *    refreshes). On `MAX_CUSTOMERS_BLOCKED`, switch to [BlockCustomerStep.MaxReached] and load the
 *    block list.
 *  - **MaxReached** → the runner unblocks someone; that frees a slot and re-blocks the pending
 *    customer in one action (matching the Flutter manage-list unblock), then fires [onBlocked].
 *
 * The MaxReached list-state is delegated to a composed [BlockListViewModel] (exposed as
 * [blockListState]) rather than a second copy of the list state machine: loads route through its
 * `Load` intent and the unblock-to-block reuses its [BlockListViewModel.runUnblock].
 *
 * [onBlocked] is invoked from [scope] (the host's), not a composition-tied collector, so a block that
 * completes after the sheet has been dismissed still refreshes the host (ECPO review finding).
 *
 * @param customerId the customer to block. @param jobId the job it happened on (echoed to the API).
 * @param onBlocked fired once the customer is blocked (directly, or after freeing a slot).
 */
class BlockCustomerViewModel(
    private val customerId: Int,
    private val jobId: Int?,
    private val dataSource: BlockListRepository,
    private val strings: BlockCustomerStrings,
    private val scope: CoroutineScope,
    private val onBlocked: () -> Unit,
    /** Passed to the composed [BlockListViewModel] so the MaxReached list shows the "n/max" cap. */
    private val remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, default -> default },
) {
    private val _uiState = MutableStateFlow(BlockCustomerUiState())
    val uiState: StateFlow<BlockCustomerUiState> = _uiState.asStateFlow()

    /**
     * The MaxReached step's block-list state — owned by a composed [BlockListViewModel] (the single
     * source of truth for load / unblock / errors). Load is deferred: it only fetches once the flow
     * hits [BlockCustomerStep.MaxReached].
     */
    private val blockListViewModel = BlockListViewModel(
        dataSource = dataSource,
        strings = strings.unblockToBlock.blockList,
        scope = scope,
        remoteConfig = remoteConfig,
        autoLoad = false,
    )
    val blockListState: StateFlow<BlockListUiState> get() = blockListViewModel.uiState

    fun onIntent(intent: BlockCustomerUiIntent) {
        when (intent) {
            BlockCustomerUiIntent.ConfirmBlock -> confirmBlock()
            is BlockCustomerUiIntent.Unblock -> unblockThenBlock(intent.customerId)
            BlockCustomerUiIntent.RetryLoadList -> blockListViewModel.onIntent(BlockListUiIntent.Load)
            BlockCustomerUiIntent.ErrorShown -> {
                _uiState.update { it.copy(errorMessage = null) }
                blockListViewModel.onIntent(BlockListUiIntent.ErrorShown)
            }
        }
    }

    /** "Yes": block the customer; on the cap error, fall through to the manage-list step. */
    private fun confirmBlock() {
        if (_uiState.value.isSubmitting) return
        scope.launch {
            _uiState.update { it.copy(isSubmitting = true, errorMessage = null) }
            try {
                dataSource.block(customerId, jobId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: MaxCustomersBlockedException) {
                _uiState.update { it.copy(isSubmitting = false, step = BlockCustomerStep.MaxReached) }
                blockListViewModel.onIntent(BlockListUiIntent.Load)
                return@launch
            } catch (e: Throwable) {
                _uiState.update { it.copy(isSubmitting = false, errorMessage = strings.genericError) }
                return@launch
            }
            _uiState.update { it.copy(isSubmitting = false) }
            onBlocked()
        }
    }

    /** MaxReached: unblock [unblockCustomerId] to free a slot, then block the pending customer. */
    private fun unblockThenBlock(unblockCustomerId: Int) {
        blockListViewModel.runUnblock(unblockCustomerId) { unblockJobId ->
            // Free a slot first. A failure here is a real unblock failure (nothing changed
            // server-side) — surface the unblock error and keep the row.
            try {
                dataSource.unblock(unblockCustomerId, unblockJobId ?: jobId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                return@runUnblock UnblockResult.Failed(strings.unblockToBlock.blockList.unblockError)
            }
            // Slot freed — now block the pending customer.
            try {
                dataSource.block(customerId, jobId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: MaxCustomersBlockedException) {
                // Still over the cap (e.g. a stale list) — refresh and stay on the manage step.
                return@runUnblock UnblockResult.Reload
            } catch (e: Throwable) {
                // Unblock succeeded but block didn't: drop the freed customer (as the plain unblock
                // does, so the list can't desync) and show a block-specific error rather than the
                // misleading "couldn't unblock" copy.
                return@runUnblock UnblockResult.Removed(strings.genericError)
            }
            onBlocked()
            UnblockResult.Removed()
        }
    }
}
