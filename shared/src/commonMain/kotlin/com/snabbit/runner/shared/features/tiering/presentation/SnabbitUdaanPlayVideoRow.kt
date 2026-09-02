package com.snabbit.runner.shared.features.tiering.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.designsystem.TierColors

/**
 * Post-intro "Snabbit Udaan" row with a trailing **Play video** CTA — the
 * counterpart to [SnabbitUdaanBanner] that takes its place once the runner has
 * viewed the tier intro (`hasViewedIntro`). The host renders it in the same slot
 * the banner used, for a service-1, non-suspended runner above BASE (gated via
 * `TieringUiState.showUdaanPlayVideoRow`); tapping **Play video** re-opens the
 * tiers intro webview so the runner can re-watch it.
 *
 * Mirrors the Flutter `SnabbitUdaanPlayVideoRow` (same behaviour, nav only — no
 * impression analytics). The UI is the Figma card variant: a white
 * [SnabbitTheme.borderRadius] `lg` (12dp) card with the title on the left and a
 * dark [SnabbitButtonSize.XS] pill on the right (Figma 32dp height / 6dp radius /
 * 12sp-Medium). Colours are [TierColors] tokens (Flutter `AppColors` parity).
 */
@Composable
fun SnabbitUdaanPlayVideoRow(
    visible: Boolean,
    onPlayVideo: () -> Unit,
    modifier: Modifier = Modifier,
    strings: TieringStrings = rememberTieringStrings(),
) {
    if (!visible) return

    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.lg)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            // Figma: white #FFFFFF card (deliberately differs from Flutter's gray play-video bg).
            .background(TierColors.udaanPlayVideoBg)
            // Figma frame padding: 12dp vertical / 16dp horizontal.
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SnabbitText(
            text = strings.playVideoTitle,
            modifier = Modifier.weight(1f),
            // Figma Body-M/16-Medium (matches the SnabbitUdaanBanner title sizing).
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            // Figma #374151 (Flutter AppColors.udaanPlayVideoTitle parity).
            color = TierColors.udaanPlayVideoTitle,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.width(8.dp))
        SnabbitButton(
            text = strings.playVideoCta,
            onClick = onPlayVideo,
            style = SnabbitButtonStyle.Primary,
            // XS = 32dp height, 6dp radius, 12sp Medium — the exact Figma pill dimensions.
            size = SnabbitButtonSize.XS,
            // Figma: dark #1F2937 pill, white label (shared with the banner's CTA).
            containerColor = TierColors.udaanButtonBg,
            contentColor = TierColors.onAccent,
        )
    }
}
