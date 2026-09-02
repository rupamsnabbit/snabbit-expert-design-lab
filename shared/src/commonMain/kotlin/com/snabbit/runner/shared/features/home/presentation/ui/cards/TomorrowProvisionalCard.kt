package com.snabbit.runner.shared.features.home.presentation.ui.cards

import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitCard
import com.snabbit.design.atoms.SnabbitCardVariant
import com.snabbit.design.atoms.SnabbitDivider
import com.snabbit.design.atoms.SnabbitDividerType
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.calendar_small
import com.snabbit.runner.shared.resources.rupee_circle
import org.jetbrains.compose.resources.painterResource
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent

/**
 * AttendanceCard → TomorrowProvisional state (Figma DS node 1580:6418
 * "Default", screen Figma 76-35279).
 *
 * Pixel-perfect mapping to the Figma DS spec:
 *  - Outer card: `SnabbitCard` `Elevated` variant — gray-100 header strip
 *    + white body, 16dp padding, 16dp gap between body sections.
 *  - Header strip: 92dp tall (Figma `h-[92px]`); date (BodyMd, textSecondary)
 *    + shift window (Heading2, textPrimary) centered.
 *  - Earn row: full-width SpaceBetween; left = rupee placeholder + prefix,
 *    right = amount SemiBold.
 *  - Divider: gray line.
 *  - Mark-attendance row: Calendar icon + prompt, left-aligned.
 *  - Buttons row: 12dp gap; Size L (56dp) Destructive (Absent) + Success
 *    (Present), both weight(1f), with circled-X / circled-check leading icons
 *    tinted white to match Figma.
 *
 * ponytail: rupee icon doesn't exist in DS 0.11.0 — using a 16dp gray-200
 * placeholder Box per "icons stay placeholders until DS ships them" rule.
 * Card radius is 12dp (DS Elevated default) — Figma wants 16dp; the only DS
 * variant with 16dp is `Selected` which adds a pink border. Flag for DS.
 * Border color: DS Elevated uses gray-100 (#F3F4F6); Figma wants gray-200
 * (#E5E7EB). DS gap.
 */
@Composable
fun TomorrowProvisionalCard(
    card: HomeCard.Attendance.TomorrowProvisional,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
    /** True while the Present POST (`ConfirmMarkProvisional(present=true)`) is
     *  in flight — shows the inline spinner on the Present button and
     *  cross-disables Absent. Absent has no card-level loading state because
     *  it only opens the EarningLoss sheet (no network), which renders its
     *  own spinner once the user confirms there. */
    presentLoading: Boolean = false,
) {
    SnabbitCard(
        modifier = modifier.fillMaxWidth(),
        variant = SnabbitCardVariant.Elevated,
        // Figma 76:35286: 1.5dp gray-200 border @ 16dp radius. DS Elevated
        // defaults to gray-100 @ 12dp, so override border + radius to match.
        borderColor = SnabbitTheme.colors.borderDefault,
        borderWidth = SnabbitTheme.borderWidth.thick,
        radius = SnabbitTheme.borderRadius.xl,
        // ponytail: Figma 1580:6375 specs 92dp but with web line-heights;
        // Compose Heading2 has 32sp lh which puts visible content ~60dp,
        // leaving an empty band. 76dp matches the visual rhythm.
        headerHeight = 76.dp,
        paddingOverride = SnabbitTheme.spacing.componentPaddingMd,
        header = { CardHeader(card.day.dateLabel, card.day.shiftWindowLabel) },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapLg)) {
            if (card.day.potentialEarnLabel != null) {
                EarnRow(prefix = strings.tomorrowEarnPrefix, amount = card.day.potentialEarnLabel)
                SnabbitDivider(type = SnabbitDividerType.Line)
            }

            MarkAttendanceRow(prompt = strings.tomorrowMarkAttendancePrompt)

            // Mirror Dart `provisional_attendance.dart:142`: tapping Absent
            // opens the EarningLoss confirmation sheet; Present marks direct
            // (PR-2 wires the JobHttp call inside HomeViewModel).
            com.snabbit.runner.shared.features.home.presentation.ui.AttendanceButtonRow(
                absentLabel = strings.tomorrowAbsentCta,
                presentLabel = strings.tomorrowPresentCta,
                onAbsent = { onIntent(HomeUiIntent.TapAbsentTomorrow) },
                onPresent = { onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)) },
                presentLoading = presentLoading,
            )
        }
    }
}

/**
 * Gray header strip — date + shift window centered. Rendered inside the
 * `SnabbitCardVariant.Elevated` `header` slot (92dp tall).
 *
 * Vertical gap between date and shift = 4dp per Figma node 1580:6375
 * (`gap-[4px] items-center`). Without this, the line-height baselines of
 * BodyMd (16/24) and Heading2 (24/32) push the strings apart by ~8sp.
 */
@Composable
internal fun CardHeader(dateLabel: String, shiftWindowLabel: String) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs, Alignment.CenterVertically),
    ) {
        SnabbitText(
            text = dateLabel,
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
        )
        SnabbitText(
            text = shiftWindowLabel,
            variant = SnabbitTextVariant.Heading2,
            color = SnabbitTheme.colors.textPrimary,
        )
    }
}

@Composable
private fun EarnRow(prefix: String, amount: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
        ) {
            SnabbitImage(
                painter = painterResource(Res.drawable.rupee_circle),
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                contentScale = ContentScale.Fit,
            )
            SnabbitText(
                text = prefix,
                variant = SnabbitTextVariant.BodyMd,
                color = SnabbitTheme.colors.textSecondary,
            )
        }
        SnabbitText(
            text = amount,
            variant = SnabbitTextVariant.BodyMd,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textPrimary,
        )
    }
}

@Composable
private fun MarkAttendanceRow(prompt: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
    ) {
        SnabbitImage(
            painter = painterResource(Res.drawable.calendar_small),
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            contentScale = ContentScale.Fit,
        )
        SnabbitText(
            text = prompt,
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
        )
    }
}
