package com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer

/**
 * User actions on the block-customer sheet. Sent to [BlockCustomerViewModel.onIntent] (single input
 * channel). "No" is not here — it just closes the sheet via the composable's `onDismiss`.
 */
sealed interface BlockCustomerUiIntent {
    /** "Yes" — confirm and block the customer. */
    data object ConfirmBlock : BlockCustomerUiIntent

    /** MaxReached step: unblock [customerId] to free a slot, then block the pending customer. */
    data class Unblock(val customerId: Int) : BlockCustomerUiIntent

    /** MaxReached step: reload the block list (retry after a load failure). */
    data object RetryLoadList : BlockCustomerUiIntent

    /** A transient error has been shown — clear it. */
    data object ErrorShown : BlockCustomerUiIntent
}
