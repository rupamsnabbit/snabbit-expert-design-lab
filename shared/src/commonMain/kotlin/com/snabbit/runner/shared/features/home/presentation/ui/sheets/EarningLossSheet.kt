package com.snabbit.runner.shared.features.home.presentation.ui.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitRichSpan
import com.snabbit.design.atoms.SnabbitRichText
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.ui.AttendanceButtonRow
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.money_jar
import com.snabbit.design.theme.SnabbitTheme

/**
 * EarningLoss confirmation sheet — Figma DS 76:38737 (variant of 1596:11048).
 * Dart port of `lib/widgets/attendance_flow/earning_loss_bottom_sheet.dart`.
 *
 * Layout matches the Figma exactly (gaps are intentional and not uniform, so
 * this sheet does not use [AttendanceSheetShell] — the shell stays for the
 * other three sheets which do follow the uniform 16dp rhythm):
 *
 *  outer Column (gap = 36dp)
 *    inner Column (gap = 16dp)
 *      illustration (100dp money jar)
 *      title block Column (gap = 4dp)
 *        title — Heading2 Bold, "You can [earn ₹X] tomorrow" with the
 *                middle phrase in green-600 (#059669)
 *        subtitle — Heading3 Medium, gray-700 "Change your attendance?"
 *    AttendanceButtonRow — Destructive Absent / Success Present
 *
 * No-amount fallback renders a single-line plain title (no green highlight)
 * and skips the subtitle row.
 */
@Composable
fun EarningLossSheet(
    amount: String?,
    strings: HomeStrings,
    onMarkAbsent: () -> Unit,
    onMarkPresent: () -> Unit,
    loadingAbsent: Boolean = false,
    loadingPresent: Boolean = false,
) {
    // DS SnabbitBottomSheet gives a bare ColumnScope (no content padding) — pad the
    // root here (this sheet opts out of AttendanceSheetShell, so it can't inherit it).
    // Top gets +4 over the other three sides so the money-jar illustration isn't
    // crowded against the sheet's rounded edge (UAT).
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = SnabbitTheme.spacing.componentPaddingMd,
                end = SnabbitTheme.spacing.componentPaddingMd,
                bottom = SnabbitTheme.spacing.componentPaddingMd,
                top = SnabbitTheme.spacing.componentPaddingMd + 4.dp,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(36.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapLg),
        ) {
            SheetIllustration(Res.drawable.money_jar)
            TitleBlock(amount = amount, strings = strings)
        }
        AttendanceButtonRow(
            absentLabel = strings.sheetAbsentCta,
            presentLabel = strings.sheetPresentCta,
            onAbsent = onMarkAbsent,
            onPresent = onMarkPresent,
            absentLoading = loadingAbsent,
            presentLoading = loadingPresent,
        )
    }
}

@Composable
private fun TitleBlock(amount: String?, strings: HomeStrings) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs),
    ) {
        if (amount.isNullOrBlank()) {
            SnabbitText(
                text = strings.earningLossNoAmountTitle,
                variant = SnabbitTextVariant.Heading2,
                fontWeight = FontWeight.Bold,
                color = SnabbitTheme.colors.textPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            SnabbitRichText(
                spans = listOf(
                    SnabbitRichSpan(text = "${strings.earningLossTitlePrefix} ", style = SpanStyle()),
                    SnabbitRichSpan(
                        text = "${strings.earningLossTitleVerb} $amount ",
                        style = SpanStyle(color = SnabbitTheme.colors.textSuccess),
                    ),
                    SnabbitRichSpan(text = strings.earningLossTitleSuffix, style = SpanStyle()),
                ),
                modifier = Modifier.fillMaxWidth(),
                baseStyle = SnabbitTheme.typography.heading2.copy(fontWeight = FontWeight.Bold),
                color = SnabbitTheme.colors.textPrimary,
                textAlign = TextAlign.Center,
            )
            SnabbitText(
                text = strings.earningLossSubtitle,
                variant = SnabbitTextVariant.Heading3,
                fontWeight = FontWeight.Medium,
                color = SnabbitTheme.colors.textBody,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
