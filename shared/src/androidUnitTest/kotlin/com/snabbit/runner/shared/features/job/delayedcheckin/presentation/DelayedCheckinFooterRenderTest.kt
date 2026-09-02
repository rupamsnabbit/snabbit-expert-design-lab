package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import com.snabbit.design.theme.SnabbitTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * ASSERTION-based render tests (not goldens) for [DelayedCheckinFooter]'s timer
 * clamp — the render-layer contract the ViewModel tests can't see:
 *
 * The footer receives the **signed** `remainingSeconds` straight from state
 * (`DelayedCheckinViewModelTest` pins that it goes negative on overrun), but the
 * rendered timer is `ReachBy(remainingSeconds.coerceAtLeast(0)).display()` — so an
 * overrun must show `"00:00"`, never a negative `"-01:23"`. That clamp lives in the
 * composable itself; these tests pin it through the compose semantics tree:
 *
 *  - `remainingSeconds = -83` → `"00:00"` (and no minus sign anywhere in the footer),
 *  - `remainingSeconds = 83`  → `"01:23"` (zero-padded mm:ss),
 *  - `remainingSeconds = 0`   → `"00:00"` (boundary),
 *
 * plus the always-on [DelayedCheckinStrings.runningLate] caption (the penalty flow
 * is by definition late — the caption never flips) and the pass-through CTA labels.
 *
 * Same Robolectric + createComposeRule harness as the screenshot tests
 * (`CheckInScreenScreenshotTest` / `HomeScreenScreenshotTest`), but assertions only —
 * runs on plain `testDebugUnitTest`, no Roborazzi record/verify step involved.
 * Determinism: the urgent CountdownWash fill is drawn by a `DrawModifierNode` whose
 * displayed value starts AT the requested progress, so a single `setContent` launches
 * no animation at all (the pixel-stepped walk only runs when progress *changes*), and
 * `LocalConnectivityStatus` defaults to Online, so no banner and nothing keeps the
 * rule busy.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp-420dpi")
class DelayedCheckinFooterRenderTest {

    @get:Rule
    val compose = createComposeRule()

    private val strings = DelayedCheckinStrings()

    private fun setFooter(remainingSeconds: Int, secondaryLabel: String) {
        compose.setContent {
            SnabbitTheme {
                DelayedCheckinFooter(
                    remainingSeconds = remainingSeconds,
                    totalSeconds = 300,
                    secondaryLabel = secondaryLabel,
                    strings = strings,
                    onCheckIn = {},
                    onSecondaryClick = {},
                )
            }
        }
    }

    /** Overrun: signed state is -83 (1 min 23 s late) but the timer holds at "00:00". */
    @Test
    fun overrun_negativeRemainingSeconds_rendersClampedZeroTimer() {
        setFooter(remainingSeconds = -83, secondaryLabel = strings.callPartnerSupport)

        compose.onNodeWithText("00:00").assertIsDisplayed()
        // The exact un-clamped rendering must not exist…
        compose.onAllNodesWithText("-01:23").assertCountEquals(0)
        // …and more generally no minus sign may appear anywhere in the footer.
        compose.onAllNodesWithText("-", substring = true).assertCountEquals(0)

        compose.onNodeWithText(strings.runningLate).assertIsDisplayed()
        // Host-driven overrun swap: the secondary CTA label passes straight through.
        compose.onNodeWithText(strings.callPartnerSupport).assertIsDisplayed()
    }

    /** Counting down: 83 s renders as zero-padded "01:23", caption still RUNNING LATE. */
    @Test
    fun countingDown_positiveRemainingSeconds_rendersZeroPaddedMmSs() {
        setFooter(remainingSeconds = 83, secondaryLabel = strings.help)

        compose.onNodeWithText("01:23").assertIsDisplayed()
        // The caption is ALWAYS runningLate — even before the deadline (unlike CheckInFooter).
        compose.onNodeWithText(strings.runningLate).assertIsDisplayed()
        compose.onNodeWithText(strings.checkIn).assertIsDisplayed()
        compose.onNodeWithText(strings.help).assertIsDisplayed()
    }

    /** Boundary: exactly at the deadline (0 s) the timer shows "00:00". */
    @Test
    fun atDeadline_zeroRemainingSeconds_rendersZeroTimer() {
        setFooter(remainingSeconds = 0, secondaryLabel = strings.help)

        compose.onNodeWithText("00:00").assertIsDisplayed()
        compose.onNodeWithText(strings.runningLate).assertIsDisplayed()
    }
}
