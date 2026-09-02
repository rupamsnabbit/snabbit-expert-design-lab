package com.snabbit.runner.shared.features.blocklist.presentation.list
import com.snabbit.runner.shared.features.blocklist.domain.model.BlockedCustomer

/**
 * Render state for the Block list.
 *
 * - load failure   → `errorMessage` set + `errorIsTransient` false → screen-level error panel with
 *   retry (shown inline when `customers` is empty).
 * - action failure → `errorMessage` set + `errorIsTransient` true → transient toast over the list.
 *   Covers unblock and the unblock-to-block re-block: a failed re-block can drop the last row and
 *   still needs a toast, so it must not be mistaken for a load failure (`errorIsTransient` keeps the
 *   two apart even when the list ends up empty).
 *
 * [maxLimit] is the block cap — the "max" in "n/max". There is no client-side cap value (the cap is
 * server-enforced, surfaced only as the `MAX_CUSTOMERS_BLOCKED` error), so it is normally null =
 * unknown and the header hides the "/max" suffix (rendering just "n") until a real cap is known.
 */
data class BlockListUiState(
    val isLoading: Boolean = true,
    val customers: List<BlockedCustomer> = emptyList(),
    val maxLimit: Int? = null,
    /** The customer whose unblock is in flight — its row spins; the others disable. Null when idle. */
    val unblockingCustomerId: Int? = null,
    val errorMessage: String? = null,
    /**
     * Classifies [errorMessage]: true = a transient action failure (unblock / re-block) shown as a
     * toast; false = a screen-level load failure shown as the inline error panel. Disambiguates the
     * two when the list is empty — a failed re-block that removed the last row must toast, not render
     * as "couldn't load". Meaningless while [errorMessage] is null.
     */
    val errorIsTransient: Boolean = false,
) {
    /** Number currently blocked — the "n" in "n/max". */
    val blockedCount: Int get() = customers.size

    /** True while any unblock is in flight (guards double-taps across rows). */
    val isUnblocking: Boolean get() = unblockingCustomerId != null
}
