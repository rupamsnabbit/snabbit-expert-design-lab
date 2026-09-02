package com.snabbit.runner.shared.features.tiering.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.designsystem.TierColors

/**
 * "Introducing Snabbit Udaan" intro banner. Renders only when [visible] (the
 * runner hasn't viewed the intro); tapping Accept opens the Tiers home webview.
 * [showHeaderImage] adds the hero header above the copy. Mirrors the Flutter
 * `SnabbitUdaanBanner`; colours are DS-token placeholders.
 *
 * [onShown] fires the impression once per appearance (keyed [LaunchedEffect]).
 */
@Composable
fun SnabbitUdaanBanner(
    visible: Boolean,
    onShown: () -> Unit,
    onAccept: () -> Unit,
    modifier: Modifier = Modifier,
    showHeaderImage: Boolean = true,
    strings: TieringStrings = rememberTieringStrings(),
) {
    if (!visible) return
    LaunchedEffect(Unit) { onShown() }

    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            // Figma: 1px #F9AECF outer border (Flutter AppColors.udaanBannerBorder parity).
            .border(SnabbitTheme.borderWidth.thin, TierColors.udaanBannerBorder, shape),
    ) {
        if (showHeaderImage) {
            SnabbitRemoteImage(
                model = TierAssets.UDAAN_BANNER_HEADER_URL,
                contentDescription = null,
                modifier = Modifier.fillMaxWidth(),
                contentScale = ContentScale.FillWidth,
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                // Figma: #FEF1F7 footer background behind the copy + CTA.
                .background(TierColors.udaanBannerBg)
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                SnabbitText(
                    text = strings.bannerTitle,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    // Figma #670632 (Flutter AppColors.udaanBannerTitle parity).
                    color = TierColors.udaanBannerTitle,
                )
                SnabbitText(
                    text = strings.bannerSubtitle,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    // Figma #4B5563 (Flutter AppColors.udaanBannerSubtitle parity).
                    color = TierColors.udaanBannerSubtitle,
                )
            }
            Spacer(Modifier.width(8.dp))
            SnabbitButton(
                text = strings.bannerCta,
                onClick = onAccept,
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.M,
                // Figma: dark #1F2937 pill, white label (Flutter AppColors.udaanBannerButton parity).
                containerColor = TierColors.udaanButtonBg,
                contentColor = TierColors.onAccent,
            )
        }
    }
}
