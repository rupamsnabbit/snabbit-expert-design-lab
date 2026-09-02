package com.snabbit.runner.shared.features.gamification.presentation.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.runner.shared.core.image.RemoteImage
import com.snabbit.runner.shared.features.gamification.domain.model.NudgeKind
import com.snabbit.runner.shared.ui.nudges.SnabbitRedCardNudge
import com.snabbit.runner.shared.features.gamification.domain.model.PreActionNudge
import com.snabbit.runner.shared.features.gamification.domain.model.deriveNudgePill
import com.snabbit.runner.shared.features.gamification.presentation.ResolveNudgeLabel
import kotlinx.coroutines.delay

/**
 * A pre-action nudge strip — the KMP port of Dart
 * `lib/widgets/gamification/nudge_banner.dart` (Figma 5510:15594). Themed by
 * [PreActionNudge.nudgeKind]:
 *  - **risk** — gray-50 → red-200 gradient, red-300 border.
 *  - **bonus** — blue gradient, white text.
 *  - **opportunity / unknown** — amber gradient.
 *
 * Shows the resolved label, an optional trailing coin / red-card pill
 * ([deriveNudgePill]), and a live `HH:MM:SS` countdown when the nudge carries an
 * expiry. On expiry it invokes [onExpired] (wire to
 * `GamificationProjector.requestRefresh()` so Dart re-fetches state — the KMP
 * analogue of Dart's `fetchDataNow()`).
 *
 * ponytail: the copy carries `**bold**` emphasis segments, but `SnabbitText` is
 * plain-string only (same DS gap flagged in `WaiverSheet`) — the markers are
 * stripped and the whole label rendered at a medium weight until the DS ships an
 * AnnotatedString overload.
 */
@Composable
fun NudgeBanner(
    nudge: PreActionNudge,
    onExpired: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val kind = nudge.nudgeKind
    // Risk nudges carrying red cards render as the DS red-card nudge — the tilted
    // "−50" card stack poking over the pill (Figma 2:6891 / 939:54144) — so the
    // accept screen matches the check-in penalty banner. Only when there is no
    // expiry: SnabbitRedCardNudge has no countdown slot, so a timed nudge keeps
    // the generic strip rather than silently losing its timer.
    if (kind == NudgeKind.Risk && (nudge.redCards ?: 0) > 0 && nudge.expiresAtMs == null) {
        SnabbitRedCardNudge(
            modifier = modifier,
            text = ResolveNudgeLabel.resolve(nudge.label).replace("**", ""),
            cardCount = nudge.redCards ?: 1,
        )
        return
    }
    // ponytail: the Bonus (OT) strip wants a dark-blue ramp (Dart #1D4ED8→#3B82F6).
    // DS exposes `blue100` for certain; the darker `blue700/500/300` steps are
    // assumed present — if the DS palette lacks them, add the tokens (or a local
    // suppressed const set like SheetColors) rather than hardcoding here.
    val (bgStart, bgEnd, border) = when (kind) {
        // Dart nudge_banner risk strip: gray-50→red-200 gradient, red-200 border.
        NudgeKind.Risk -> Triple(
            SnabbitColorsLight.gray100, SnabbitColorsLight.red200, SnabbitColorsLight.red200,
        )
        NudgeKind.Bonus -> Triple(
            SnabbitColorsLight.blue700, SnabbitColorsLight.blue500, SnabbitColorsLight.blue300,
        )
        else -> Triple(
            SnabbitColorsLight.yellow50, SnabbitColorsLight.yellow100, SnabbitColorsLight.yellow300,
        )
    }
    val textColor = if (kind == NudgeKind.Bonus) {
        SnabbitColorsLight.whiteDefault
    } else {
        SnabbitColorsLight.gray700
    }
    val shape = RoundedCornerShape(12.dp)
    val text = ResolveNudgeLabel.resolve(nudge.label).replace("**", "")
    val countdown = rememberCountdownLabel(nudge.expiresAtMs, onExpired)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 46.dp)
            .background(Brush.horizontalGradient(listOf(bgStart, bgEnd)), shape)
            .border(1.dp, border, shape)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // BE-driven leading icon (Dart `_LeadingIcon`: 36dp, 8dp radius, cover). RemoteImage
        // draws nothing on blank URL / load failure, so the strip degrades to text-only.
        RemoteImage(
            url = nudge.iconUrl,
            contentDescription = null,
            modifier = Modifier.size(36.dp).clip(RoundedCornerShape(8.dp)),
        )
        Column(modifier = Modifier.weight(1f)) {
            SnabbitText(
                text = text,
                color = textColor,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Medium,
            )
            if (countdown != null) {
                SnabbitText(
                    text = countdown,
                    color = textColor,
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
        NudgePillBadge(pill = deriveNudgePill(nudge.goldCoins, nudge.redCards))
    }
}

/**
 * Renders each nudge in [nudges] as a [NudgeBanner], stacked with a gap — the KMP
 * port of Dart `NudgeBannerList`.
 */
@Composable
fun NudgeBannerList(
    nudges: List<PreActionNudge>,
    onExpired: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (nudges.isEmpty()) return
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        nudges.forEach { nudge ->
            NudgeBanner(nudge = nudge, onExpired = onExpired)
        }
    }
}

/**
 * Ticks a `HH:MM:SS` (or `MM:SS`) countdown to [expiresAtMs], calling [onExpired]
 * once when it elapses. Null when there is no expiry. Confines the clock / OptIn
 * to one helper (matching `LunchProjector`).
 */
@OptIn(kotlin.time.ExperimentalTime::class)
@Composable
private fun rememberCountdownLabel(expiresAtMs: Long?, onExpired: () -> Unit): String? {
    if (expiresAtMs == null) return null
    var remainingMs by remember(expiresAtMs) {
        mutableStateOf(expiresAtMs - kotlin.time.Clock.System.now().toEpochMilliseconds())
    }
    LaunchedEffect(expiresAtMs) {
        while (remainingMs > 0) {
            delay(1000)
            remainingMs = expiresAtMs - kotlin.time.Clock.System.now().toEpochMilliseconds()
        }
        onExpired()
    }
    if (remainingMs <= 0) return null
    val totalSec = remainingMs / 1000
    val h = totalSec / 3600
    val m = (totalSec % 3600) / 60
    val s = totalSec % 60
    fun two(n: Long) = n.toString().padStart(2, '0')
    return if (h > 0) "${two(h)}:${two(m)}:${two(s)}" else "${two(m)}:${two(s)}"
}
