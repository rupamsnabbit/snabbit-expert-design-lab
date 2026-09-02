package com.snabbit.runner.shared.features.job.presentation.completed.rating

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingStrings
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingUiState
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.snabbit_smiley_delighted_active
import com.snabbit.runner.shared.resources.snabbit_smiley_delighted_stroke
import com.snabbit.runner.shared.resources.snabbit_smiley_dissatisfied_active
import com.snabbit.runner.shared.resources.snabbit_smiley_dissatisfied_stroke
import com.snabbit.runner.shared.resources.snabbit_smiley_happy_active
import com.snabbit.runner.shared.resources.snabbit_smiley_happy_stroke
import com.snabbit.runner.shared.resources.snabbit_smiley_okay_active
import com.snabbit.runner.shared.resources.snabbit_smiley_okay_stroke
import com.snabbit.runner.shared.resources.snabbit_smiley_very_dissatisfied_active
import com.snabbit.runner.shared.resources.snabbit_smiley_very_dissatisfied_stroke

/** Ratings run 1 (saddest) … 5 (happiest). */
private const val RATING_COUNT = 5
private const val SMILEY_SIZE_DP = 58

/**
 * **Rate the customer** — the five-smiley rating card (Figma "Shift — Job Lifecycle DS" node
 * 13:11611). Each smiley is outlined ([smileyStroke]) until picked, then flips to its solid
 * ([smileyActive]) variant. Migrated from the Flutter `RatingStars` (`rating_block_handler.dart`),
 * swapping stars for the smileys already in `composeResources`.
 *
 * Stateless — the caller owns the [CustomerRatingUiState] and handles taps via [onSelect] (the rating
 * POST + the reveal-block hook live in the caller's `CustomerRatingViewModel`). Previewable/testable
 * with a hand-built state.
 */
@Composable
fun CustomerRating(
    state: CustomerRatingUiState,
    strings: CustomerRatingStrings,
    onSelect: (rating: Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        // Figma: 20 between the title and the smiley row.
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SnabbitText(
            text = strings.title,
            // Body-L/18-Semibold, gray-700.
            fontSize = 18.sp,
            lineHeight = 24.sp,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textBody,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            for (rating in 1..RATING_COUNT) {
                val resource = if (state.selectedRating == rating) smileyActive(rating) else smileyStroke(rating)
                Image(
                    painter = painterResource(resource),
                    contentDescription = null,
                    modifier = Modifier
                        .size(SMILEY_SIZE_DP.dp)
                        // No ripple — a bare tap, matching the Flutter GestureDetector.
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) { onSelect(rating) },
                )
            }
        }
    }
}

/** The solid (selected) smiley for [rating] 1..5. */
private fun smileyActive(rating: Int): DrawableResource = when (rating) {
    1 -> Res.drawable.snabbit_smiley_very_dissatisfied_active
    2 -> Res.drawable.snabbit_smiley_dissatisfied_active
    3 -> Res.drawable.snabbit_smiley_okay_active
    4 -> Res.drawable.snabbit_smiley_happy_active
    else -> Res.drawable.snabbit_smiley_delighted_active
}

/** The outlined (unselected) smiley for [rating] 1..5. */
private fun smileyStroke(rating: Int): DrawableResource = when (rating) {
    1 -> Res.drawable.snabbit_smiley_very_dissatisfied_stroke
    2 -> Res.drawable.snabbit_smiley_dissatisfied_stroke
    3 -> Res.drawable.snabbit_smiley_okay_stroke
    4 -> Res.drawable.snabbit_smiley_happy_stroke
    else -> Res.drawable.snabbit_smiley_delighted_stroke
}

/* ── Preview ─────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewCustomerRating() {
    SnabbitTheme {
        Column(Modifier.background(SnabbitTheme.colors.bgPrimary).padding(16.dp)) {
            CustomerRating(
                state = CustomerRatingUiState(selectedRating = 1),
                strings = rememberCustomerRatingStrings(),
                onSelect = {},
            )
        }
    }
}
