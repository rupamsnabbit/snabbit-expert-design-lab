package com.snabbit.runner.shared.features.shift.presentation.login
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.shift.presentation.login.ShiftLoginStrings

private const val SELFIE_GOOD_IMAGE_URL =
    "https://assets-expert.snabbit.com/shift-login/selfie_do.png"

/**
 * Each bad-example asset is a pre-composed *row* of don't examples (markers
 * baked in), not a single tile — so they stack vertically at their own
 * intrinsic aspect ratio, never square-cropped or laid side-by-side.
 */
private data class SelfieBadRow(val imageUrl: String, val aspectRatio: Float)
private val SELFIE_BAD_IMAGE_ROWS = listOf(
    SelfieBadRow("https://assets-expert.snabbit.com/shift-login/selfie_donts_1.png", 969f / 344f),
    SelfieBadRow("https://assets-expert.snabbit.com/shift-login/selfie_donts_2.png", 969f / 304f),
)

/**
 * Figma 76-44375 — intro bottom-sheet body.
 *
 * Title + good-example tile + caption + red-bordered "do not" rows + OK CTA.
 *
 * ponytail: bad-example section renders one full-width row per
 * [SELFIE_BAD_IMAGE_ROWS] entry (currently 2) — add more entries to grow it.
 */
@Composable
fun IntroSheet(
    strings: ShiftLoginStrings,
    onOk: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // DS SnabbitBottomSheet gives a bare ColumnScope (no content padding) — pad here.
    // Top is 24 (UAT: +8 over the other sides). Figma 3042:57741 actually specs 32;
    // 24 is the deliberate override.
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                start = SnabbitTheme.spacing.componentPaddingMd,
                end = SnabbitTheme.spacing.componentPaddingMd,
                bottom = SnabbitTheme.spacing.componentPaddingMd,
                top = SnabbitTheme.spacing.componentPaddingLg,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`7`),
    ) {
        SnabbitText(
            text = strings.introTitle,
            variant = SnabbitTextVariant.Heading2,
            color = SnabbitTheme.colors.textPrimary,
        )

        // Tile + caption are one visual group (Figma pairs them at a 6dp gap,
        // inside the column's 24dp section rhythm).
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            GoodExampleTile()

            SnabbitText(
                text = strings.introGoodCaption,
                variant = SnabbitTextVariant.Title,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textBody,
                textAlign = TextAlign.Center,
            )
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(SnabbitTheme.borderRadius.lg))
                // Figma 2678:53272 — red-50 fill (`bgError`) with a 1.5dp red-600
                // border (`textError`). `borderError` is red-500 and reads too light.
                .background(SnabbitTheme.colors.bgError)
                .border(
                    width = 1.5.dp,
                    color = SnabbitTheme.colors.textError,
                    shape = RoundedCornerShape(SnabbitTheme.borderRadius.lg),
                )
                .padding(SnabbitTheme.spacing.`4`),
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            SnabbitText(
                text = strings.introBadHeader,
                variant = SnabbitTextVariant.Title,
                color = SnabbitTheme.colors.textError,
            )
            BadExampleRows()
        }

        Spacer(Modifier.height(SnabbitTheme.spacing.componentGapXs))

        SnabbitButton(
            text = strings.introCta,
            onClick = onOk,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/**
 * Figma 3042:57745 — 140x152 photo at radius-md, with the 38dp success badge
 * straddling its top-right corner (3dp proud on both edges, per 3042:57754).
 *
 * The badge is a sibling of the clipped image, not a child: the image's own
 * `clip` would cut off anything hanging past the corner.
 */
@Composable
private fun GoodExampleTile() {
    Box(contentAlignment = Alignment.TopEnd) {
        SnabbitRemoteImage(
            model = SELFIE_GOOD_IMAGE_URL,
            contentDescription = null,
            modifier = Modifier
                .width(140.dp)
                .height(152.dp)
                .clip(RoundedCornerShape(SnabbitTheme.borderRadius.md)),
            contentScale = ContentScale.Crop,
        )
        // DS `CheckCircle` is the vendored pixel-exact Figma glyph — a filled disc
        // with the tick knocked out — so it carries the design's tick weight, which
        // the thinner Material `Check` can't. The white disc behind it is what the
        // knocked-out tick reads as. Green is `textSuccess` (#059669, the badge fill
        // in Figma), NOT `iconSuccess` (#10B981) — that mismatch was the UAT bug.
        Box(
            modifier = Modifier
                .offset(x = 3.dp, y = (-3).dp)
                .size(38.dp)
                .clip(CircleShape)
                .background(SnabbitTheme.colors.bgPrimary),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitIcon(
                name = SnabbitIconName.CheckCircle,
                size = 38.dp,
                color = SnabbitTheme.colors.textSuccess,
            )
        }
    }
}

@Composable
private fun BadExampleRows() {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
    ) {
        SELFIE_BAD_IMAGE_ROWS.forEach { row ->
            SnabbitRemoteImage(
                model = row.imageUrl,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(row.aspectRatio)
                    .clip(RoundedCornerShape(SnabbitTheme.borderRadius.md)),
                contentScale = ContentScale.FillWidth,
            )
        }
    }
}
