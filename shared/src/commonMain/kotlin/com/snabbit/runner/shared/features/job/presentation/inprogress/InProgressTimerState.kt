package com.snabbit.runner.shared.features.job.presentation.inprogress

import androidx.compose.ui.graphics.vector.ImageVector
import com.snabbit.design.atoms.SnabbitTooltipArrowPosition

/** The timer colour tier — drives the pill variant, the background glow, and the CTA-enabled state. */
enum class InProgressColor { Green, Yellow, Red }

/**
 * The locally-ticked, derived view of the in-progress timer — everything the screen renders from the
 * running countdown. Produced by [rememberInProgressTimer]; shared by [InProgressContent] and
 * [CompleteJobFooter] so they never drift.
 */
data class InProgressTimerState(
    val color: InProgressColor,
    /** The pill's countdown text, e.g. "48:23" (or "-01:23" past end-time). */
    val timeText: String,
    /** The pill label — "TIME LEFT" normally, "AUTO CHECKOUT IN" during the auto-checkout window. */
    val pillLabel: String,
    /** Fraction of the window remaining (1 = full), driving the pill ring fill. */
    val progress: Float,
    /** Whether "Complete Job" is tappable (from the yellow window onward, per Flutter). */
    val completeEnabled: Boolean,
    /** Live seconds remaining to end-time (negative once past); gates the early-finish campaign sheet. */
    val remainingSeconds: Int,
    /** Status-callout copy beneath the pill, or null for none. */
    val calloutText: String?,
    /** true → red (Error) callout; false → green (Success) callout. */
    val calloutIsError: Boolean,
    /** Callout caret — [SnabbitTooltipArrowPosition.TopCenter] so every callout points up at the pill. */
    val calloutArrow: SnabbitTooltipArrowPosition = SnabbitTooltipArrowPosition.TopCenter,
    /** Custom callout icon (the job-extended clock+plus); null → the tooltip variant's default icon. */
    val calloutIcon: ImageVector? = null,
)
