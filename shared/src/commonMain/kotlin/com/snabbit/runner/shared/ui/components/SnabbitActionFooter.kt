package com.snabbit.runner.shared.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.invalidateDraw
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitButtonLoadingPosition
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.connectivity.ConnectivityStatus
import com.snabbit.runner.shared.core.connectivity.LocalConnectivityStatus
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * The two "Red state" (urgent) presentations of [SnabbitActionFooter]. Distinct visuals,
 * not two implementations of one — pick per context.
 */
enum class SnabbitActionFooterUrgentStyle {
    /**
     * A directionless red **throb**: the whole footer pulses soft ⇄ strong red
     * (red50 ⇄ red300) on a ~600ms reverse cycle. An "act now" signal with no countdown
     * geometry — the new-job accept countdown's final third. Ignores `urgentFillProgress`.
     */
    Blink,

    /**
     * A red **countdown-progress wash**: a red300 → transparent fill anchored at the RIGHT
     * edge grows leftward as `urgentFillProgress` elapses, over a static red200 → white
     * background. The Figma "running late" treatment — the check-in / delayed-check-in flows.
     */
    CountdownWash,
}

/**
 * SnabbitActionFooter — sticky bottom action footer (Expert App component).
 *
 * App-specific composition. Figma: "Bottom check-in / Acceptance screen" set
 * (Property 1 = Default / Red state / Variant3). Composes DS building blocks:
 * a [SnabbitMetricCard] (caption + timer) over a DS [SnabbitButton],
 * with an optional secondary ("Deny") button — a DS [SnabbitButton] in the
 * NeutralStroke (outline) style.
 *
 * - [buttonType] picks the primary button color (Brand pink / Success green).
 * - [urgent] turns on the "Red state"; [urgentStyle] picks which one — a red
 *   [SnabbitActionFooterUrgentStyle.Blink] throb (the new-job accept countdown) or a
 *   [SnabbitActionFooterUrgentStyle.CountdownWash] fill of width [urgentFillProgress],
 *   anchored at the RIGHT edge growing leftward over a red200 → white background, per the
 *   Figma "running late" frames (the check-in flows). Either way the timer renders in
 *   `text.error` (e.g. a negative "-01:23") with a near-black caption.
 * - [progress] (0..1) drives the button's trailing fill (from a countdown).
 * - [secondaryLabel] (the "Variant3") renders the Deny outline button.
 *
 * Window insets belong in the app shell (see `SnabbitScreen`), not here.
 *
 * NOTE: the wash reads the DS `red300`/`red50` *palette* (`SnabbitColorsLight`)
 * directly — the semantic `SnabbitColors` interface has no red-300; a semantic
 * "urgent/error-strong bg" token in the DS would let this drop the palette ref.
 */
