package com.snabbit.runner.shared.features.awol.presentation.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.image.RemoteImage
import com.snabbit.runner.shared.features.awol.domain.AwolPhase
import com.snabbit.runner.shared.features.awol.domain.AwolSnapshot
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.awol.presentation.AwolUiState

// Per-phase accent/container tokens (FR-14: payload/phase-driven variants of one
// component). Inferred-type helpers so no file names the raw Color type — the
// detekt ForbiddenImport guardrail (all values are SnabbitTheme tokens).

/** The phase's accent token (breach & job error-red / re-entered success-green). */
@Composable
internal fun awolAccent(phase: AwolPhase) = when (phase) {
    AwolPhase.BREACH -> SnabbitTheme.colors.textError
    AwolPhase.JOB -> SnabbitTheme.colors.textError
    AwolPhase.RE_ENTERED -> SnabbitTheme.colors.textSuccess
}

/** The phase's subtle container token, pairing [awolAccent]. */
@Composable
internal fun awolContainer(phase: AwolPhase) = when (phase) {
    AwolPhase.BREACH -> SnabbitTheme.colors.bgErrorSubtle
    AwolPhase.JOB -> SnabbitTheme.colors.bgErrorSubtle
    AwolPhase.RE_ENTERED -> SnabbitTheme.colors.bgSuccessSubtle
}

/**
 * The alert card body both surfaces share (§2A mockups): image slot →
 * [badge] → red-card pill (when held, FR-07) → title → countdown meter
 * (hidden without an anchor) → warning text → penalty-rate strip (server-
 * computed, FR-03) → consequences (re-entered, FR-08). CTAs are appended by
 * the callers ([AwolHomeCard] / [AwolOverlaySurface]) — the home card has a
 * single Show Directions; the overlay adds the secondary "I Understand"
 * (dismissal contract, FR-05).
 *
 * The image slot renders [AwolUiState.imageUrl] via the core [RemoteImage]
 * seam over a neutral placeholder block — no URL (or a failed load) leaves
 * the placeholder showing, so the card degrades exactly as before the
 * loader existed.
 */
@Composable
internal fun AwolAlertContent(
    state: AwolUiState,
    snapshot: AwolSnapshot,
    strings: AwolStrings,
    showBadge: Boolean,
    modifier: Modifier = Modifier,
) {
    val accent = awolAccent(snapshot.phase)
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(SnabbitTheme.colors.bgSecondary),
        ) {
            RemoteImage(
                url = state.imageUrl,
                contentDescription = null,
                modifier = Modifier.matchParentSize(),
            )
        }

        if (showBadge) {
            AwolBadge(text = snapshot.badgeText, phase = snapshot.phase)
        }

        if (snapshot.redCardsTotal > 0) {
            AwolRedCardPill(count = snapshot.redCardsTotal, strings = strings)
        }

        SnabbitText(
            text = snapshot.titleText,
            variant = SnabbitTextVariant.Heading3,
            color = SnabbitTheme.colors.textPrimary,
            textAlign = TextAlign.Center,
        )

        state.remainingSeconds?.let { remaining ->
            AwolCountdownMeter(
                remainingSeconds = remaining,
                totalSeconds = snapshot.totalSeconds,
                phase = snapshot.phase,
                timeLeftLabel = strings.timeLeftLabel,
            )
        }

        SnabbitText(
            text = snapshot.warningText,
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
        )

        if (snapshot.showPenaltyRate) {
            AwolPenaltyRateStrip(
                // Count = the "N red cards will be added" number from the payload (matches
                // the warning above). Interval = the countdown window the meter shows
                // (p75 on round 1, step interval after), so the strip always agrees with
                // the timer. Count falls back to the bundled constant for legacy hoods.
                count = snapshot.penaltyRateCount?.toString() ?: strings.penaltyRateCount,
                connector = strings.penaltyRateConnector,
                // Floor of the window — never "0 Minutes" (windows are minute-granular by design).
                interval = strings.penaltyRateIntervalOf((snapshot.totalSeconds / 60).coerceAtLeast(1)),
            )
        }

        // Consequences are a re-entered-state concept (legacy `AwolData`); on BREACH the
        // penalty-rate strip carries the messaging (Figma §2A), so any breach `consequences`
        // the server sends (occasionally malformed) are not surfaced here.
        if (snapshot.phase != AwolPhase.BREACH && snapshot.consequences.isNotEmpty()) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                snapshot.consequences.forEach { consequence ->
                    consequence.text?.let { text ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .clip(CircleShape)
                                    .background(accent),
                            )
                            SnabbitText(
                                text = text,
                                variant = SnabbitTextVariant.BodyMd,
                                color = SnabbitTheme.colors.textSecondary,
                            )
                        }
                    }
                }
            }
        }
    }
}
