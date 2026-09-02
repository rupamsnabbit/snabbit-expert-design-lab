package com.snabbit.runner.shared.features.autoot.presentation

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitRichSpan
import com.snabbit.design.atoms.SnabbitRichText
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails
import com.snabbit.runner.shared.features.autoot.domain.model.ShiftDetails
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.auto_ot_chip_clock
import com.snabbit.runner.shared.resources.auto_ot_clock
import com.snabbit.runner.shared.resources.auto_ot_expired
import com.snabbit.runner.shared.resources.auto_ot_success_check
import com.snabbit.runner.shared.ui.icons.AppIcons
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Entry composable for the Auto-OT flow — a [SnabbitBottomSheet] whose body swaps by
 * [AutoOtUiState.step] (offer → confirm → loading → success | expired | failure). Renders
 * nothing when `step == null`. The caller (an always-composed overlay) owns visibility;
 * this stays DI-free (VM state in, intents out) so it previews/tests cleanly.
 *
 * Layout follows the new Figma ("Shift – Job Lifecycle DS"): offer 226:29568, confirm 2536:53272,
 * success 2536:53621, expired 2553:52485. The redesign has **no in-body decline button** — the
 * sheet ✕ is the only dismiss affordance (the VM routes an offer ✕ to the reject path).
 *
 * Loading is non-dismissible (no close / scrim / back) while the accept call is in flight.
 */
@Composable
fun AutoOtSheet(
    state: AutoOtUiState,
    onIntent: (AutoOtUiIntent) -> Unit,
    strings: AutoOtStrings = AutoOtStrings(),
) {
    val step = state.step ?: return
    val loading = step == AutoOtStep.Loading
    SnabbitBottomSheet(
        onDismissRequest = { onIntent(AutoOtUiIntent.Dismiss) },
        showCloseButton = !loading,
        draggable = false,
        dismissible = !loading,
    ) {
        when (step) {
            AutoOtStep.Offer -> AutoOtOfferContent(state.details, strings, onIntent)
            AutoOtStep.Confirm -> AutoOtConfirmContent(state.details, strings, onIntent)
            AutoOtStep.Loading -> AutoOtLoadingContent(strings)
            AutoOtStep.Success -> AutoOtSuccessContent(state.details, strings)
            AutoOtStep.Expired -> AutoOtExpiredContent(strings, onIntent)
            AutoOtStep.Failure -> AutoOtFailureContent(strings, onIntent)
        }
    }
}

/* ── Offer ───────────────────────────────────────────────────────────── */

@Composable
private fun AutoOtOfferContent(
    details: AutoOtDetails?,
    strings: AutoOtStrings,
    onIntent: (AutoOtUiIntent) -> Unit,
) {
    // Figma: 56dp between the content block and the Confirm CTA.
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(56.dp),
    ) {
        // Content block (Figma 226:29570 → gap-20 between clock, title and the receipt group).
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            AutoOtIllustration(Res.drawable.auto_ot_clock)
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                SnabbitText(
                    text = strings.offerTitlePrefix,
                    variant = SnabbitTextVariant.Heading2,
                    color = SnabbitTheme.colors.textPrimary,
                    textAlign = TextAlign.Center,
                )
                SnabbitText(
                    text = strings.offerTitleHighlight,
                    variant = SnabbitTextVariant.Heading2,
                    color = SnabbitTheme.colors.textBrand,
                    textAlign = TextAlign.Center,
                )
            }
            // Receipt group (Figma 226:29574 → gap-16): dashed rule, current-shift row, dashed rule,
            // then the "Select OT shift" sub-group. NOT a bordered card.
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                HorizontalDashedLine(Modifier.fillMaxWidth())
                // Row 226:29577 → py-4, chip-to-content gap-12, right padding 12; a dotted divider
                // splits the two clock-chip cells.
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .padding(end = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    AutoOtReceiptCell(
                        label = strings.currentShiftLabel,
                        value = formatTimeRange(details?.regularShift?.startTimeIso, details?.regularShift?.endTimeIso),
                        alignEnd = false,
                    )
                    VerticalDashedLine(height = 36.dp)
                    AutoOtReceiptCell(
                        label = strings.minGLabel,
                        value = formatOtRupees(details?.regularShift?.ming?.toInt()),
                        alignEnd = true,
                    )
                }
                HorizontalDashedLine(Modifier.fillMaxWidth())
                // "Select OT shift" sub-group (Figma 226:29597 → gap-24).
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                ) {
                    SnabbitText(
                        text = strings.selectOtShiftLabel,
                        variant = SnabbitTextVariant.BodyLg,
                        fontWeight = FontWeight.SemiBold,
                        color = SnabbitTheme.colors.textPrimary,
                        textAlign = TextAlign.Center,
                    )
                    AutoOtOfferOptionCard(details?.otShift, strings)
                }
            }
        }
        Column(modifier = Modifier.fillMaxWidth().navigationBarsPadding()) {
            SnabbitButton(
                text = strings.confirmOtCta,
                onClick = { onIntent(AutoOtUiIntent.Confirm) },
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
            )
        }
    }
}

