package com.snabbit.runner.shared.features.home.presentation.ui.sheets

import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource
import com.snabbit.design.theme.SnabbitTheme

/**
 * Shared shell for the attendance bottom sheets. Every attendance sheet in
 * this module renders the same column — illustration → bold title → optional
 * middle slot (subtitle / dated box / red-card cluster / period leave) →
 * actions footer — so this is the one place that shape lives.
 *
 * Slots stay composable lambdas (not data) so each caller is free to swap
 * the illustration for whatever shape Figma ships for it (image, pill, red
 * card cluster) without churning the shell signature.
 *
 *  - [background] optional full-bleed layer painted behind the column (the
 *    penalty variant's nudges shimmer, Dart's `Stack` bg image). Null → none.
 *  - [header] always renders first (illustration / pill / cluster).
 *  - [title] Heading2 bold, centered, full-width.
 *  - [content] optional middle band (subtitle, date box, period leave row).
 *  - [actions] the buttons row (single CTA or AttendanceButtonRow).
 *
 * Mirrors the Dart sheets' shape (Stack with optional bg image → Column with
 * illustration → title → content → buttons). Non-penalty sheets pass no
 * [background] and rely on the DS sheet host's gray-50 panel.
 */
@Composable
internal fun AttendanceSheetShell(
    header: @Composable () -> Unit,
    title: String,
    actions: @Composable () -> Unit,
    content: (@Composable () -> Unit)? = null,
    background: (@Composable BoxScope.() -> Unit)? = null,
    extraTopPadding: Dp = 0.dp,
) {
    Box(modifier = Modifier.fillMaxWidth()) {
        background?.invoke(this)
        // DS SnabbitBottomSheet gives a bare ColumnScope (no content padding), so
        // the shell owns the Figma panel padding (16 h / 24 v) for every attendance
        // sheet. [extraTopPadding] adds on top of it for sheets that need more headroom.
        Column(
            modifier = Modifier.fillMaxWidth()
                .padding(
                    horizontal = SnabbitTheme.spacing.componentPaddingMd,
                    vertical = SnabbitTheme.spacing.componentPaddingLg,
                )
                .padding(top = extraTopPadding),
            horizontalAlignment = Alignment.CenterHorizontally,
            // Figma: 36 between the illustration/title/content block and the actions.
            // ponytail: exact Figma gap with no matching DS spacing token (scale is 32/40).
            verticalArrangement = Arrangement.spacedBy(36.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                // Figma: 16 between the illustration and the title/content group.
                verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapLg),
            ) {
                header()
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    // Figma: 24 between the title and the content slot.
                    verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`7`),
                ) {
                    SnabbitText(
                        text = title,
                        variant = SnabbitTextVariant.Heading2,
                        fontWeight = FontWeight.Bold,
                        color = SnabbitTheme.colors.textPrimary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    content?.invoke()
                }
            }
            actions()
        }
    }
}

/** 100dp circular drawable — the default header for image-backed sheets. */
@Composable
internal fun SheetIllustration(drawable: DrawableResource, size: Dp = 100.dp) {
    SnabbitImage(
        painter = painterResource(drawable),
        contentDescription = null,
        modifier = Modifier.size(size),
        contentScale = ContentScale.Fit,
    )
}

/** Gray-100 inset box with caption date + Heading2 shift window. Same chrome
 *  as the Elevated card header strip on TomorrowProvisionalCard. */
@Composable
internal fun SheetDateBox(dateLabel: String, shiftWindowLabel: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(SnabbitTheme.colors.bgTertiary, RoundedCornerShape(SnabbitTheme.borderRadius.lg))
            // Figma: 16 h / 8 v — the box hugs its two centered lines.
            .padding(
                horizontal = SnabbitTheme.spacing.componentPaddingMd,
                vertical = SnabbitTheme.spacing.componentPaddingSm,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs),
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

/** Centered gray-500 subtitle — used under the title on the EarningLoss sheet. */
@Composable
internal fun SheetSubtitle(text: String) {
    SnabbitText(
        text = text,
        variant = SnabbitTextVariant.BodyMd,
        color = SnabbitTheme.colors.textSecondary,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
    )
}
