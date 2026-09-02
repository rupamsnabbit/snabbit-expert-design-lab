package com.snabbit.runner.shared.features.tiering.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme

/**
 * Job/coin tiering nudge (`EARLY_CHECK_IN` / `PERFECT_JOB`): the base
 * [TierNudgeListItem] with the job badge leading and a trailing coin-count chip,
 * in the borderless pink variant. Mirrors the Flutter `JobTieringNudge`.
 *
 * [coinsCount] is null when the backend sent no reward (ECPO-1022) — the chip is
 * then omitted. A non-null empty trailing is passed (rather than falling through to
 * [TierNudgeListItem]'s default chevron) because the job nudge is non-navigable.
 */
@Composable
fun JobTieringNudge(
    title: String,
    coinsCount: Int?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    TierNudgeListItem(
        imageUrl = TierAssets.JOB_URL,
        title = title,
        onClick = onClick,
        modifier = modifier,
        pinkStyle = true,
        trailing = { if (coinsCount != null) CoinCountChip(coinsCount) },
    )
}

/** White pill: the Snabbit-coin icon + the coin count. */
@Composable
private fun CoinCountChip(coinsCount: Int) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(percent = 50))
            .background(SnabbitTheme.colors.bgPrimary)
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SnabbitRemoteImage(
            model = TierAssets.COIN_URL,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            contentScale = ContentScale.Fit,
        )
        Spacer(Modifier.width(4.dp))
        SnabbitText(
            text = coinsCount.toString(),
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textPrimary,
        )
    }
}
