package com.snabbit.runner.shared.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonLoadingPosition
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.ui.icons.AppIcons

/**
 * A single footer action in a [GeneralErrorState]. Style / enabled / loading are per-button, so a
 * screen can, say, show a primary "Try again" (spinning while it retries) beside a neutral
 * "Contact support".
 *
 * @param label button copy. @param onClick tap handler.
 * @param style DS button style — defaults to [SnabbitButtonStyle.Primary].
 * @param enabled tappable when true. @param loading shows the button's spinner and blocks taps.
 * @param loadingPosition which side the spinner sits while [loading] — defaults to
 *   [SnabbitButtonLoadingPosition.Leading] (spinner to the LEFT of the label, e.g. the "Try again"
 *   retry on the check-in location-error state).
 */
@Immutable
data class ErrorStateAction(
    val label: String,
    val onClick: () -> Unit,
    val style: SnabbitButtonStyle = SnabbitButtonStyle.Primary,
    val enabled: Boolean = true,
    val loading: Boolean = false,
    val loadingPosition: SnabbitButtonLoadingPosition = SnabbitButtonLoadingPosition.Leading,
)

/**
 * Stable, [Immutable] wrapper around the footer [ErrorStateAction] list. A bare
 * `List<ErrorStateAction>` is an *unstable* Compose parameter, so passing one straight into
 * [GeneralErrorState] stops it from skipping and forces a recompose on every parent tick; wrapping
 * the list in this `@Immutable` type marks it stable and restores skipping.
 */
@Immutable
data class ErrorStateActions(val items: List<ErrorStateAction>)

/**
 * **General error / empty state** — a centered icon + (multiline) title + optional (multiline)
 * subtitle, over a persistent bottom footer of full-width action buttons. Figma "Shift — Job
 * Lifecycle DS" nodes 991:57980 (full screen) and 991:58006 (bottom-sheet content); the two share
 * this layout and differ only in host chrome.
 *
 * Fully presentational and configurable:
 *  - [icon] is a replaceable slot (defaults to the red alert badge); pass `null` to hide it.
 *  - [subtitle] is optional.
 *  - [actions] is a 0..n list (wrapped in the stable [ErrorStateActions]) — none hides the footer,
 *    one is a single CTA, two gives the common "Try again" + "Contact support" pair, and more just
 *    stack below. Each [ErrorStateAction] carries its own style / enabled / loading.
 *
 * **Not** wrapped in a screen or bottom sheet — embed it in either. It fills its container's width
 * and pins the footer to the bottom via a weighted, scrollable content area, so give it a
 * **height-bounded** modifier: `Modifier.fillMaxSize()` inside `SnabbitScreen`'s content for the
 * full-screen case, or a fixed / `fillMaxHeight(fraction)` height inside a bottom sheet. System
 * safe-area insets are the host's job (see `SnabbitScreen`), not this component's.
 *
 * @param title the headline (H3/20-Semibold, gray-800); wraps across lines.
 * @param subtitle optional supporting copy (Body-S/14-Medium, gray-500); wraps across lines.
 * @param actions footer buttons (wrapped in [ErrorStateActions]), top-to-bottom; empty hides the footer.
 * @param icon top illustration slot; `null` hides it. Defaults to the red alert badge.
 */
@Composable
fun GeneralErrorState(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    actions: ErrorStateActions = ErrorStateActions(emptyList()),
    icon: (@Composable () -> Unit)? = DefaultErrorIconSlot,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        // Centered content — takes the space above the footer and scrolls if the copy is long.
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (icon != null) {
                icon()
                Spacer(Modifier.height(16.dp)) // Figma: 16 between the icon and the title.
            }
            SnabbitText(
                text = title,
                // H3/20-Semibold, gray-800 (#1F2937 — no exact semantic token).
                fontSize = 20.sp,
                lineHeight = 28.sp,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitColorsLight.gray800,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            if (subtitle != null) {
                Spacer(Modifier.height(4.dp)) // Figma: 4 between title and subtitle.
                SnabbitText(
                    text = subtitle,
                    // Body-S/14-Medium, gray-500.
                    fontSize = 14.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Medium,
                    color = SnabbitTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }

        // Persistent footer — full-width buttons stacked 12dp apart (Figma "Button Groups").
        if (actions.items.isNotEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                actions.items.forEach { action ->
                    SnabbitButton(
                        text = action.label,
                        onClick = action.onClick,
                        style = action.style,
                        size = SnabbitButtonSize.L,
                        enabled = action.enabled,
                        loading = action.loading,
                        loadingPosition = action.loadingPosition,
                        fullWidth = true,
                    )
                }
            }
        }
    }
}

/**
 * Default (icon-only) slot for [GeneralErrorState]'s `icon`, hoisted to a single stable instance so
 * the default doesn't allocate a fresh lambda per recomposition — a churning default would defeat
 * the skipping the [ErrorStateActions] wrapper restores.
 */
private val DefaultErrorIconSlot: @Composable () -> Unit = { DefaultErrorIcon() }

/**
 * The default error badge — a 64dp red-100 disc holding the red-600 alert-circle glyph
 * ([AppIcons.AlertCircle]), matching `general_error_state_icon.svg`.
 */
@Composable
private fun DefaultErrorIcon() {
    Box(
        modifier = Modifier
            .size(64.dp)
            .clip(CircleShape)
            .background(SnabbitColorsLight.red100), // #FEE2E2 red-100 badge fill
        contentAlignment = Alignment.Center,
    ) {
        Image(
            imageVector = AppIcons.AlertCircle,
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
        )
    }
}

/* ── Preview ─────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewGeneralErrorState() {
    SnabbitTheme {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(600.dp)
                .background(SnabbitTheme.colors.bgPrimary),
        ) {
            GeneralErrorState(
                modifier = Modifier.fillMaxSize(),
                title = "We couldn’t mark your attendance",
                subtitle = "Don’t worry your shift data is safe. This might be a network issue.",
                actions = ErrorStateActions(
                    listOf(
                        ErrorStateAction("Try Again", onClick = {}, style = SnabbitButtonStyle.Primary),
                        ErrorStateAction(
                            "Contact Support",
                            onClick = {},
                            style = SnabbitButtonStyle.NeutralStroke,
                        ),
                    ),
                ),
            )
        }
    }
}
