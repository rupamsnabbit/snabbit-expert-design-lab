package com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer

/**
 * State of the block-customer confirmation flow — the [com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer.BlockCustomerSheet]
 * bottom sheet the runner sees after tapping **Block** on a
 * [com.snabbit.runner.shared.features.job.presentation.completed.BlockCustomerCard]. Owned by [BlockCustomerViewModel].
 *
 * Mirrors the Flutter `BlockState` machine (`rating_block_handler.dart`): a [BlockCustomerStep.Confirm]
 * "Are you sure?" step, and — when the block hits the server cap (`MAX_CUSTOMERS_BLOCKED`) — a
 * [BlockCustomerStep.MaxReached] step that shows the "unblock to block" surface so the runner can free
 * a slot. A successful block is a one-shot signal (the host `onBlocked` callback), not a state.
 *
 * The MaxReached list-state is not held here — it lives in the composed block-list VM (exposed via
 * [BlockCustomerViewModel.blockListState]).
 *
 * @property step which sheet step is showing.
 * @property isSubmitting the confirm-step block call is in flight (the Yes button spins).
 * @property errorMessage confirm-step failure copy; null when none.
 */
data class BlockCustomerUiState(
    val step: BlockCustomerStep = BlockCustomerStep.Confirm,
    val isSubmitting: Boolean = false,
    val errorMessage: String? = null,
)

/** The steps the block-customer sheet morphs through (no "blocked" step — a success closes the sheet). */
enum class BlockCustomerStep {
    /** "Are you sure you want to block?" with No / Yes. */
    Confirm,

    /** At the block cap → the "unblock to block" surface (block list + unblock-to-free-a-slot). */
    MaxReached,
}
