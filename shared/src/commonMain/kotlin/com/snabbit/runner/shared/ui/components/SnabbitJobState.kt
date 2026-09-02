package com.snabbit.runner.shared.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme

/**
 * SnabbitJobState — Job lifecycle status indicator (Expert App component).
 *
 * App-specific composition built on DS primitives (`SnabbitIcon` registry +
 * `SnabbitText`). Figma: "Job States" set (New job / Check In / Job in
 * Progress / Job Completed).
 *
 * A centered row of a status glyph + a label. By default the glyph is 20.dp
 * and the label is Outfit SemiBold 20.sp/28 in `text.primary`; only the glyph
 * (and its tint) changes per status — [SnabbitJobStateStatus.Completed] uses
 * success green, every other state uses the dark icon color. Glyph size
 * ([iconSize]) and label typography are independently customizable; pass
 * [icon] to override the glyph entirely.
 */

enum class SnabbitJobStateStatus { NewJob, CheckIn, InProgress, Completed }

@Composable
fun SnabbitJobState(
    label: String,
    status: SnabbitJobStateStatus,
    modifier: Modifier = Modifier,
    /** Size of the default status glyph. Ignored when [icon] is supplied. */
    iconSize: Dp = 20.dp,
    /** Label text size. */
    fontSize: TextUnit = 20.sp,
    /** Label line height. */
    lineHeight: TextUnit = 28.sp,
    /** Label font weight. */
    fontWeight: FontWeight = FontWeight.SemiBold,
    /** Label color. Falls back to `text.primary` when [Color.Unspecified]. */
    textColor: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Unspecified,
    /** Overrides the default per-status glyph (you control its size/tint). */
    icon: (@Composable () -> Unit)? = null,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            icon()
        } else {
            SnabbitIcon(
                name = defaultIconName(status),
                size = iconSize,
                color = if (status == SnabbitJobStateStatus.Completed) {
                    SnabbitTheme.colors.textSuccess
                } else {
                    SnabbitTheme.colors.iconPrimary
                },
                contentDescription = null,
            )
        }
        SnabbitText(
            text = label,
            color = if (textColor != androidx.compose.ui.graphics.Color.Unspecified) textColor else SnabbitTheme.colors.textPrimary,
            fontSize = fontSize,
            lineHeight = lineHeight,
            fontWeight = fontWeight,
        )
    }
}

private fun defaultIconName(status: SnabbitJobStateStatus): SnabbitIconName = when (status) {
    SnabbitJobStateStatus.NewJob -> SnabbitIconName.SprayBottle
    SnabbitJobStateStatus.CheckIn -> SnabbitIconName.CheckCircle
    SnabbitJobStateStatus.InProgress -> SnabbitIconName.ClockFilled
    SnabbitJobStateStatus.Completed -> SnabbitIconName.CheckCircle
}

// ── Previews ──────────────────────────────────────────────────────────

@Preview
@Composable
private fun PreviewSnabbitJobStates() {
    SnabbitTheme {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SnabbitJobState(label = "New Job", status = SnabbitJobStateStatus.NewJob)
            SnabbitJobState(label = "Check In", status = SnabbitJobStateStatus.CheckIn)
            SnabbitJobState(label = "Job In Progress", status = SnabbitJobStateStatus.InProgress)
            SnabbitJobState(label = "Job Completed", status = SnabbitJobStateStatus.Completed)
        }
    }
}
