package com.snabbit.runner.shared.features.home.presentation.ui.sheets

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.gamification.domain.model.CtaOverride
import com.snabbit.runner.shared.features.gamification.presentation.ui.CtaBadgeChip
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.ui.AttendanceButtonRow
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.calendar_illustration
import com.snabbit.runner.shared.resources.emergency_logout_bg
import org.jetbrains.compose.resources.painterResource

/**
 * FALSE_ATTENDANCE red-card cluster penalty chrome for the change-attendance
 * sheet — the decoded `sheet_warnings[FALSE_ATTENDANCE]` folded into what the
 * sheet needs to render Dart's `showPenaltyChrome` branch:
 *  - [redCardCount] → cluster size (Dart `ctaMap[mark_absent].redCards ?? 3`).
 *  - [absentCta] / [presentCta] → the inline CTA badge chips on each button
 *    (Dart `ctaMap[mark_absent]` on Absent, `ctaMap[go_back]` on Present).
 *
 * Non-null instance = penalty chrome (shimmer bg + red cards + chips, no date
 * box); null = the plain calendar sheet. Built host-side (`HomeTabContent`)
 * only when a FALSE_ATTENDANCE warning is present, mirroring Dart's
 * `showPenaltyChrome = hasNudges`.
 */
data class ChangeAttendancePenalty(
    val redCardCount: Int,
    val absentCta: CtaOverride? = null,
    val presentCta: CtaOverride? = null,
)

/**
 * "Are you sure you want to change attendance?" sheet — Dart port of
 * `lib/widgets/attendance_flow/attendance_change_sheet.dart`.
 *
 * Two chromes, chosen by [penalty] (Dart's `showPenaltyChrome`):
 *  - **penalty ≠ null** — Figma DS 76-38777: nudges shimmer background
 *    ([Res.drawable.emergency_logout_bg], the same asset the emergency-logout
 *    sheet uses), overlapping red-card cluster, no date box, and Absent/Present
 *    buttons carrying gamification CTA badge chips.
 *  - **penalty == null** — Figma DS 318-44202: plain calendar illustration +
 *    gray-100 dated box + icon'd Absent/Present row.
 *
 * The period-leave variant of Flutter's `AttendanceChangeSheet` still lands
 * separately.
 */
@Composable
fun ChangeAttendanceConfirmSheet(
    dateLabel: String,
    shiftWindowLabel: String,
    strings: HomeStrings,
    onConfirmAbsent: () -> Unit,
    onConfirmPresent: () -> Unit,
    loadingAbsent: Boolean = false,
    loadingPresent: Boolean = false,
    penalty: ChangeAttendancePenalty? = null,
) {
    if (penalty != null) {
        AttendanceSheetShell(
            background = {
                // Full-bleed nudges shimmer, 185dp — the shared asset the
                // emergency-logout sheet paints (Dart `kNudgesBottomSheetBackgroundUrl`).
                Image(
                    painter = painterResource(Res.drawable.emergency_logout_bg),
                    contentDescription = null,
                    modifier = Modifier.fillMaxWidth().height(185.dp).align(Alignment.TopCenter),
                    contentScale = ContentScale.Crop,
                )
            },
            header = { RedCardClusterPlaceholder(count = penalty.redCardCount, faded = false) },
            title = strings.changeAttendanceConfirmTitle,
            extraTopPadding = 8.dp,
            actions = {
                PenaltyAttendanceButtons(
                    absentLabel = strings.sheetAbsentCta,
                    presentLabel = strings.sheetPresentCta,
                    absentCta = penalty.absentCta,
                    presentCta = penalty.presentCta,
                    onAbsent = onConfirmAbsent,
                    onPresent = onConfirmPresent,
                    absentLoading = loadingAbsent,
                    presentLoading = loadingPresent,
                )
            },
        )
    } else {
        AttendanceSheetShell(
            header = { SheetIllustration(Res.drawable.calendar_illustration) },
            title = strings.changeAttendanceConfirmTitle,
            content = { SheetDateBox(dateLabel = dateLabel, shiftWindowLabel = shiftWindowLabel) },
            actions = {
                AttendanceButtonRow(
                    absentLabel = strings.sheetAbsentCta,
                    presentLabel = strings.sheetPresentCta,
                    onAbsent = onConfirmAbsent,
                    onPresent = onConfirmPresent,
                    absentLoading = loadingAbsent,
                    presentLoading = loadingPresent,
                )
            },
        )
    }
}

/**
 * Absent / Present row for the penalty chrome — no leading circle icons (Dart's
 * penalty buttons drop them) and an inline gamification badge chip after each
 * label (Dart `attendanceSheetCtaButtonChild`). [CtaBadgeChip] renders nothing
 * when its override carries neither a coin nor a red-card badge.
 */
@Composable
private fun PenaltyAttendanceButtons(
    absentLabel: String,
    presentLabel: String,
    absentCta: CtaOverride?,
    presentCta: CtaOverride?,
    onAbsent: () -> Unit,
    onPresent: () -> Unit,
    absentLoading: Boolean,
    presentLoading: Boolean,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
    ) {
        PenaltyCtaButton(
            label = absentLabel,
            cta = absentCta,
            containerColor = SnabbitColorsLight.red600,
            onClick = onAbsent,
            loading = absentLoading,
            enabled = !presentLoading,
        )
        PenaltyCtaButton(
            label = presentLabel,
            cta = presentCta,
            containerColor = SnabbitColorsLight.green600,
            onClick = onPresent,
            loading = presentLoading,
            enabled = !absentLoading,
        )
    }
}

/**
 * One penalty CTA button — Figma DS 76-38777 (red-600 / green-600, rounded-12,
 * 56dp, white 16sp SemiBold label + inline [CtaBadgeChip]).
 *
 * Hand-rolled on purpose: `SnabbitButton` exposes only `text` + icon slots, and
 * routing the pill through its `trailingIcon` slot size-clamps it (the icon and
 * count overlap). Dart hits the same wall and builds the child as a plain
 * `Row[label + chip]` inside an `ElevatedButton` — this mirrors that.
 * ponytail: delete the day the DS ships an inline-content / badge-slot button.
 */
@Composable
private fun RowScope.PenaltyCtaButton(
    label: String,
    cta: CtaOverride?,
    containerColor: Color,
    onClick: () -> Unit,
    loading: Boolean,
    enabled: Boolean,
) {
    Box(
        modifier = Modifier
            .weight(1f)
            .height(56.dp)
            .clip(RoundedCornerShape(SnabbitTheme.borderRadius.lg))
            .background(containerColor)
            .clickable(enabled = enabled && !loading, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            CircularProgressIndicator(
                color = SnabbitColorsLight.whiteDefault,
                strokeWidth = 2.dp,
                modifier = Modifier.size(20.dp),
            )
        } else {
            Row(
                horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SnabbitText(
                    text = label,
                    variant = SnabbitTextVariant.BodyMd,
                    fontWeight = FontWeight.SemiBold,
                    color = SnabbitColorsLight.whiteDefault,
                )
                if (cta != null) CtaBadgeChip(cta = cta)
            }
        }
    }
}
