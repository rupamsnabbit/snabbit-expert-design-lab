package com.snabbit.runner.shared.features.tiering.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.runner.shared.core.designsystem.TierColors
import com.snabbit.runner.shared.core.designsystem.components.HeaderNavPill
import com.snabbit.runner.shared.features.tiering.domain.model.Tier

/**
 * Tier Badge v2 (Figma "Expert Tier" app-bar medal, nodes 4633-234xx) — realized
 * as a [HeaderNavPill] so it slots into the home top nav exactly like the
 * coins / SOS pills: a 40dp icon circle with a gradient "name capsule" hugging
 * its bottom edge (the same `HeaderPillStack` layout, tap target and −6dp overlap).
 *
 * The icon circle is a plain white disc holding the runner's remote tier badge
 * ([TierAssets.badgeUrl] — the icons already shipped for the nudges); the capsule
 * is the per-tier gradient + text colour from [TierColors]. Tap → [onClick] (opens
 * the tiers "Levels Home" webview). Mirrors the Flutter `TierBadgeV2` + its
 * `partner_home` mount, where it replaces the gold-coins pill once tiering is on.
 */
fun tierHeaderPill(tier: Tier, onClick: () -> Unit): HeaderNavPill = HeaderNavPill(
    // glyphBg is ignored (glyphContent overrides the default circle) but required.
    glyphBg = TierColors.badgeCircleBg,
    label = tier.displayName,
    chipBackground = TierColors.capsuleBrush(tier),
    chipTextColor = TierColors.capsuleText(tier),
    chipBorderColor = null, // the capsule has no border (Figma)
    contentDescription = "${tier.displayName} Level",
    onClick = onClick,
    glyphContent = { TierBadgeIcon(TierAssets.badgeUrl(tier)) },
)

/** White 40dp disc holding the 24dp remote tier badge (no gray hairline ring). */
@Composable
private fun TierBadgeIcon(badgeUrl: String) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(TierColors.badgeCircleBg, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        SnabbitRemoteImage(
            model = badgeUrl,
            contentDescription = null,
            modifier = Modifier.size(24.dp),
            contentScale = ContentScale.Fit,
        )
    }
}