/**
 * One cell of the current-shift receipt row: a pink clock chip + a [label]/[value] stack (Figma
 * label = Body-S/14 gray-500, value = 16px bold gray-900, 2dp apart, 12dp from the chip). Content-
 * sized so the parent `SpaceBetween` distributes the two cells + divider; the right cell ([alignEnd])
 * right-aligns its text, mirroring Figma 226:29587.
 */
@Composable
private fun AutoOtReceiptCell(
    label: String,
    value: String,
    alignEnd: Boolean,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ClockChip()
        Column(
            horizontalAlignment = if (alignEnd) Alignment.End else Alignment.Start,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            SnabbitText(label, variant = SnabbitTextVariant.Small, color = SnabbitTheme.colors.textSecondary)
            SnabbitText(
                value,
                variant = SnabbitTextVariant.BodyMd,
                fontWeight = FontWeight.Bold,
                color = SnabbitTheme.colors.textPrimary,
            )
        }
    }
}

/* ── Confirm ─────────────────────────────────────────────────────────── */

@Composable
private fun AutoOtConfirmContent(
    details: AutoOtDetails?,
    strings: AutoOtStrings,
    onIntent: (AutoOtUiIntent) -> Unit,
) {
    // Figma 2536:53272 — no illustration; left-aligned title; white card with a pink border and no
    // leading icon; uniform gap-24 (title → card → button).
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.Start,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        SnabbitText(
            text = strings.confirmTitle,
            variant = SnabbitTextVariant.Heading2,
            color = SnabbitTheme.colors.textPrimary,
            textAlign = TextAlign.Start,
            modifier = Modifier.fillMaxWidth(),
        )
        AutoOtBorderedCard(borderColor = SnabbitTheme.colors.borderBrand) {
            AutoOtShiftRow(
                leading = null,
                leadingLabel = { AutoOtRowLabel(strings.newShiftTimingLabel) },
                timeRange = formatTimeRange(details?.otShift?.startTimeIso, details?.otShift?.endTimeIso),
                trailingLabel = strings.newMinGLabel,
                trailingValue = formatOtRupees(details?.otShift?.ming?.toInt()),
            )
        }
        Column(modifier = Modifier.fillMaxWidth().navigationBarsPadding()) {
            SnabbitButton(
                text = strings.confirmCta,
                onClick = { onIntent(AutoOtUiIntent.Submit) },
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
            )
        }
    }
}

/* ── Loading ─────────────────────────────────────────────────────────── */

@Composable
private fun AutoOtLoadingContent(strings: AutoOtStrings) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp).navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapLg),
    ) {
        CircularProgressIndicator(color = SnabbitTheme.colors.iconBrand)
        SnabbitText(
            text = strings.loadingLabel,
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
        )
    }
}

/* ── Success ─────────────────────────────────────────────────────────── */

@Composable
private fun AutoOtSuccessContent(
    details: AutoOtDetails?,
    strings: AutoOtStrings,
) {
    // Figma 2536:53621 — green check disc (60dp) + centered title + white card with a GREEN border
    // and green check icon. The "Go back" CTA is dropped: the accept already ran + refreshed, so the
    // sheet ✕ dismisses this terminal state (a bottom button would be redundant).
    Column(
        modifier = Modifier.fillMaxWidth().navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        AutoOtIllustration(Res.drawable.auto_ot_success_check, sizeDp = 60.dp)
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            SnabbitText(
                text = strings.successTitle,
                variant = SnabbitTextVariant.Heading2,
                color = SnabbitTheme.colors.textPrimary,
                textAlign = TextAlign.Center,
            )
            SnabbitText(
                text = strings.successSubtitle,
                variant = SnabbitTextVariant.Heading2,
                color = SnabbitTheme.colors.textPrimary,
                textAlign = TextAlign.Center,
            )
        }
        AutoOtBorderedCard(borderColor = SnabbitTheme.colors.iconSuccess) {
            AutoOtShiftRow(
                leading = {
                    Image(
                        painter = painterResource(Res.drawable.auto_ot_success_check),
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                    )
                },
                leadingLabel = { AutoOtRowLabel(strings.newShiftTimingLabel) },
                timeRange = formatTimeRange(details?.otShift?.startTimeIso, details?.otShift?.endTimeIso),
                trailingLabel = strings.newMinGLabel,
                trailingValue = formatOtRupees(details?.otShift?.ming?.toInt()),
            )
        }
    }
}

/* ── Expired ─────────────────────────────────────────────────────────── */

