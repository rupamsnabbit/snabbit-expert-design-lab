package com.snabbit.runner.shared.features.job.presentation.completed.rating

/**
 * Render state for the customer-rating card
 * ([com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRating]).
 *
 * Selection is optimistic — the tapped smiley flips to its solid variant immediately while the
 * `update_customer_rating` POST is in flight; a failure surfaces [errorMessage] but keeps the
 * selection (matching the Flutter `rateCustomerApi`, which only toasts on error).
 *
 * @property selectedRating the chosen rating 1..5 (1 = saddest); null before any tap.
 * @property isSubmitting the rating POST is in flight.
 * @property isError true when the last rating-submit failed (the caller resolves the copy from
 *   [rememberCustomerRatingStrings]); the selection is kept.
 */
data class CustomerRatingUiState(
    val selectedRating: Int? = null,
    val isSubmitting: Boolean = false,
    val isError: Boolean = false,
)
