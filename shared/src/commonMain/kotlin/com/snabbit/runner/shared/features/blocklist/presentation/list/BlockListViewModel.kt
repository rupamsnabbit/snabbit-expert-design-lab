package com.snabbit.runner.shared.features.blocklist.presentation.list

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository

/**
 * Drives the Block list.
 *
 * Plain class — constructed with the [BlockListRepository] seam, [BlockListStrings], and a [scope]
 * (the host's UI scope; the "callers pass CoroutineScope" convention, same as
 * [com.snabbit.runner.shared.features.language.presentation.LanguageViewModel]). Tests construct it with a fake + a test
 * scope; the Android host wires the real impl + its `lifecycleScope`.
 *
 * The list loads on init unless [autoLoad] is false — the block-customer "unblock to block" flow
 * composes this VM but defers the load to its MaxReached step. Unblock flips a per-row in-flight
 * flag, calls the data source, and on 2xx drops that customer from the list. One unblock runs at a
 * time; the shared state machine is exposed via [runUnblock] so that flow can reuse it (free a slot,
 * then re-block) instead of copying it. [BlockListUiState.maxLimit] is the "n/max" cap, read from the
 * `expert_max_blocked_customers` Remote Config value Dart mirrors into the KMP store; null (unknown →
 * header shows just "n") when unset or non-positive, so the server-enforced cap (`MAX_CUSTOMERS_BLOCKED`)
 * remains the real gate.
 */
class BlockListViewModel(
    private val dataSource: BlockListRepository,
    private val strings: BlockListStrings,
    private val scope: CoroutineScope,
    /**
     * Reads the "n/max" cap from the `expert_max_blocked_customers` Remote Config value Dart mirrors
     * into the KMP store (see [resolveMaxLimit]). Defaults to a no-op gateway returning the caller's
     * fallback — safe (cap unknown → header shows just "n") — mirroring
     * [com.snabbit.runner.shared.features.profile.ProfileViewModel].
     */
    private val remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, default -> default },
    autoLoad: Boolean = true,
) {
    private val _uiState = MutableStateFlow(BlockListUiState())
    val uiState: StateFlow<BlockListUiState> = _uiState.asStateFlow()

    init {
        if (autoLoad) load()
    }

    /** The single input channel — every screen action flows through here. */
    fun onIntent(intent: BlockListUiIntent) {
        when (intent) {
            BlockListUiIntent.Load -> load()
            is BlockListUiIntent.Unblock -> unblock(intent.customerId)
            BlockListUiIntent.ErrorShown -> _uiState.update { it.copy(errorMessage = null, errorIsTransient = false) }
        }
    }

    /** Loads the blocked-customer list, resolving the "n/max" cap from Remote Config (see [resolveMaxLimit]). */
    private fun load() {
        scope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null, errorIsTransient = false) }
            try {
                val customers = dataSource.getBlockedCustomers()
                _uiState.update { it.copy(isLoading = false, customers = customers, maxLimit = resolveMaxLimit()) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                // Load failure → the inline error panel with retry (not a transient toast).
                _uiState.update { it.copy(isLoading = false, errorMessage = strings.loadError, errorIsTransient = false) }
            }
        }
    }

    /**
     * The block cap for the "n/max" header — the `expert_max_blocked_customers` Remote Config value
     * Dart mirrors into the KMP store (pushed as a string). Null (unknown → header shows just "n")
     * when unset, non-numeric, or ≤0, so behaviour degrades safely when RC/the bridge is unavailable.
     */
    private fun resolveMaxLimit(): Int? =
        remoteConfig.getString(MAX_BLOCKED_CUSTOMERS_KEY, "").toIntOrNull()?.takeIf { it > 0 }

    /**
     * Unblocks [customerId], then removes it from the list on success. Guards against a second
     * unblock while one is in flight. On failure, surfaces a transient error and keeps the row.
     */
    private fun unblock(customerId: Int) {
        runUnblock(customerId) { jobId ->
            try {
                dataSource.unblock(customerId, jobId)
                UnblockResult.Removed()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                UnblockResult.Failed(strings.unblockError)
            }
        }
    }

    /**
     * The shared unblock state machine, exposed for composition. Guards a concurrent unblock, flips
     * the in-flight flag for [customerId], runs [operation], then applies its [UnblockResult] to the
     * list. The flag stays set for the whole [operation], so a chained follow-up keeps the row
     * spinning until it settles: the plain [unblock] just calls the data source, while the
     * block-customer "unblock to block" flow frees the slot then re-blocks the pending customer.
     * [operation] receives the customer's own `jobId` (or null) and must rethrow [CancellationException].
     */
    internal fun runUnblock(customerId: Int, operation: suspend (jobId: Int?) -> UnblockResult) {
        if (_uiState.value.unblockingCustomerId != null) return
        val jobId = _uiState.value.customers.firstOrNull { it.customerId == customerId }?.jobId
        scope.launch {
            _uiState.update { it.copy(unblockingCustomerId = customerId, errorMessage = null, errorIsTransient = false) }
            when (val result = operation(jobId)) {
                // Unblock / re-block outcomes are transient action errors → toast, even when
                // dropping the last row leaves the list empty (must not read as a load failure).
                is UnblockResult.Removed -> _uiState.update {
                    it.copy(
                        unblockingCustomerId = null,
                        customers = it.customers.filterNot { c -> c.customerId == customerId },
                        errorMessage = result.error,
                        errorIsTransient = true,
                    )
                }

                is UnblockResult.Failed -> _uiState.update {
                    it.copy(unblockingCustomerId = null, errorMessage = result.error, errorIsTransient = true)
                }

                UnblockResult.Reload -> {
                    _uiState.update { it.copy(unblockingCustomerId = null) }
                    load()
                }
            }
        }
    }

    private companion object {
        /** Must equal `RemoteConfigKeys.expertMaxBlockedCustomers` on the Flutter side (the RC mirror key). */
        const val MAX_BLOCKED_CUSTOMERS_KEY = "expert_max_blocked_customers"
    }
}

/**
 * The outcome of a [BlockListViewModel.runUnblock] operation, applied to the list state.
 *
 * - [Removed] — the customer was unblocked: drop the row. [error] optionally surfaces a follow-up
 *   failure (the block-customer flow freed the slot, but its re-block then failed).
 * - [Failed] — the unblock itself failed: keep the row and surface [error].
 * - [Reload] — refetch the list from the server (e.g. still over the cap — reconcile).
 */
internal sealed interface UnblockResult {
    data class Removed(val error: String? = null) : UnblockResult
    data class Failed(val error: String) : UnblockResult
    data object Reload : UnblockResult
}