@Composable
private fun AutoOtExpiredContent(
    strings: AutoOtStrings,
    onIntent: (AutoOtUiIntent) -> Unit,
) {
    // Figma 2553:52486 — large clock + red "!" badge (165dp); gap-12 illustration→title, gap-32 to CTA.
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(32.dp),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            AutoOtIllustration(Res.drawable.auto_ot_expired, sizeDp = 165.dp)
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                SnabbitText(
                    text = strings.expiredTitle,
                    variant = SnabbitTextVariant.Heading2,
                    color = SnabbitTheme.colors.textPrimary,
                    textAlign = TextAlign.Center,
                )
                SnabbitText(
                    text = strings.expiredSubtitle,
                    variant = SnabbitTextVariant.Heading2,
                    color = SnabbitTheme.colors.textPrimary,
                    textAlign = TextAlign.Center,
                )
            }
        }
        Column(modifier = Modifier.fillMaxWidth().navigationBarsPadding()) {
            SnabbitButton(
                text = strings.expiredCta,
                onClick = { onIntent(AutoOtUiIntent.Acknowledge) },
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
            )
        }
    }
}

/* ── Failure ─────────────────────────────────────────────────────────── */

@Composable
private fun AutoOtFailureContent(
    strings: AutoOtStrings,
    onIntent: (AutoOtUiIntent) -> Unit,
) {
    // Compact error state, spaced consistently with the Expired sheet (icon+text block → gap-32 →
    // CTA; icon → gap-12 → text; title → gap-4 → subtitle). Uses a red alert disc + "Try again"
    // rather than the full-screen GeneralErrorState, whose pinned footer stretches a content sheet.
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(32.dp),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(SnabbitTheme.colors.bgErrorSubtle),
                contentAlignment = Alignment.Center,
            ) {
                SnabbitIcon(
                    imageVector = AppIcons.AlertCircle,
                    size = 32.dp,
                    color = SnabbitTheme.colors.iconError,
                )
            }
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                SnabbitText(
                    text = strings.failureTitle,
                    variant = SnabbitTextVariant.Heading2,
                    color = SnabbitTheme.colors.textPrimary,
                    textAlign = TextAlign.Center,
                )
                SnabbitText(
                    text = strings.failureSubtitle,
                    variant = SnabbitTextVariant.BodyMd,
                    color = SnabbitTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        Column(modifier = Modifier.fillMaxWidth().navigationBarsPadding()) {
            SnabbitButton(
                text = strings.retryCta,
                onClick = { onIntent(AutoOtUiIntent.Retry) },
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
            )
        }
    }
}

/* ── Shared sub-composables ──────────────────────────────────────────── */

/**
 * "Selection Card with Description" (Figma) — a rounded card with a colored 2px border, an optional
 * tinted fill, and 16dp padding. Used for the offer OT option (pink border + pink-50 tint), confirm
 * (pink border, no fill) and success (green border, no fill). Built from tokens because no DS card
 * variant exposes an arbitrary border colour / tint pairing.
 */
@Composable
private fun AutoOtBorderedCard(
    borderColor: Color,
    fillColor: Color = Color.Transparent,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.lg)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(fillColor)
            .border(SnabbitTheme.borderWidth.thick, borderColor, shape)
            .padding(SnabbitTheme.spacing.componentPaddingMd),
        content = content,
    )
}

/** Two-column summary row: [optional leading icon + label slot + time] | [trailing label + value].
 *  [leadingLabel] is a slot so the offer card can emphasise "N hours" mid-string via SnabbitRichText
 *  (SnabbitText is plain-string only). */
@Composable
private fun AutoOtShiftRow(
    leading: (@Composable () -> Unit)?,
    leadingLabel: @Composable () -> Unit,
    timeRange: String,
    trailingLabel: String,
    trailingValue: String,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            leading?.invoke()
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                leadingLabel()
                SnabbitText(
                    timeRange,
                    variant = SnabbitTextVariant.BodyLg,
                    fontWeight = FontWeight.SemiBold,
                    color = SnabbitTheme.colors.textPrimary,
                )
            }
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            SnabbitText(trailingLabel, variant = SnabbitTextVariant.Small, color = SnabbitTheme.colors.textSecondary)
            SnabbitText(
                trailingValue,
                variant = SnabbitTextVariant.BodyMd,
                fontWeight = FontWeight.Bold,
                color = SnabbitTheme.colors.textPrimary,
            )
        }
    }
}

/** Plain 14px gray-500 row label (confirm / success cards). */
@Composable
private fun AutoOtRowLabel(text: String) {
    SnabbitText(text, variant = SnabbitTextVariant.Small, color = SnabbitTheme.colors.textSecondary)
}

/** "Work {n} hours extra" (14px gray-500) with the "{n} hours" segment emphasised (Figma 226:29605),
 *  via the DS [SnabbitRichText] rather than a plain SnabbitText. */
