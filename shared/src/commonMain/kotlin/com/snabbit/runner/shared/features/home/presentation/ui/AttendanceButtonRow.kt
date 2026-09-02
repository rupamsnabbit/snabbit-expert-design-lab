package com.snabbit.runner.shared.features.home.presentation.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.runner.shared.features.home.presentation.ui.cards.AbsentCircleIcon
import com.snabbit.runner.shared.features.home.presentation.ui.cards.PresentCircleIcon
import com.snabbit.design.theme.SnabbitTheme

/**
 * Paired Absent / Present buttons — the recurring attendance CTA row.
 *
 * Same shape across TomorrowProvisionalCard (Figma 76-35279),
 * EarningLossSheet (1596:11048), MarkTomorrowAttendanceSheet (1583:6506),
 * and ChangeAttendanceConfirmSheet (1596:11119):
 *  - Two SnabbitButton Size L (56dp), full-width, weight(1f) each.
 *  - Absent = Destructive (red, white circled-X leading icon).
 *  - Present = Success (green, white circled-check leading icon).
 *  - 12dp gap between them.
 *
 * Labels are passed in so card-side call sites can read
 * `tomorrowAbsentCta`/`tomorrowPresentCta` while sheet-side call sites
 * read `sheetAbsentCta`/`sheetPresentCta`. The string values are
 * currently identical but live under different keys so they can drift
 * (e.g. translation differences) without coupling.
 */
@Composable
fun AttendanceButtonRow(
    absentLabel: String,
    presentLabel: String,
    onAbsent: () -> Unit,
    onPresent: () -> Unit,
    modifier: Modifier = Modifier,
    /** True when the Absent button's action is in flight — shows the inline
     *  spinner and disables both buttons (single-flight). */
    absentLoading: Boolean = false,
    /** Mirror of [absentLoading] for Present. */
    presentLoading: Boolean = false,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
    ) {
        SnabbitButton(
            text = absentLabel,
            onClick = onAbsent,
            style = SnabbitButtonStyle.Destructive,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            enabled = !presentLoading,
            loading = absentLoading,
            leadingIcon = {
                SnabbitIcon(imageVector = AbsentCircleIcon, size = 20.dp, color = SnabbitTheme.colors.textInverse)
            },
            modifier = Modifier.weight(1f),
        )
        SnabbitButton(
            text = presentLabel,
            onClick = onPresent,
            style = SnabbitButtonStyle.Success,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            enabled = !absentLoading,
            loading = presentLoading,
            leadingIcon = {
                SnabbitIcon(imageVector = PresentCircleIcon, size = 20.dp, color = SnabbitTheme.colors.textInverse)
            },
            modifier = Modifier.weight(1f),
        )
    }
}
