package com.snabbit.runner.shared.features.job.presentation.completed

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.domain.model.JobPayout
import com.snabbit.runner.shared.features.job.domain.model.PayoutBreakdownLine
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRating
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingStrings
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingUiState
import com.snabbit.runner.shared.features.job.presentation.completed.rating.rememberCustomerRatingStrings
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.rememberJobStrings
import com.snabbit.runner.shared.features.job.presentation.formatRupees
import com.snabbit.runner.shared.ui.components.SnabbitEarningsAccordion
import com.snabbit.runner.shared.ui.components.SnabbitJobState
import com.snabbit.runner.shared.ui.components.SnabbitJobStateStatus
import com.snabbit.runner.shared.features.job.presentation.newjob.earningsItems

/**
 * `RUNNER_POST_CHECKOUT` body — the job-completion screen (Figma "Shift — Job Lifecycle DS" nodes
 * 11:18791 / 12:9750). Composes existing app/DS components only:
 *
 *  - [SnabbitJobState] "Job Completed" header (green check),
 *  - [SnabbitEarningsAccordion] "You Earned" card (total + breakdown), built from [JobUiState.Completed.payout]
 *    via [earningsItems] (the same mapping the check-in screen uses),
 *  - [CustomerRating] five-smiley card (stateless over [ratingState]; taps go to [onSelectRating]),
 *  - a [BlockCustomerCard] that appears once the runner rates **1★** (the saddest smiley) — its Block
 *    opens the confirmation sheet ([onBlock]); after a block it shows [isBlocked] with an Unblock ([onUnblock]).
 *
 * The "Ready for next job" CTA lives in the screen's bottom bar (enabled once any rating is given).
 * Stateless — the caller owns the rate-customer state (from the reused `CustomerRatingViewModel`) and
 * the block outcome ([isBlocked]).
 */
@Composable
internal fun CompletedContent(
    state: JobUiState.Completed,
    ratingState: CustomerRatingUiState,
    ratingStrings: CustomerRatingStrings,
    strings: JobStrings,
    isBlocked: Boolean,
    isUnblocking: Boolean = false,
    contentPadding: PaddingValues,
    onSelectRating: (rating: Int) -> Unit,
    onBlock: () -> Unit,
    onUnblock: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(contentPadding)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        SnabbitJobState(label = strings.jobCompletedTitle, status = SnabbitJobStateStatus.Completed)

        // "You Earned" — non-collapsible; the check-in bonus row highlights green (via earningsItems).
        // The backend often hasn't computed the payout at checkout time, so the envelope sends
        // `payout_info` null; show a "Calculating your earnings" placeholder instead of a blank gap (a
        // later current_state poll fills payout_info in and the accordion replaces it). Mirrors the legacy
        // rate_customer.dart placeholder. NOTE: legacy gated this on `isRateCardV2Effective`, a
        // user-profile flag not in the KMP envelope — this shows for all runners until that flag is plumbed.
        val payout = state.payout
        if (payout != null) {
            SnabbitEarningsAccordion(
                title = strings.youEarned,
                amount = formatRupees(payout.totalEarning ?: 0),
                items = earningsItems(payout, strings),
                // Completed = the "earned" state: total amount in green-600 (textSuccess) and the earned
                // check-in bonus row banded green-50 (bgSuccess), vs the check-in screen's pending blue band.
                amountColor = SnabbitTheme.colors.textSuccess,
                highlightColor = SnabbitTheme.colors.bgSuccess,
            )
        } else {
            CalculatingEarningsCard(strings = strings)
        }

        CustomerRating(state = ratingState, strings = ratingStrings, onSelect = onSelectRating)

        // Rated the saddest or second saddest smiley (1★ or 2★) → offer to block the customer (Figma 12:9750).
        ratingState.selectedRating?.let { selectedRating ->
            if (selectedRating <= 2) {
                BlockCustomerCard(
                    customerName = state.customerName?.takeIf { it.isNotBlank() } ?: strings.customerFallback,
                    onBlock = onBlock,
                    isBlocked = isBlocked,
                    onUnblock = onUnblock,
                    unblocking = isUnblocking,
                )
            }
        }
    }
}