@Composable
fun SnabbitActionFooter(
    caption: String,
    time: String,
    primaryLabel: String,
    onPrimaryClick: () -> Unit,
    modifier: Modifier = Modifier,
    buttonType: SnabbitButtonStyle = SnabbitButtonStyle.Primary,
    urgent: Boolean = false,
    /** Which "Red state" to show while [urgent]; see [SnabbitActionFooterUrgentStyle]. */
    urgentStyle: SnabbitActionFooterUrgentStyle = SnabbitActionFooterUrgentStyle.CountdownWash,
    progress: Float = 0f,
    /**
     * Elapsed fraction (0..1) of the countdown window driving the urgent wash's fill
     * width. Defaults to a full-width wash for urgent states without a window (e.g.
     * already past the deadline).
     */
    urgentFillProgress: Float = 1f,
    secondaryLabel: String? = null,
    onSecondaryClick: (() -> Unit)? = null,
    /**
     * Optional content (label/spinner) color for the secondary button. Null keeps the
     * NeutralStroke default (dark slate). The new-job Deny/Logout passes `red600` here
     * (the Figma tints it red); help / call-support secondaries leave it null.
     */
    secondaryContentColor: androidx.compose.ui.graphics.Color? = null,
    /**
     * When false (e.g. a submit is in flight), primary + secondary taps are ignored —
     * blocks a double-submit.
     */
    enabled: Boolean = true,
    /**
     * When true, the PRIMARY button shows its "Loading" spinner state and ignores taps
     * (an in-flight primary action). The secondary button is gated by [enabled] / [secondaryLoading].
     */
    loading: Boolean = false,
    /**
     * When true, the SECONDARY button shows its "Loading" spinner and ignores taps — so a two-button
     * footer (e.g. Accept + Deny) can spin the button that was actually pressed while [enabled] = false
     * disables the other. Defaults false (single-action footers never spin the secondary).
     */
    secondaryLoading: Boolean = false,
    /**
     * Device connectivity, defaulting to the ambient [LocalConnectivityStatus]. When not
     * [ConnectivityStatus.Online], a [SnabbitConnectivityBanner] is stacked flush on top of the
     * footer. Overridable for previews / tests; real hosts provide the CompositionLocal.
     */
    connectivityStatus: ConnectivityStatus = LocalConnectivityStatus.current,
) {
    val borderColor = SnabbitTheme.colors.borderSubtle
    val backgroundModifier = when {
        !urgent -> Modifier.background(SnabbitTheme.colors.bgPrimary)

        urgentStyle == SnabbitActionFooterUrgentStyle.Blink -> {
            // "Red state" BLINK — pulse the wash top between a soft (red50) and strong (red300) red
            // so the footer visibly throbs (the new-job accept countdown's final third). A
            // directionless "act now" signal — no countdown fill, so `urgentFillProgress` is unused.
            // Driven in the draw phase by [urgentWash] (a DrawModifierNode, mirroring earningsShimmer):
            // the pulse self-animates on the node and is read in draw(), so there's no per-frame
            // recomposition or Brush allocation. The node only exists while this branch is composed,
            // so the animation stops when it detaches.
            Modifier.urgentWash(from = SnabbitColorsLight.red50, to = SnabbitColorsLight.red300)
        }

        else -> {
            // "Red state" COUNTDOWN WASH — the fill's WIDTH is the elapsed fraction of the countdown
            // window ([urgentFillProgress]: 0 → full over the whole window, no repeating animation).
            // Figma spec: a red300 (#FCA5A5) → transparent top-down gradient fill anchored at the
            // RIGHT edge growing leftward, over a red200 (#FECACA) → white top-down gradient
            // background (which shows through the fill's faded bottom).
            // Driven in the draw phase by [countdownWash] (a DrawModifierNode) — see its KDoc for
            // why the smoothing steps by pixel rather than by frame.
            Modifier.countdownWash(
                progress = urgentFillProgress,
                background = SnabbitColorsLight.red200,
                fill = SnabbitColorsLight.red300,
            )
        }
    }

    // The connectivity strip stacks flush on top of the footer body, so ANY SnabbitActionFooter
    // is network-aware via LocalConnectivityStatus — no caller change. Online → the banner renders
    // nothing, leaving the footer identical to before.
    val showBanner = connectivityStatus != ConnectivityStatus.Online
    Column(modifier = modifier.fillMaxWidth()) {
        SnabbitConnectivityBanner(status = connectivityStatus)

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .then(backgroundModifier)
                // Top divider separates the footer from the scrollable content above it — but when the
                // connectivity banner sits flush on top, that 1.5dp line reads as a hairline gap between
                // the banner and the footer, so drop it then (the banner is the top edge). ECPO issue #4.
                .then(
                    if (showBanner) {
                        Modifier
                    } else {
                        Modifier.drawBehind {
                            val stroke = 1.5.dp.toPx()
                            drawLine(
                                color = borderColor,
                                start = Offset(0f, stroke / 2f),
                                end = Offset(size.width, stroke / 2f),
                                strokeWidth = stroke,
                            )
                        }
                    },
                )
                .padding(horizontal = 16.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            SnabbitMetricCard(
                caption = caption,
                value = time,
                size = SnabbitMetricCardSize.Md,
                // Urgent caption is near-black per Figma ("RUNNING LATE" in #111827 =
                // text.primary); only the timer numerals go red.
                captionColor = if (urgent) SnabbitTheme.colors.textPrimary else androidx.compose.ui.graphics.Color.Unspecified,
                valueColor = if (urgent) SnabbitTheme.colors.textError else SnabbitTheme.colors.textSuccess,
            )

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                SnabbitButton(
                    text = primaryLabel,
                    onClick = onPrimaryClick,
                    style = buttonType,
                    progress = progress,
                    enabled = enabled,
                    loading = loading,
                    loadingPosition = SnabbitButtonLoadingPosition.Leading,
                    fullWidth = true,
                    size = SnabbitButtonSize.L,
                )
                if (secondaryLabel != null) {
                    // Deny = DS outline button (NeutralStroke). Its label color is [secondaryContentColor]
                    // when provided (the new-job Deny/Logout passes red600 per Figma), else the stock dark
                    // slate default. Overriding contentColor is the sanctioned way to tint a NeutralStroke
                    // label (same as JobDenyFlowSheet); there is no "outline + red text" DS variant.
                    SnabbitButton(
                        text = secondaryLabel,
                        onClick = onSecondaryClick ?: {},
                        style = SnabbitButtonStyle.NeutralStroke,
                        size = SnabbitButtonSize.L,
                        enabled = enabled,
                        loading = secondaryLoading,
                        fullWidth = true,
                        contentColor = secondaryContentColor,
                    )
                }
            }
        }
    }
}

