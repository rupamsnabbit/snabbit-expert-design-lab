package com.snabbit.runner.shared.features.job.presentation.checkin

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.PenaltyNudge
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinStrings
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.PenaltyNudgeBanner
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.RedCardCounterChip
import com.snabbit.runner.shared.features.job.domain.model.JobPayout
import com.snabbit.runner.shared.features.job.domain.model.PayoutBreakdownLine
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.rememberJobStrings
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * WHOLE-SCREEN golden tests for the check-in stage (`RUNNER_JOB_POST_ACCEPT` /
 * `RUNNER_JOB_CHECK_IN`). These render the entire screen host — [SnabbitScreen]
 * (background + insets + theme) wrapping [CheckInContent] — not the bare cards,
 * so the golden validates the B10 card-reorder decision in situ:
 *
 *  - `checkin_screen_accepted`  → penalty inactive, no penalty strip → PRICING
 *    card sits ABOVE the ADDRESS card (the existing post-accept order).
 *  - `checkin_screen_delayed`   → delayed-check-in penalty active, with the real
 *    penalty strip (`RedCardCounterChip` + `PenaltyNudgeBanner`) mounted as
 *    `topContent` → ADDRESS card sits ABOVE the PRICING card (get-there-first nudge).
 *
 * Determinism: [CheckInContent] renders no remote images (the earnings accordion
 * and navigation card use bundled/vector art only) and no clock — the only time
 * shown is the payout's fixed `checkInTimeIso`, parsed by the pure
 * `formatIsoClockTime` (→ "7:45 PM"). So no `FakeImageLoaderEngine` / frozen clock
 * is needed here. The penalty widgets load bundled Compose drawables (no network).
 *
 * Record / verify (plain `testDebugUnitTest` leaves these as no-ops):
 *   gradle :shared:recordRoborazziDebug
 *   gradle :shared:verifyRoborazziDebug
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-420dpi")
class CheckInScreenScreenshotTest {

    @get:Rule
    val compose = createComposeRule()

    // rememberJobStrings() ends with `.localized(getKoin().get())` — the base's l10n change made it
    // Koin-backed, but this screenshot test (authored earlier) never started Koin. Provide an EMPTY
    // LocalizationStore (every key falls back to the composeResources English → deterministic render).
    @Before
    fun startKoinForStrings() {
        stopKoin() // defensive: clear any context leaked by a prior test in this JVM
        startKoin { modules(module { single { LocalizationStore(FakeLogger(), CrashReporter { _, _ -> }) } }) }
    }

    @After
    fun stopKoinForStrings() = stopKoin()

