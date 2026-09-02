package com.snabbit.runner.shared.features.job.presentation.checkin

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.presentation.contact.CustomerContactHandler
import com.snabbit.runner.shared.features.job.presentation.contact.NoOpCustomerContactHandler
import com.snabbit.runner.shared.features.job.presentation.contact.NoOpTtsController
import com.snabbit.runner.shared.features.job.presentation.contact.TtsController
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.domain.model.JobPayout
import com.snabbit.runner.shared.features.job.domain.model.PayoutBreakdownLine
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.rememberJobStrings
import com.snabbit.runner.shared.features.job.presentation.formatIsoClockTime
import com.snabbit.runner.shared.features.job.presentation.formatRupees
import com.snabbit.runner.shared.ui.components.EarningsCollapsedSummary
import com.snabbit.runner.shared.ui.components.SnabbitEarningsAccordion
import com.snabbit.runner.shared.ui.components.SnabbitJobState
import com.snabbit.runner.shared.ui.components.SnabbitJobStateStatus
import com.snabbit.runner.shared.ui.icons.AppIcons
import com.snabbit.runner.shared.ui.components.SnabbitNavigationAction
import com.snabbit.runner.shared.ui.components.SnabbitNavigationActions
import com.snabbit.runner.shared.ui.components.SnabbitNavigationCard
import com.snabbit.runner.shared.features.job.presentation.newjob.earningsItems

/**
 * `RUNNER_JOB_POST_ACCEPT` / `RUNNER_JOB_CHECK_IN` body — the check-in screen the runner
 * sees after reaching the job location. Composes existing app/DS components only, matching
 * Figma "Shift — Job Lifecycle DS" (node 1:28113 eligible / 2:6823 no-longer-eligible):
 *
 *  - [SnabbitJobState] "Check In" header,
 *  - [SnabbitEarningsAccordion] payout card (collapsible; the check-in bonus row is the
 *    highlighted blue band while eligible, and greyed / struck-total once the deadline
 *    passes — driven by [JobUiState.AwaitingCheckIn.isPastCheckIn]),
 *  - [SnabbitNavigationCard] with the customer, address and Map / Call / Chat quick-actions.
 *
 * The "Check In" CTA + bonus countdown live in the screen's bottom bar ([CheckInFooter]).
 */
/**
 * The two cards below the header/penalty strip that swap order per state (B10). Named so
 * the ordering decision is a pure, unit-testable value ([checkInCardOrder]) rather than
 * layout logic buried in the composable.
 */
internal enum class CheckInCard { Pricing, Address }

/**
 * Card order for the check-in body (B10):
 *  - plain Accepted / post-accept check-in → PRICING above ADDRESS (existing behaviour),
 *  - delayed check-in (penalty active)      → ADDRESS above PRICING (get-there-first nudge).
 *
 * The cards keep stable LazyColumn keys, so flipping this list animates a real position
 * swap via `Modifier.animateItem()` rather than a re-composition jump.
 */
internal fun checkInCardOrder(penaltyActive: Boolean): List<CheckInCard> =
    if (penaltyActive) {
        listOf(CheckInCard.Address, CheckInCard.Pricing)
    } else {
        listOf(CheckInCard.Pricing, CheckInCard.Address)
    }