/** One full pulse (soft→strong red) of the urgent wash, in ms — matches the old blink cadence. */
private const val URGENT_BLINK_MILLIS = 600

/**
 * The urgent "running late" wash — a vertical red gradient whose top colour pulses [from] ⇄ [to]
 * (red50 ⇄ red300) over a white bottom while the footer is urgent. Backed by a [DrawModifierNode]
 * (mirroring `earningsShimmer` in SnabbitEarningsAccordion): the pulse is self-driven by an
 * [Animatable] on the node's own coroutine scope and read in `draw()`, so each step invalidates only
 * the draw phase — the composable never recomposes per frame, and the gradient [Brush] is no longer
 * re-allocated in composition every frame (the old `rememberInfiniteTransition` + composition-scope
 * `Brush.verticalGradient` did both). Visual is unchanged: same 600ms reverse pulse, red50→red300 top.
 */
private fun Modifier.urgentWash(
    from: androidx.compose.ui.graphics.Color,
    to: androidx.compose.ui.graphics.Color,
): Modifier = this then UrgentWashElement(from, to)

private data class UrgentWashElement(
    val from: androidx.compose.ui.graphics.Color,
    val to: androidx.compose.ui.graphics.Color,
) : ModifierNodeElement<UrgentWashNode>() {
    override fun create(): UrgentWashNode = UrgentWashNode(from, to)

    override fun update(node: UrgentWashNode) {
        node.update(from, to)
    }
}

private class UrgentWashNode(
    private var from: androidx.compose.ui.graphics.Color,
    private var to: androidx.compose.ui.graphics.Color,
) : Modifier.Node(), DrawModifierNode {

    // Pulse 0f⇄1f, read in draw() so each animation step invalidates only the draw phase. Self-driven
    // on the node's coroutine scope, which the framework cancels on detach → the pulse stops then.
    private val pulse = Animatable(0f)

    override fun onAttach() {
        coroutineScope.launch {
            pulse.animateTo(
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(URGENT_BLINK_MILLIS, easing = FastOutSlowInEasing),
                    repeatMode = RepeatMode.Reverse,
                ),
            )
        }
    }

    fun update(newFrom: androidx.compose.ui.graphics.Color, newTo: androidx.compose.ui.graphics.Color) {
        // Endpoint-only change keeps the running pulse's phase; just redraw with the new colours.
        from = newFrom
        to = newTo
        invalidateDraw()
    }

    override fun ContentDrawScope.draw() {
        val top = lerp(from, to, pulse.value)
        drawRect(
            brush = Brush.verticalGradient(listOf(top, androidx.compose.ui.graphics.Color.White)),
            size = size,
        )
        drawContent()
    }
}