    @Test
    fun checkInScreen_accepted() {
        compose.setContent {
            SnabbitScreen(containerColor = SnabbitTheme.colors.bgSecondary) { padding ->
                CheckInContent(
                    state = sampleState,
                    strings = rememberJobStrings(),
                    contentPadding = padding,
                    penaltyActive = false,
                    topContent = null,
                )
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/checkin_screen_accepted.png")
    }

    @Test
    fun checkInScreen_delayed() {
        compose.setContent {
            SnabbitScreen(containerColor = SnabbitTheme.colors.bgSecondary) { padding ->
                CheckInContent(
                    state = sampleState,
                    strings = rememberJobStrings(),
                    contentPadding = padding,
                    penaltyActive = true,
                    topContent = {
                        // The real delayed-check-in penalty strip: the "N Red Card(s)
                        // Received" counter pill + the deduction nudge banner. Grouped
                        // by CheckInContent's own "penalty" item (20.dp gap, centered).
                        RedCardCounterChip(
                            receivedRedCards = 1,
                            strings = DelayedCheckinStrings(),
                        )
                        PenaltyNudgeBanner(
                            nudge = PenaltyNudge(label = "1 red card will be added", redCards = 1),
                        )
                    },
                )
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/checkin_screen_delayed.png")
    }

    // ---- Delayed-check-in matrix (A/B/C/D). `checkin_screen_accepted` is A1
    // (no penalty, eligible) and `checkin_screen_delayed` is B2/C1 (penalty, 1
    // red card + nudge). The cases below fill the rest of the core set. ----

    /** A2 — no penalty, past check-in: PRICING-above-ADDRESS order, bonus struck/greyed. */
    @Test
    fun checkInScreen_pastCheckIn() {
        compose.setContent {
            SnabbitScreen(containerColor = SnabbitTheme.colors.bgSecondary) { padding ->
                CheckInContent(
                    state = pastCheckInState,
                    strings = rememberJobStrings(),
                    contentPadding = padding,
                    penaltyActive = false,
                    topContent = null,
                )
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/checkin_screen_past_checkin.png")
    }

    /** B1 — penalty, 0 red cards received, NO nudge (the "0 Red Cards Received" chip still renders). */
    @Test
    fun checkInScreen_penalty0NoNudge() {
        compose.setContent {
            SnabbitScreen(containerColor = SnabbitTheme.colors.bgSecondary) { padding ->
                CheckInContent(
                    state = sampleState,
                    strings = rememberJobStrings(),
                    contentPadding = padding,
                    penaltyActive = true,
                    topContent = {
                        RedCardCounterChip(receivedRedCards = 0, strings = DelayedCheckinStrings())
                    },
                )
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/checkin_screen_penalty_0.png")
    }

    /** B3/C2 — penalty, 2 red cards received + "2 red cards will be added" nudge (plural). */
    @Test
    fun checkInScreen_penalty2WithNudge() {
        compose.setContent {
            SnabbitScreen(containerColor = SnabbitTheme.colors.bgSecondary) { padding ->
                CheckInContent(
                    state = sampleState,
                    strings = rememberJobStrings(),
                    contentPadding = padding,
                    penaltyActive = true,
                    topContent = {
                        RedCardCounterChip(receivedRedCards = 2, strings = DelayedCheckinStrings())
                        PenaltyNudgeBanner(
                            nudge = PenaltyNudge(label = "2 red cards will be added", redCards = 2),
                        )
                    },
                )
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/checkin_screen_penalty_2.png")
    }

    /** B4 — penalty, 3 red cards received + "3 red cards will be added" nudge. */
    @Test
    fun checkInScreen_penalty3WithNudge() {
        compose.setContent {
            SnabbitScreen(containerColor = SnabbitTheme.colors.bgSecondary) { padding ->
                CheckInContent(
                    state = sampleState,
                    strings = rememberJobStrings(),
                    contentPadding = padding,
                    penaltyActive = true,
                    topContent = {
                        RedCardCounterChip(receivedRedCards = 3, strings = DelayedCheckinStrings())
                        PenaltyNudgeBanner(
                            nudge = PenaltyNudge(label = "3 red cards will be added", redCards = 3),
                        )
                    },
                )
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/checkin_screen_penalty_3.png")
    }

    /** C3 — penalty active with a received-red-card chip but NO nudge banner (chip only). */
    @Test
    fun checkInScreen_penaltyNoNudge() {
        compose.setContent {
            SnabbitScreen(containerColor = SnabbitTheme.colors.bgSecondary) { padding ->
                CheckInContent(
                    state = sampleState,
                    strings = rememberJobStrings(),
                    contentPadding = padding,
                    penaltyActive = true,
                    topContent = {
                        RedCardCounterChip(receivedRedCards = 1, strings = DelayedCheckinStrings())
                    },
                )
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/checkin_screen_penalty_no_nudge.png")
    }

    /** D1 — penalty active AND past check-in: address-on-top + penalty strip + bonus-lost earnings. */
    @Test
    fun checkInScreen_penaltyPastCheckIn() {
        compose.setContent {
            SnabbitScreen(containerColor = SnabbitTheme.colors.bgSecondary) { padding ->
                CheckInContent(
                    state = pastCheckInState,
                    strings = rememberJobStrings(),
                    contentPadding = padding,
                    penaltyActive = true,
                    topContent = {
                        RedCardCounterChip(receivedRedCards = 1, strings = DelayedCheckinStrings())
                        PenaltyNudgeBanner(
                            nudge = PenaltyNudge(label = "1 red card will be added", redCards = 1),
                        )
                    },
                )
            }
        }
        compose.onRoot().captureRoboImage(filePath = "$SNAPSHOTS/checkin_screen_penalty_past_checkin.png")
    }

    private companion object {
        const val SNAPSHOTS = "src/androidUnitTest/snapshots"

        /** Mirrors the private `sampleCheckInPayout` at the bottom of `CheckInContent.kt`. */
        val samplePayout = JobPayout(
            totalEarning = 150,
            lines = listOf(
                PayoutBreakdownLine(labelKey = "work", labelDefault = "Work (1 hour)", pillText = null, iconUrl = null, subtitle = null, amount = 120),
                PayoutBreakdownLine(labelKey = "summer", labelDefault = "Summer Bonus ☀️ (1 hour)", pillText = null, iconUrl = null, subtitle = null, amount = 20),
                PayoutBreakdownLine(labelKey = "ot", labelDefault = "OT (15 min)", pillText = null, iconUrl = null, subtitle = null, amount = 40),
            ),
            checkInAmount = 5,
            checkInTimeIso = "2026-06-27T19:45:00+05:30",
        )

        /** Mirrors the private `sampleCheckInState` — eligible (not past check-in). */
        val sampleState = JobUiState.AwaitingCheckIn(
            jobId = 739,
            customerName = "Radhika S",
            address = "HAL Old Airport rd, near railway over bridge, LN Pura, Marathahalli, Bengaluru",
            payout = samplePayout,
            checkInRemainingSeconds = 83,
            checkInTotalSeconds = 300,
        )

        /** Past the check-in bonus deadline (A2 / D1): bonus struck/greyed, urgent footer. */
        val pastCheckInState = sampleState.copy(
            isPastCheckIn = true,
            checkInRemainingSeconds = -120,
        )
    }
}
