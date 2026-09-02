package com.snabbit.runner.shared.features.home.presentation.ui.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.design.theme.SnabbitTheme

/**
 * "Red cards waived off this time" sheet — Figma DS 1597:6691, Dart port of
 * `lib/widgets/gamification/waiver_bottom_sheet.dart`.
 *
 * Triggered server-side when a gamification post-action response carries
 * `status: WAIVED`. Non-dismissable — the runner must acknowledge with
 * "I will not repeat again" before the sheet closes.
 *
 * Slot composition over [AttendanceSheetShell]:
 *  - **header**: yellow Warning pill + faded red-card cluster, stacked.
 *  - **title**: "Red cards waived off this time" ([HomeStrings.waiverTitle]).
 *  - **content**: gray-500 "Repeated violations lead to N red cards" subtitle.
 *  - **actions**: full-width Success "I will not repeat again" CTA.
 *
 * ponytail: Figma red-highlights the `N red cards` portion of the subtitle;
 * SnabbitText is plain-string only — flag for DS to add AnnotatedString overload.
 */
@Composable
fun WaiverSheet(
    redCardCount: Int,
    strings: HomeStrings,
    onAcknowledge: () -> Unit,
) {
    AttendanceSheetShell(
        header = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
            ) {
                WarningPill(text = strings.waiverWarningPill)
                RedCardClusterPlaceholder(count = redCardCount.coerceIn(1, 5), faded = true)
            }
        },
        title = strings.waiverTitle,
        content = {
            SheetSubtitle(
                strings.waiverSubtitleTemplate.replace("{count}", redCardCount.toString()),
            )
        },
        actions = {
            SnabbitButton(
                text = strings.waiverCta,
                onClick = onAcknowledge,
                style = SnabbitButtonStyle.Success,
                size = SnabbitButtonSize.L,
                fullWidth = true,
                modifier = Modifier.fillMaxWidth(),
            )
        },
    )
}

@Composable
private fun WarningPill(text: String) {
    Row(
        modifier = Modifier
            .background(SnabbitTheme.colors.bgWarningStrong, RoundedCornerShape(SnabbitTheme.borderRadius.lg))
            .padding(horizontal = SnabbitTheme.spacing.componentPaddingSm, vertical = SnabbitTheme.spacing.`1`),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs),
    ) {
        SnabbitText(
            text = text,
            variant = SnabbitTextVariant.BodyMd,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textOnWarning,
        )
    }
}