/** How long a per-second progress step is smoothed over. Matches the previous tween. */
private const val WASH_SMOOTHING_MILLIS = 1100L

/**
 * Upper bound on redraws per smoothing run. `WASH_SMOOTHING_MILLIS / 64` ≈ 17 ms, i.e. one
 * step per frame at 60 Hz — never schedule redraws faster than the display can show them.
 */
private const val WASH_MAX_STEPS = 64

/**
 * How many redraws to spend smoothing a progress jump of [deltaProgress] across a footer
 * [widthPx] wide: **one step per device pixel the fill actually moves**, floored at 1 and
 * capped at [WASH_MAX_STEPS].
 *
 * This is the whole point of the countdown wash's cost profile, so it is a pure function and
 * directly tested. A 5-minute check-in window advances ~0.0033 progress/s ≈ 3.6 px/s → 4 steps;
 * a 30-second accept window advances ~0.033 progress/s ≈ 36 px/s → 36 steps. Animating either at
 * frame rate would redraw two full-width gradients ~44×/s to move the bar a fraction of a pixel.
 */
internal fun countdownWashSteps(deltaProgress: Float, widthPx: Float): Int =
    (deltaProgress * widthPx).roundToInt().coerceIn(1, WASH_MAX_STEPS)

/**
 * The "running late" countdown wash — a red300 → transparent fill anchored at the RIGHT edge,
 * growing leftward to [progress], over a static [background] → white gradient.
 *
 * **Why this is a node and not an `Animatable` + `LaunchedEffect`.** The previous version
 * re-targeted an 1100 ms `tween` every time `progress` changed, and `progress` changes once a
 * second — so the animation was cancelled and restarted before it could ever settle, leaving an
 * animator permanently in flight that invalidated the draw phase on *every* frame. On-device
 * profiling measured the delayed-check-in footer at **2,668 frames / 60 s (~44 fps) and 43% of
 * one core** while a penalty countdown was live, redrawing two full-width gradient rects each
 * frame for a bar that moves a fraction of a pixel between frames.
 *
 * So the smoothing steps by **pixel, not by frame**: each progress update is walked to its new
 * value in as many steps as the fill actually moves device pixels (1 step ≈ 1 px), capped at
 * [WASH_MAX_STEPS]. That is self-adjusting — a 5-minute check-in window moves ~3.6 px/s and
 * redraws ~4×/s, while a 30-second accept window moves ~36 px/s and redraws ~36×/s, staying
 * smooth exactly where smoothness is perceptible. Sub-pixel motion is not worth a frame.
 *
 * Behaviour is otherwise preserved: forward motion (time elapsing) eases in; any BACKWARD target
 * — a new countdown window starting after a card fires — snaps instantly so the bar restarts from
 * scratch rather than visibly sliding back. Like [urgentWash], the animation is self-driven on the
 * node's own coroutine scope, which the framework cancels on detach, and the value is read only in
 * `draw()` so the footer never recomposes per frame.
 */
private fun Modifier.countdownWash(
    progress: Float,
    background: androidx.compose.ui.graphics.Color,
    fill: androidx.compose.ui.graphics.Color,
): Modifier = this then CountdownWashElement(progress.coerceIn(0f, 1f), background, fill)

private data class CountdownWashElement(
    val progress: Float,
    val background: androidx.compose.ui.graphics.Color,
    val fill: androidx.compose.ui.graphics.Color,
) : ModifierNodeElement<CountdownWashNode>() {
    override fun create(): CountdownWashNode = CountdownWashNode(progress, background, fill)

    override fun update(node: CountdownWashNode) {
        node.update(progress, background, fill)
    }
}

