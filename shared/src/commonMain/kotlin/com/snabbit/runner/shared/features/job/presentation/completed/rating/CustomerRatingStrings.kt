package com.snabbit.runner.shared.features.job.presentation.completed.rating

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.rating_error
import com.snabbit.runner.shared.resources.rating_title
import org.jetbrains.compose.resources.stringResource
import org.koin.mp.KoinPlatform.getKoin

/**
 * UI text for the customer-rating card. Two-tier i18n (per PR #452): the English fallbacks live in
 * `composeResources` and are resolved by [rememberCustomerRatingStrings]; the host can still override
 * any label at runtime by passing the app's server-driven i18n value into the corresponding field.
 */
data class CustomerRatingStrings(
    val title: String,
    val rateError: String,
)

/**
 * [CustomerRatingStrings] with each label defaulted to its `composeResources` fallback. Pass a named
 * argument to override just that label with a server-driven value.
 */
@Composable
fun rememberCustomerRatingStrings(
    title: String = stringResource(Res.string.rating_title),
    rateError: String = stringResource(Res.string.rating_error),
): CustomerRatingStrings = remember(title, rateError) {
    CustomerRatingStrings(title = title, rateError = rateError)
}.localized(getKoin().get())

/**
 * Overlays the server-driven i18n map onto these [CustomerRatingStrings] (baked into
 * [rememberCustomerRatingStrings]); absent keys fall back to composeResources English.
 */
fun CustomerRatingStrings.localized(store: LocalizationStore): CustomerRatingStrings = copy(
    title = store.getMessage("job_completed.rate_customer", title),
    rateError = store.getMessage("job_completed.rating.error", rateError),
)
