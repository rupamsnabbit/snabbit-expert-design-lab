package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitTheme

/**
 * Brand-colored capture button (bespoke camera shutter — no DS equivalent).
 *
 * Structure (outside in): 82dp ring (brand border) → 70dp filled brand circle →
 * 24dp rounded-square icon (soft-brand border). Colors come from
 * `SnabbitTheme.colors` (brand tokens); sizes are the Figma spec.
 *
 * **Behavior:** haptic on tap; inner circle dims to 60% while pressed and back
 * on release (try/finally survives cancellation); 50% overall opacity when
 * disabled. `rememberUpdatedState` keeps the tap handler fresh — the record
 * button stays enabled across start→stop, so `pointerInput(enabled)` wouldn't
 * otherwise re-capture the latest `onClick`. When [isRecording] (video capture in
 * progress), the inner circle morphs into a smaller rounded "stop" square and back
 * to a circle on stop — purely visual, the tap still toggles recording.
 */
@Composable
fun CaptureButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isRecording: Boolean = false,
) {
    val haptic = LocalHapticFeedback.current
    val currentOnClick by rememberUpdatedState(onClick)
    var isPressed by remember { mutableStateOf(false) }

    // Brand tokens read in composition (CompositionLocal — not file scope).
    val brand = SnabbitTheme.colors.bgBrand
    val brandSoft = SnabbitTheme.colors.borderBrand

    // Animate inner circle opacity: 1.0 → 0.6 on press, back to 1.0 on release
    val innerAlpha by animateFloatAsState(
        targetValue = when {
            !enabled -> DISABLED_ALPHA
            isPressed -> PRESSED_ALPHA
            else -> 1f
        },
        animationSpec = tween(durationMillis = ANIMATION_DURATION_MS),
        label = "captureButtonAlpha",
    )

    // Overall opacity for the disabled state
    val outerAlpha = if (enabled) 1f else DISABLED_ALPHA

    // Video record affordance: the inner circle morphs into a smaller rounded
    // "stop" square while recording, and back to a full circle when idle. Shrinking
    // is required — a full-size square's corners would exceed the outer ring.
    val innerSize by animateDpAsState(
        targetValue = if (isRecording) STOP_SIZE else INNER_SIZE,
        animationSpec = tween(durationMillis = ANIMATION_DURATION_MS),
        label = "captureButtonInnerSize",
    )
    val innerCorner by animateDpAsState(
        targetValue = if (isRecording) STOP_CORNER else INNER_SIZE / 2,
        animationSpec = tween(durationMillis = ANIMATION_DURATION_MS),
        label = "captureButtonInnerCorner",
    )

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .size(OUTER_SIZE)
            .alpha(outerAlpha)
            .clip(CircleShape)
            .border(width = OUTER_BORDER_WIDTH, color = brand, shape = CircleShape)
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                detectTapGestures(
                    onPress = {
                        isPressed = true
                        try {
                            tryAwaitRelease()
                        } finally {
                            // Always reset — even if the coroutine is cancelled
                            // (e.g. when enabled flips to false mid-press)
                            isPressed = false
                        }
                    },
                    onTap = {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        currentOnClick()
                    },
                )
            },
    ) {
        // Inner indicator: filled brand circle (idle) that morphs to a rounded
        // "stop" square while recording video.
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(innerSize)
                .clip(RoundedCornerShape(innerCorner))
                .alpha(innerAlpha)
                .background(brand),
        ) {
            // Center icon (rounded square outline) — hidden while recording, where
            // the stop-square itself is the affordance.
            if (!isRecording) {
                Box(
                    modifier = Modifier
                        .size(ICON_SIZE)
                        .border(
                            width = ICON_BORDER_WIDTH,
                            color = brandSoft,
                            shape = RoundedCornerShape(ICON_CORNER_RADIUS),
                        ),
                )
            }
        }
    }
}

// ── Figma spec constants ─────────────────────────────────────────

private val OUTER_SIZE = 82.dp
private val OUTER_BORDER_WIDTH = 1.dp
private val INNER_SIZE = 70.dp
private val STOP_SIZE = 36.dp
private val STOP_CORNER = 8.dp
private val ICON_SIZE = 24.dp
private val ICON_BORDER_WIDTH = 1.5.dp
private val ICON_CORNER_RADIUS = 8.dp
private const val PRESSED_ALPHA = 0.6f
private const val DISABLED_ALPHA = 0.5f
private const val ANIMATION_DURATION_MS = 150