private class CountdownWashNode(
    private var target: Float,
    private var background: androidx.compose.ui.graphics.Color,
    private var fill: androidx.compose.ui.graphics.Color,
) : Modifier.Node(), DrawModifierNode {

    /** What `draw()` renders. Mutated only from the main thread (this node's scope + draw). */
    private var displayed: Float = target

    /** Last drawn width, so the step count can be sized in real device pixels. */
    private var widthPx: Float = 0f

    private var stepJob: Job? = null

    fun update(
        newTarget: Float,
        newBackground: androidx.compose.ui.graphics.Color,
        newFill: androidx.compose.ui.graphics.Color,
    ) {
        val colorsChanged = newBackground != background || newFill != fill
        background = newBackground
        fill = newFill

        if (newTarget == target) {
            // Recomposition with an unchanged countdown — never restart the walk.
            if (colorsChanged) invalidateDraw()
            return
        }
        target = newTarget

        if (newTarget <= displayed) {
            // Backward (or equal): snap. A new window restarts the bar rather than sliding back.
            stepJob?.cancel()
            stepJob = null
            displayed = newTarget
            invalidateDraw()
            return
        }
        startWalk(newTarget)
    }

    private fun startWalk(newTarget: Float) {
        stepJob?.cancel()
        val from = displayed
        val delta = newTarget - from
        // Before the first draw the width is unknown — land the value rather than guess a rate.
        if (widthPx <= 0f) {
            displayed = newTarget
            invalidateDraw()
            return
        }
        val steps = countdownWashSteps(delta, widthPx)
        val stepMillis = WASH_SMOOTHING_MILLIS / steps
        stepJob = coroutineScope.launch {
            for (i in 1..steps) {
                delay(stepMillis)
                displayed = from + delta * (i.toFloat() / steps)
                invalidateDraw()
            }
            displayed = newTarget
            invalidateDraw()
        }
    }

    override fun ContentDrawScope.draw() {
        widthPx = size.width
        drawRect(
            brush = Brush.verticalGradient(
                0f to background,
                1f to androidx.compose.ui.graphics.Color.White,
            ),
        )
        val current = displayed
        if (current > 0f) {
            drawRect(
                brush = Brush.verticalGradient(
                    0f to fill,
                    1f to androidx.compose.ui.graphics.Color.White.copy(alpha = 0f),
                ),
                topLeft = Offset(size.width * (1f - current), 0f),
                size = Size(size.width * current, size.height),
            )
        }
        drawContent()
    }
}

/* ── Previews ────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewSnabbitActionFooterDefault() {
    SnabbitTheme {
        SnabbitActionFooter(
            caption = "CHECK IN BY 7:45 PM",
            time = "1:23",
            primaryLabel = "Check In",
            onPrimaryClick = {},
            progress = 0.25f,
        )
    }
}

@Preview
@Composable
private fun PreviewSnabbitActionFooterRunningLate() {
    SnabbitTheme {
        SnabbitActionFooter(
            caption = "RUNNING LATE",
            time = "-01:23",
            primaryLabel = "Check In",
            onPrimaryClick = {},
            urgent = true,
            progress = 0.5f,
            secondaryLabel = "Deny",
            onSecondaryClick = {},
        )
    }
}

@Preview
@Composable
private fun PreviewSnabbitActionFooterUrgentBlink() {
    SnabbitTheme {
        SnabbitActionFooter(
            caption = "ACCEPT IN",
            time = "0:00",
            primaryLabel = "Accept Job",
            onPrimaryClick = {},
            buttonType = SnabbitButtonStyle.Success,
            urgent = true,
            urgentStyle = SnabbitActionFooterUrgentStyle.Blink,
        )
    }
}

@Preview
@Composable
private fun PreviewSnabbitActionFooterNoInternet() {
    SnabbitTheme {
        SnabbitActionFooter(
            caption = "CHECK IN BY 7:45 PM",
            time = "1:23",
            primaryLabel = "Check In",
            onPrimaryClick = {},
            progress = 0.25f,
            connectivityStatus = ConnectivityStatus.Offline,
        )
    }
}

@Preview
@Composable
private fun PreviewSnabbitActionFooterBadInternet() {
    SnabbitTheme {
        SnabbitActionFooter(
            caption = "CHECK IN BY 7:45 PM",
            time = "1:23",
            primaryLabel = "Check In",
            onPrimaryClick = {},
            progress = 0.25f,
            connectivityStatus = ConnectivityStatus.BadConnection,
        )
    }
}
