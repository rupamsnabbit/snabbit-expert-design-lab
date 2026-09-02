package com.snabbit.runner.shared.features.job.presentation.common

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonLoadingPosition
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle

/**
 * Default fill time for an [AutoProgressButton] — the campaign auto-advance window (20s). Used by
 * the post-check-in ([SuccessfulCheckIn]) and job-end ([PostJobEndCampaign]) campaigns: their
 * progress button fills over this window before advancing to the next step.
 */
internal const val DEFAULT_AUTO_ADVANCE_MILLIS = 20_000

/**
 * A [SnabbitButton] that drives its own fill: the trailing band animates 0→1 over
 * [durationMillis] and fires [onProgressComplete] when it reaches the end (auto-advance).
 * Tapping the button completes early. [onProgressComplete] fires **at most once**.
 *
 * Shared by [SuccessfulCheckIn] (auto-dismiss "OK") and [TasksDoneSelector] (auto-confirm the
 * selected tasks). The callback is read fresh at fire time via [rememberUpdatedState], so it can
 * close over live state (e.g. the current selection) without capturing a stale value.
 *
 * @param onProgressComplete run once when the fill completes or the button is tapped.
 * @param style the DS button style (Primary = brand pink, Success = green).
 * @param durationMillis how long the fill takes before auto-firing.
 */
@Composable
internal fun AutoProgressButton(
    label: String,
    onProgressComplete: () -> Unit,
    modifier: Modifier = Modifier,
    style: SnabbitButtonStyle = SnabbitButtonStyle.Primary,
    durationMillis: Int = DEFAULT_AUTO_ADVANCE_MILLIS,
) {
    val currentOnComplete by rememberUpdatedState(onProgressComplete)
    val progress = remember { Animatable(0f) }
    var fired by remember { mutableStateOf(false) }

    fun fireOnce() {
        if (!fired) {
            fired = true
            currentOnComplete()
        }
    }

    LaunchedEffect(Unit) {
        progress.animateTo(targetValue = 1f, animationSpec = tween(durationMillis, easing = LinearEasing))
        fireOnce()
    }

    SnabbitButton(
        text = label,
        onClick = { fireOnce() },
        modifier = modifier,
        style = style,
        progress = progress.value,
        loadingPosition = SnabbitButtonLoadingPosition.Trailing,
        fullWidth = true,
        size = SnabbitButtonSize.L,
    )
}