@Composable
private fun WorkExtraLabel(hours: Int?, strings: AutoOtStrings) {
    SnabbitRichText(
        spans = listOf(
            SnabbitRichSpan(text = strings.workExtraPrefix, style = SpanStyle()),
            SnabbitRichSpan(text = strings.workExtraHours(hours), style = SpanStyle(fontWeight = FontWeight.SemiBold)),
            SnabbitRichSpan(text = strings.workExtraSuffix, style = SpanStyle()),
        ),
        baseStyle = SnabbitTheme.typography.small.copy(fontWeight = FontWeight.Medium),
        color = SnabbitTheme.colors.textSecondary,
    )
}

/** The OT option card — "Work N hours extra" + timing + new MinG (Figma 226:29601: pink-50 tint +
 *  pink border). No "Most preferred" badge — the backend has no field to rank a single OT option,
 *  so (per Flutter) we don't show it. */
@Composable
private fun AutoOtOfferOptionCard(shift: ShiftDetails?, strings: AutoOtStrings) {
    AutoOtBorderedCard(
        borderColor = SnabbitTheme.colors.borderBrand,
        fillColor = SnabbitTheme.colors.bgBrandSubtle,
    ) {
        AutoOtShiftRow(
            leading = null,
            leadingLabel = { WorkExtraLabel(shift?.durationHours, strings) },
            timeRange = formatTimeRange(shift?.startTimeIso, shift?.endTimeIso),
            trailingLabel = strings.newMinGLabel,
            trailingValue = formatOtRupees(shift?.ming?.toInt()),
        )
    }
}

/** The pink clock chip in the current-shift receipt row: a 36dp pink-50 disc holding the Figma
 *  "Time-Clock-Circle" outline glyph (16dp), not the filled [AppIcons.Clock]. */
@Composable
private fun ClockChip() {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(CircleShape)
            .background(SnabbitTheme.colors.bgBrandSubtle),
        contentAlignment = Alignment.Center,
    ) {
        Image(
            painter = painterResource(Res.drawable.auto_ot_chip_clock),
            contentDescription = null,
            modifier = Modifier.size(16.dp),
        )
    }
}

/** Figma dashed rule (nodes "Line 1"/"Line 2"): a 1.5dp gray-200 line with a 4/4 dash pattern.
 *  Both the horizontal receipt rules and the vertical cell divider use this so they read identically
 *  (the DS `SnabbitDivider(Dotted)` uses a different, denser pattern). */
@Composable
private fun HorizontalDashedLine(modifier: Modifier = Modifier) {
    val color = SnabbitTheme.colors.borderDefault
    Canvas(modifier = modifier.fillMaxWidth().height(1.5.dp)) {
        val dash = 4.dp.toPx()
        drawLine(
            color = color,
            start = Offset(0f, size.height / 2f),
            end = Offset(size.width, size.height / 2f),
            strokeWidth = size.height,
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(dash, dash), 0f),
        )
    }
}

@Composable
private fun VerticalDashedLine(height: Dp) {
    val color = SnabbitTheme.colors.borderDefault
    Canvas(modifier = Modifier.height(height).width(1.5.dp)) {
        val dash = 4.dp.toPx()
        drawLine(
            color = color,
            start = Offset(size.width / 2f, 0f),
            end = Offset(size.width / 2f, size.height),
            strokeWidth = size.width,
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(dash, dash), 0f),
        )
    }
}

/**
 * The circular Auto-OT artwork — Figma vectors converted to `composeResources/drawable` vector-XML
 * (SVG can't be decoded on Android at runtime). Offer/confirm → clock + green "+"; success → green
 * check disc; expired → clock + red "!".
 */
@Composable
private fun AutoOtIllustration(resource: DrawableResource, sizeDp: Dp = 106.dp) {
    Image(
        painter = painterResource(resource),
        contentDescription = null,
        modifier = Modifier.size(sizeDp),
    )
}

/* ── Preview ─────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewAutoOtOffer() {
    val details = AutoOtDetails(
        requestId = 1,
        otType = com.snabbit.runner.shared.features.autoot.domain.model.OtType.EndOt,
        regularShift = ShiftDetails("2026-02-07T08:00:00+05:30", "2026-02-07T17:00:00+05:30", 600.0, null),
        otShift = ShiftDetails("2026-02-07T08:00:00+05:30", "2026-02-07T19:00:00+05:30", 750.0, 2),
        expiryDurationMinutes = 5,
        status = null,
    )
    SnabbitTheme {
        Box(
            modifier = Modifier.fillMaxWidth().background(SnabbitTheme.colors.bgPrimary).padding(16.dp),
        ) {
            AutoOtOfferContent(details, AutoOtStrings(), onIntent = {})
        }
    }
}