@Composable
fun CheckInContent(
    state: JobUiState.AwaitingCheckIn,
    strings: JobStrings,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier,
    contact: CustomerContactHandler = NoOpCustomerContactHandler,
    tts: TtsController = NoOpTtsController,
    // Job-lifecycle instrumentation (nullable so previews / un-hosted renders stay DI-free).
    analytics: JobAnalytics? = null,
    // B10: when the delayed check-in penalty is active the ADDRESS card sits ABOVE the
    // PRICING card (get-there-first nudge); otherwise PRICING stays on top. Threaded from
    // JobScreen as `dcState?.penalty != null`.
    penaltyActive: Boolean = false,
    // Optional strip UNDER the "Check In" header — the delayed check-in penalty section
    // mounts its red-card counter pill + deduction nudge banner here (scrolls with the
    // body; Figma places the penalty strip between the header and the customer card).
    topContent: (@Composable () -> Unit)? = null,
    // Tiering job nudge ("Do early Check in for perfect job") — placed directly below the
    // navigation card as its own item (20dp margins via the list's spacedBy). Null → omitted.
    jobTieringNudge: (@Composable () -> Unit)? = null,
) {
    // "Listen" replay counter for audio_played (1 = first play on this screen, 2+ = replays).
    var audioPlayCount by remember { mutableStateOf(0) }
    // Stop any read-aloud in progress when the runner leaves the check-in stage.
    DisposableEffect(Unit) { onDispose { tts.stop() } }
    // LazyColumn (not a plain scrolling Column) so the two reorderable cards are keyed
    // items and `Modifier.animateItem()` animates the B10 position swap. Legal here
    // because SnabbitScreen adds NO scroll of its own — this is the stage's sole vertical
    // scroller, so there is no nested-scroll conflict.
    val layoutDirection = LocalLayoutDirection.current
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        // Fold the scaffold insets AND the screen's 16.dp gutter into contentPadding so the
        // body scrolls under the transparent floating header exactly as the old Column did.
        contentPadding = PaddingValues(
            start = contentPadding.calculateStartPadding(layoutDirection) + 16.dp,
            top = contentPadding.calculateTopPadding() + 16.dp,
            end = contentPadding.calculateEndPadding(layoutDirection) + 16.dp,
            bottom = contentPadding.calculateBottomPadding() + 16.dp,
        ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        item(key = "header") {
            SnabbitJobState(
                label = strings.checkIn,
                status = SnabbitJobStateStatus.CheckIn,
                modifier = Modifier.animateItem(),
            )
        }
        topContent?.let { top ->
            item(key = "penalty") {
                // Group the penalty strip's chip + banner in one item, keeping their 20.dp
                // internal gap (they had no ColumnScope before either — plain lambda call).
                Column(
                    modifier = Modifier.fillMaxWidth().animateItem(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) { top() }
            }
        }
        checkInCardOrder(penaltyActive).forEach { card ->
            when (card) {
                CheckInCard.Pricing -> state.payout?.let { payout ->
                    item(key = "card-pricing") {
                        CheckInEarnings(
                            payout = payout,
                            isPastCheckIn = state.isPastCheckIn,
                            strings = strings,
                            // Preserve the check-in "expand_earnings" instrumentation across the B10 refactor.
                            analytics = analytics,
                            modifier = Modifier.animateItem(),
                        )
                    }
                }
                CheckInCard.Address -> {
                    item(key = "card-address") {
                    // Full address = address + geo_address (secondary line), mirroring the Flutter
                    // AddressDetails; blank parts are dropped so a missing line leaves no stray gap and a
                    // fully-blank address shows nothing (ECPO-860 #7 — the KMP card previously dropped
                    // geo_address, so the address read as "trimmed").
                    val fullAddress = listOfNotNull(
                        state.address?.takeIf { it.isNotBlank() },
                        state.geoAddress?.takeIf { it.isNotBlank() },
                    ).joinToString("\n")
                    SnabbitNavigationCard(
                        customerName = state.customerName?.takeIf { it.isNotBlank() } ?: strings.customerFallback,
                        address = fullAddress,
                        modifier = Modifier.animateItem(),
                        listenLabel = strings.listen,
                        // Read the address aloud via the host TTS bridge (no-op when un-hosted / on previews).
                        onListen = {
                            audioPlayCount += 1
                            analytics?.audioPlayed(screenName = JobAnalytics.SCREEN_CHECK_IN, playCountOnScreen = audioPlayCount)
                            tts.speak(fullAddress)
                        },
                        actions = SnabbitNavigationActions(
                            listOf(
                                // Map = the navigation arrow → Google Maps walking directions to the customer.
                                SnabbitNavigationAction(
                                    AppIcons.Map,
                                    strings.mapAction,
                                    onClick = {
                                        analytics?.checkInScreenCtaClick("map")
                                        contact.openMaps(state.latitude, state.longitude)
                                    },
                                ),
                                // Call = masked call (with a dialer fallback). Chat is disabled (feature off).
                                SnabbitNavigationAction(
                                    AppIcons.Call,
                                    strings.callAction,
                                    onClick = {
                                        analytics?.checkInScreenCtaClick("call")
                                        contact.call(state.customerPhone)
                                    },
                                ),
                            ),
                        ),
                    )
                    }
                    // "Do early Check in for perfect job" — directly below the nav card (20dp
                    // margins from the list's spacedBy); omitted when there's no eligible nudge.
                    jobTieringNudge?.let { nudge ->
                        item(key = "tiering-nudge") { nudge() }
                    }
                }
            }
        }
    }
}

/**
 * The earnings card, in its eligible or bonus-lost shape. It **starts collapsed** in both shapes;
 * the runner taps the tile to expand the breakdown. Eligible: full total, check-in row highlighted,
 * and a collapsed summary (`base + bonus` + a "Check In by" pill). Lost (deadline passed): the total
 * drops by the bonus, the with-bonus original is struck, and the check-in row is greyed.
 *
 * Assumes `total_earning` is the with-bonus total, so the base = total − bonus (the design
 * math: ₹150 = ₹145 + ₹5). Adjust here if the backend sends the base instead.
 */
@Composable
private fun CheckInEarnings(
    payout: JobPayout,
    isPastCheckIn: Boolean,
    strings: JobStrings,
    analytics: JobAnalytics? = null,
    modifier: Modifier = Modifier,
) {
    val total = payout.totalEarning ?: 0
    val bonus = payout.checkInAmount ?: 0
    val hasBonus = bonus > 0
    val lost = isPastCheckIn && hasBonus

    SnabbitEarningsAccordion(
        modifier = modifier,
        title = strings.youWillEarn,
        amount = formatRupees(if (lost) total - bonus else total),
        originalAmount = if (lost) formatRupees(total) else null,
        items = earningsItems(payout, strings, checkInLost = lost),
        collapsible = true,
        // Always starts collapsed — the runner taps the tile to reveal the breakdown. Eligible
        // shows the base+bonus summary + check-in pill in the collapsed header; lost shows the
        // discounted total.
        initialExpanded = false,
        // A user-initiated expand → the check-in "expand_earnings" CTA.
        onExpandedChange = { expanded -> if (expanded) analytics?.checkInScreenCtaClick("expand_earnings") },
        collapsedSummary = if (hasBonus && !lost) {
            EarningsCollapsedSummary(
                baseAmount = formatRupees(total - bonus),
                bonusAmount = formatRupees(bonus),
                pillText = strings.checkInByPill.replace("{time}", formatIsoClockTime(payout.checkInTimeIso).orEmpty()),
            )
        } else {
            null
        },
    )
}

/* ── Previews ────────────────────────────────────────────────────────── */

private val sampleCheckInPayout = JobPayout(
    totalEarning = 150,
    lines = listOf(
        PayoutBreakdownLine(labelKey = "work", labelDefault = "Work (1 hour)", pillText = null, iconUrl = null, subtitle = null, amount = 120),
        PayoutBreakdownLine(labelKey = "summer", labelDefault = "Summer Bonus ☀️ (1 hour)", pillText = null, iconUrl = null, subtitle = null, amount = 20),
        PayoutBreakdownLine(labelKey = "ot", labelDefault = "OT (15 min)", pillText = null, iconUrl = null, subtitle = null, amount = 40),
    ),
    checkInAmount = 5,
    checkInTimeIso = "2026-06-27T19:45:00+05:30",
)

private val sampleCheckInState = JobUiState.AwaitingCheckIn(
    jobId = 739,
    customerName = "Radhika S",
    address = "HAL Old Airport rd, near railway over bridge, LN Pura, Marathahalli, Bengaluru",
    payout = sampleCheckInPayout,
    checkInRemainingSeconds = 83,
    checkInTotalSeconds = 300,
)

@Preview
@Composable
private fun PreviewCheckInContentEligible() {
    SnabbitTheme {
        CheckInContent(
            state = sampleCheckInState,
            strings = rememberJobStrings(),
            contentPadding = PaddingValues(0.dp),
        )
    }
}

@Preview
@Composable
private fun PreviewCheckInContentBonusLost() {
    SnabbitTheme {
        CheckInContent(
            state = sampleCheckInState.copy(isPastCheckIn = true),
            strings = rememberJobStrings(),
            contentPadding = PaddingValues(0.dp),
        )
    }
}
