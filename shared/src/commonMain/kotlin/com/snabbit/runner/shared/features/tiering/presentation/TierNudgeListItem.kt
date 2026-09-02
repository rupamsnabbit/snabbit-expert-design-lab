package com.snabbit.runner.shared.features.tiering.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.designsystem.TierColors
import com.snabbit.runner.shared.features.tiering.domain.model.NudgeTheme
import com.snabbit.runner.shared.features.tiering.domain.model.Tier

/**
 * A tappable home-screen nudge row — leading remote image, a title, and a
 * trailing right chevron. Mirrors the Flutter `TierNudgeListItem`; [onClick]
 * opens the nudge's route.
 *
 * The palette is driven by [theme] + [tier] (mirrors the Flutter `_styleFor` /
 * `_tierSpecificStyle`): border/title accent + a background tint per theme, and
 * for `TIER_SPECIFIC` the runner's [tier] accent/tint. [pinkStyle] is the
 * job/coin variant ([JobTieringNudge]) — a borderless pink row.
 *
 * The non-tier-specific leading icon is tinted to the theme accent
 * ([TierColors.nudgeImageTint], `BlendMode.SrcIn`), matching the Flutter
 * `leadingImageColor`; TIER_SPECIFIC (tier badge) and the job/pink variant render
 * untinted. (Needs the DS `SnabbitRemoteImage` `colorFilter` hook, 0.19.0+.)
 */
@Composable
fun TierNudgeListItem(
    imageUrl: String,
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    theme: NudgeTheme = NudgeTheme.GENERIC,
    tier: Tier? = null,
    pinkStyle: Boolean = false,
    // Gate the accent tint. Off for a themeless dynamic nudge so a full-colour
    // backend image renders as-is instead of being flattened by the SrcIn tint.
    tintImage: Boolean = true,
    trailing: (@Composable () -> Unit)? = null,
) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    val bgColor = when {
        pinkStyle -> TierColors.jobPinkBg
        theme == NudgeTheme.TIER_SPECIFIC && tier != null -> TierColors.tint(tier)
        theme == NudgeTheme.BENEFITS -> TierColors.benefitsTint
        theme == NudgeTheme.MOTIVATION -> TierColors.motivationTint
        else -> TierColors.genericBg
    }
    val titleColor = when {
        pinkStyle -> TierColors.jobPinkText
        theme == NudgeTheme.TIER_SPECIFIC && tier != null -> TierColors.accent(tier)
        theme == NudgeTheme.BENEFITS -> TierColors.benefitsTitle
        theme == NudgeTheme.MOTIVATION -> TierColors.motivationAccent
        else -> TierColors.genericTitle
    }
    val borderColor = when {
        theme == NudgeTheme.TIER_SPECIFIC && tier != null -> TierColors.accent(tier)
        theme == NudgeTheme.BENEFITS -> TierColors.benefitsAccent
        theme == NudgeTheme.MOTIVATION -> TierColors.motivationAccent
        else -> TierColors.genericBorder
    }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(bgColor, shape)
            // Job/pink variant is borderless (Flutter parity).
            .then(
                if (pinkStyle) Modifier
                else Modifier.border(SnabbitTheme.borderWidth.thicker, borderColor, shape),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SnabbitRemoteImage(
            model = imageUrl,
            contentDescription = null,
            modifier = Modifier.size(32.dp),
            contentScale = ContentScale.Fit,
            // Tint themed icons to the theme accent (Flutter parity); tier-specific badge
            // + job/pink render untinted. Filter comes from core/designsystem so this
            // feature file never names Color/ColorFilter (detekt ForbiddenImport).
            // A themeless dynamic nudge ([tintImage] = false) keeps the raw backend image.
            colorFilter = if (tintImage) TierColors.nudgeImageTint(theme, pinkStyle) else null,
        )
        Spacer(Modifier.width(8.dp))
        Box(Modifier.weight(1f)) {
            SnabbitText(
                text = title,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = titleColor,
                // ECPO-925: wrap to 2 lines instead of truncating — the job check-in
                // nudge (coin chip steals width) was ellipsised on a single line.
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Spacer(Modifier.width(4.dp))
        if (trailing != null) {
            trailing()
        } else {
            // DS ships ChevronLeft; rotate 180° for the trailing right chevron.
            Box(Modifier.rotate(180f)) {
                SnabbitIcon(
                    name = SnabbitIconName.ChevronLeft,
                    size = 16.dp,
                    color = SnabbitTheme.colors.iconPrimary,
                )
            }
        }
    }
}
