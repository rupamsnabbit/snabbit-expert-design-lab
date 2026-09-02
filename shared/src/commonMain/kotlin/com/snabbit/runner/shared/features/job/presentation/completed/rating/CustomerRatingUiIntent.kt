package com.snabbit.runner.shared.features.job.presentation.completed.rating

/** User actions on the customer-rating card, sent to [CustomerRatingViewModel.onIntent]. */
sealed interface CustomerRatingUiIntent {
    /** The runner tapped the smiley for [rating] (1 = saddest .. 5 = happiest). Local-only selection. */
    data class SelectRating(val rating: Int) : CustomerRatingUiIntent

    /** "Ready for next job" — submit the selected rating, then refresh `current_state` to advance. */
    data object Submit : CustomerRatingUiIntent
}