/**
 * Placeholder shown on the Completed stage while the backend is still computing the payout (envelope
 * `payout_info` == null at checkout). Replaced by the real [SnabbitEarningsAccordion] once a later
 * `current_state` poll returns a populated payout. Mirrors the legacy `_CalculatingEarningsCard`.
 */
@Composable
private fun CalculatingEarningsCard(strings: JobStrings) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(SnabbitTheme.colors.bgPrimary)
            .border(1.5.dp, SnabbitTheme.colors.borderSubtle, shape)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // A spinner stands in for the legacy static "earnings calculating" illustration (no KMP asset
        // needed) — it reads as "being computed", matching the interim state.
        CircularProgressIndicator(
            modifier = Modifier.size(24.dp),
            color = SnabbitTheme.colors.iconBrand,
            strokeWidth = 2.dp,
        )
        SnabbitText(
            text = strings.calculatingEarningsTitle,
            color = SnabbitTheme.colors.textPrimary,
            fontSize = 18.sp,
            lineHeight = 24.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        SnabbitText(
            text = strings.calculatingEarningsSubtitle,
            color = SnabbitTheme.colors.textSecondary,
            fontSize = 14.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.Normal,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/* ── Previews ────────────────────────────────────────────────────────── */

private val samplePayout = JobPayout(
    totalEarning = 150,
    lines = listOf(
        PayoutBreakdownLine(labelKey = "work", labelDefault = "Work (1 hour)", pillText = null, iconUrl = null, subtitle = null, amount = 120),
        PayoutBreakdownLine(labelKey = "summer", labelDefault = "Summer Bonus ☀️ (1 hour)", pillText = null, iconUrl = null, subtitle = null, amount = 20),
        PayoutBreakdownLine(labelKey = "ot", labelDefault = "OT (15 min)", pillText = null, iconUrl = null, subtitle = null, amount = 40),
    ),
    checkInAmount = 5,
    checkInTimeIso = "2026-06-27T19:45:00+05:30",
)

private val sampleCompleted = JobUiState.Completed(
    jobId = 739,
    customerId = 42,
    customerName = "Radhika S",
    customerAddress = "HAL Old Airport Rd, Marathahalli, Bengaluru",
    payout = samplePayout,
)

@Composable
private fun previewCompleted(ratingState: CustomerRatingUiState, isBlocked: Boolean) {
    SnabbitTheme {
        CompletedContent(
            state = sampleCompleted,
            ratingState = ratingState,
            ratingStrings = rememberCustomerRatingStrings(),
            strings = rememberJobStrings(),
            isBlocked = isBlocked,
            contentPadding = PaddingValues(0.dp),
            onSelectRating = {},
            onBlock = {},
            onUnblock = {},
        )
    }
}

@Preview
@Composable
private fun PreviewCompletedUnrated() = previewCompleted(CustomerRatingUiState(), isBlocked = false)

@Preview
@Composable
private fun PreviewCompletedRatedOneStar() =
    previewCompleted(CustomerRatingUiState(selectedRating = 1), isBlocked = false)

@Preview
@Composable
private fun PreviewCompletedBlocked() =
    previewCompleted(CustomerRatingUiState(selectedRating = 1), isBlocked = true)

@Preview
@Composable
private fun PreviewCompletedCalculatingEarnings() {
    SnabbitTheme {
        CompletedContent(
            state = sampleCompleted.copy(payout = null),
            ratingState = CustomerRatingUiState(),
            ratingStrings = rememberCustomerRatingStrings(),
            strings = rememberJobStrings(),
            isBlocked = false,
            contentPadding = PaddingValues(0.dp),
            onSelectRating = {},
            onBlock = {},
            onUnblock = {},
        )
    }
}
