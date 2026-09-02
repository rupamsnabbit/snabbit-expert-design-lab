package com.snabbit.runner.shared.features.blocklist.presentation.list

/**
 * Every user action on the Block list, as data. The screen sends these to
 * [BlockListViewModel.onIntent] — a single input channel, so all state transitions live in one
 * exhaustive `when` (child composables receive `onIntent`, never the ViewModel).
 */
sealed interface BlockListUiIntent {
    /** Load / reload the blocked-customer list (initial + retry). */
    data object Load : BlockListUiIntent

    /** Unblock the customer with [customerId]. */
    data class Unblock(val customerId: Int) : BlockListUiIntent

    /** A transient (unblock-failure) error has been shown — clear it. */
    data object ErrorShown : BlockListUiIntent
}
