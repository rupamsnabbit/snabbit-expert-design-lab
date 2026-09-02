package com.snabbit.runner.shared.features.shift.presentation.emergencylogout
import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.period_leave_drop
import org.jetbrains.compose.resources.painterResource

/**
 * Gray-pill row with the period-leave checkbox (Figma 222:43283 — "Period
 * Leave (N Available)"). Hand-rolled rather than using `SnabbitSelectionCard`
 * because that molecule forces the checkbox on the LEFT — Figma puts the
 * affordance (droplet icon) on the left and the checkbox on the RIGHT.
 *
 * The Figma droplet PNG (`https://assets-expert.snabbit.com/period_leave/period_leave_drop.png`)
 * is bundled in `composeResources/` as `period_leave_drop` and rendered via
 * `SnabbitImage(painterResource)`.
 */
@Composable
fun PeriodLeaveRow(
    checked: Boolean,
    availableCount: Int,
    titleTemplate: String,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.lg)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(SnabbitTheme.colors.bgSecondary, shape)
            .clickable { onCheckedChange(!checked) }
            .padding(horizontal = SnabbitTheme.spacing.`4`, vertical = SnabbitTheme.spacing.`4`),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(
            modifier = Modifier.padding(end = SnabbitTheme.spacing.`4`),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
        ) {
            // Bundled period-leave drop icon — mirrors the Dart-side asset
            // (`https://assets-expert.snabbit.com/period_leave/period_leave_drop.png`).
            SnabbitImage(
                painter = painterResource(Res.drawable.period_leave_drop),
                contentDescription = null,
                modifier = Modifier.width(15.dp).height(18.dp),
            )
            SnabbitText(
                text = titleTemplate.replace("{count}", availableCount.toString()),
                // Figma 222:43283 — Body-M/16-Medium (Outfit Medium 16/24),
                // gray-900. BodyLg alone renders Regular — the QA-reported
                // wrong font on this row (ECPO-753 reopen item 2).
                variant = SnabbitTextVariant.BodyLg,
                fontWeight = FontWeight.Medium,
                color = SnabbitTheme.colors.textPrimary,
            )
        }
        CheckboxBox(checked = checked)
    }
}

/**
 * Square checkbox visual — filled gray-900 with a check glyph when checked,
 * gray-300 stroke on white when unchecked. Mirrors the Figma 222:43283
 * checkbox treatment. Hand-drawn because the DS atom isn't in scope here.
 */
@Composable
private fun CheckboxBox(checked: Boolean) {
    if (checked) {
        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(RoundedCornerShape(SnabbitTheme.borderRadius.sm))
                .background(SnabbitTheme.colors.bgInverse),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitIcon(
                name = SnabbitIconName.Check,
                size = 14.dp,
                color = SnabbitTheme.colors.textInverse,
            )
        }
    } else {
        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(RoundedCornerShape(SnabbitTheme.borderRadius.sm))
                .border(width = SnabbitTheme.borderWidth.thicker, color = SnabbitColorsLight.gray300, shape = RoundedCornerShape(SnabbitTheme.borderRadius.sm)),
        )
    }
}
