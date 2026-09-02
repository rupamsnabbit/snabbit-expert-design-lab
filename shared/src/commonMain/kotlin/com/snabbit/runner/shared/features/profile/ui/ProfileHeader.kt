package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.runner.shared.core.designsystem.TierColors
import com.snabbit.runner.shared.core.designsystem.drawTierCardRings
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.presentation.TierAssets
import com.snabbit.runner.shared.features.tiering.presentation.rememberTieringStrings
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.period_leave_drop
import org.jetbrains.compose.resources.painterResource
import org.koin.mp.KoinPlatform.getKoin

/**
 * Profile header — the "star-expert" card (Figma node `933:32258`): a near-white
 * card with a tan 1dp border, holding the runner's photo, name, a
 * `delivery-method · #id` sub-line, and (when the runner has a period-leave quota)
 * a period-leave chip. Rating is intentionally NOT shown.
 *
 * **Tiering:** when [tier] is non-null (i.e. the runner is tiering-enabled — the
 * same gate as the Flutter `ViewTierFromDrawerMenu` / `expert_info.dart`), the card
 * switches to the per-tier gradient background (`TierColors.cardRadialBrush`,
 * Figma "Expert Tier" profile card), the text goes light, and a bottom row is added
 * — the tier badge + "{Tier} Level" + a "View level" CTA ([onTierClick] → tiers
 * webview). When null the card renders exactly as before (near-white, tan border).
 *
 * Built in **Material 3** with [ProfileTileDefaults] tokens; an M3 [Surface] gives
 * the card its shape/border and — when [onClick] is set — the whole-card ripple to
 * open the Identity Card. `commonMain` / iOS-safe.
 *
 * @param expertId display id already formatted with the leading `#` (e.g. "#2413").
 * @param periodLeaveMax total period-leave quota; the chip shows only when `> 0`.
 * @param periodLeaveTaken period leaves already used (clamped to `0..periodLeaveMax`).
 * @param onClick optional whole-card tap (→ Identity Card); non-clickable when null.
 * @param tier non-null → the per-tier "level" card; null → the default near-white card.
 * @param onTierClick "View level" tap (→ tiers home webview); used only when [tier] != null.
 * @param onTierShown fired once per appearance of the tier row (impression).
 */
@Composable
fun ProfileHeader(
    name: String?,
    deliveryMethod: String?,
    expertId: String?,
    photoUrl: String?,
    modifier: Modifier = Modifier,
    periodLeaveMax: Int = 0,
    periodLeaveTaken: Int = 0,
    onClick: (() -> Unit)? = null,
    tier: Tier? = null,
    onTierClick: () -> Unit = {},
    onTierShown: () -> Unit = {},
) {
    val subtitle = listOfNotNull(
        deliveryMethod?.takeIf { it.isNotBlank() },
        expertId?.takeIf { it.isNotBlank() },
    ).takeIf { it.isNotEmpty() }?.joinToString("  ·  ")

    val shape = RoundedCornerShape(ProfileTileDefaults.HeaderCornerRadius)
    // The tiering card has no tan border (its gradient carries the identity).
    val border = if (tier == null) {
        BorderStroke(ProfileTileDefaults.HeaderBorderWidth, ProfileTileDefaults.HeaderBorder)
    } else {
        null
    }

    if (tier != null) LaunchedEffect(tier) { onTierShown() }

    // The gradient is painted on the content (behind it), clipped to the card shape
    // by the Surface. It is opaque, so it covers the Surface's solid `color`.
    val content: @Composable () -> Unit = {
        val gradientModifier = if (tier != null) {
            Modifier.drawBehind {
                drawRect(TierColors.cardRadialBrush(tier, size))
                // Concentric decorative rings in the bottom-right (Figma) — clipped to the card.
                drawTierCardRings()
            }
        } else {
            Modifier
        }
        ProfileHeaderContent(
            name = name,
            subtitle = subtitle,
            photoUrl = photoUrl,
            periodLeaveMax = periodLeaveMax,
            periodLeaveTaken = periodLeaveTaken,
            tier = tier,
            onTierClick = onTierClick,
            modifier = gradientModifier,
        )
    }

    if (onClick != null) {
        Surface(
            onClick = onClick,
            modifier = modifier.fillMaxWidth(),
            shape = shape,
            color = ProfileTileDefaults.HeaderGradientStart,
            border = border,
        ) { content() }
    } else {
        Surface(
            modifier = modifier.fillMaxWidth(),
            shape = shape,
            color = ProfileTileDefaults.HeaderGradientStart,
            border = border,
        ) { content() }
    }
}

@Composable
private fun ProfileHeaderContent(
    name: String?,
    subtitle: String?,
    photoUrl: String?,
    periodLeaveMax: Int,
    periodLeaveTaken: Int,
    tier: Tier?,
    onTierClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tiering = tier != null
    val nameColor = if (tiering) ProfileTileDefaults.HeaderTierName else ProfileTileDefaults.HeaderName
    val subtitleColor = if (tiering) ProfileTileDefaults.HeaderTierSubtitle else ProfileTileDefaults.HeaderSubtitle
    Column(
        modifier = modifier.fillMaxWidth().padding(ProfileTileDefaults.HeaderPadding),
        verticalArrangement = Arrangement.spacedBy(ProfileTileDefaults.HeaderRowToChip),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.HeaderAvatarGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ProfileAsyncImage(
                photoUrl = photoUrl,
                diameter = ProfileTileDefaults.HeaderAvatarSize.value.toInt(),
            )
            Column(verticalArrangement = Arrangement.spacedBy(ProfileTileDefaults.HeaderNameToId)) {
                SnabbitText(
                    text = name.orEmpty(),
                    variant = SnabbitTextVariant.Title,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = nameColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (subtitle != null) {
                    SnabbitText(
                        text = subtitle,
                        variant = SnabbitTextVariant.BodyMd,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = subtitleColor,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
        if (periodLeaveMax > 0) {
            PeriodLeaveChip(
                taken = periodLeaveTaken.coerceIn(0, periodLeaveMax),
                max = periodLeaveMax,
                tiering = tiering,
            )
        }
        if (tier != null) {
            TierLevelRow(tier = tier, onClick = onTierClick)
        }
    }
}

/**
 * Bottom row of the tiering card: the tier badge + "{Tier} Level", with a trailing
 * "View level" CTA (→ tiers webview). Mirrors the Flutter `ViewTierFromDrawerMenu`.
 */
@Composable
private fun TierLevelRow(tier: Tier, onClick: () -> Unit) {
    // Localized via the tiering strings (Flutter-key parity: `tiering_level_word` / `view_tier`),
    // matching the PeriodLeaveChip below and the tiering surfaces; English fallbacks pre-bundle.
    val strings = rememberTieringStrings()
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.TierRowGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SnabbitRemoteImage(
                model = TierAssets.badgeUrl(tier),
                contentDescription = null,
                modifier = Modifier.size(ProfileTileDefaults.TierRowBadgeSize),
                contentScale = ContentScale.Fit,
            )
            SnabbitText(
                text = "${tier.displayName} ${strings.levelWord}",
                variant = SnabbitTextVariant.BodyMd,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = ProfileTileDefaults.HeaderTierRowText,
            )
        }
        Row(
            modifier = Modifier.clickable(onClick = onClick),
            horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.TierRowCtaGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SnabbitText(
                text = strings.viewLevel,
                variant = SnabbitTextVariant.BodyMd,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = ProfileTileDefaults.HeaderTierRowText,
            )
            // DS ships ChevronLeft; rotate 180° for the trailing right chevron.
            Row(modifier = Modifier.rotate(180f)) {
                SnabbitIcon(
                    name = SnabbitIconName.ChevronLeft,
                    size = ProfileTileDefaults.TierRowChevronSize,
                    color = ProfileTileDefaults.HeaderTierRowText,
                )
            }
        }
    }
}

/** Drop icon + "Period Leave (taken/max)" (drawer parity). */
@Composable
private fun PeriodLeaveChip(taken: Int, max: Int, tiering: Boolean) {
    val l10n: LocalizationStore = getKoin().get()
    Row(
        horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.PeriodLeaveChipGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(Res.drawable.period_leave_drop),
            contentDescription = null,
            modifier = Modifier.size(ProfileTileDefaults.PeriodLeaveChipIcon),
        )
        SnabbitText(
            text = l10n.getMessage("profile.period_leave", "Period Leave ({taken}/{max})")
                .replace("{taken}", taken.toString()).replace("{max}", max.toString()),
            variant = SnabbitTextVariant.Caption,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            // On the dark tier gradient the black chip text would vanish — go light.
            color = if (tiering) ProfileTileDefaults.HeaderTierSubtitle else ProfileTileDefaults.PeriodLeaveChipText,
        )
    }
}
