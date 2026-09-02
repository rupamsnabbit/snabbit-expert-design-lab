package com.snabbit.runner.shared.features.tiering.presentation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringNudgeContent

/**
 * Renders the resolved home nudge ([content]) as the appropriate widget — the
 * coins progress card, the job coin-chip row, or the themed list-item row —
 * mirroring the Flutter `ApplicableTieringNudge` router. Stateless: [content]
 * comes from `TieringUiState.homeNudge`; the host wires [onShown] / [onClick] to
 * the ViewModel intents. Renders nothing when [content] is null.
 *
 * [onShown] is the onLoad impression: a keyed [LaunchedEffect] fires it once per
 * rendered nudge identity (the Compose equivalent of the de-duped impression).
 * The coins card is tappable (Flutter parity) → opens the tiers-coins webview via [onClick].
 */
@Composable
fun ApplicableTieringNudge(
    content: TieringNudgeContent?,
    onShown: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (content == null) return
    LaunchedEffect(content.impressionKey()) { onShown() }
    when (content) {
        is TieringNudgeContent.CoinsCard ->
            TierNudgeProgressCard(
                tier = content.tier,
                data = content.data,
                onClick = onClick,
                modifier = modifier,
            )

        is TieringNudgeContent.Job ->
            JobTieringNudge(
                title = content.title,
                coinsCount = content.coinsCount,
                onClick = onClick,
                modifier = modifier,
            )

        is TieringNudgeContent.Themed ->
            TierNudgeListItem(
                imageUrl = content.iconUrl,
                title = content.title,
                theme = content.theme,
                tier = content.tier,
                tintImage = content.tintImage,
                onClick = onClick,
                modifier = modifier,
            )
    }
}

/** Stable identity for the impression — re-fires [onShown] only when the nudge changes. */
private fun TieringNudgeContent.impressionKey(): String = when (this) {
    is TieringNudgeContent.CoinsCard -> "coins:${tier.name}"
    is TieringNudgeContent.Job -> "job:$titleKey"
    is TieringNudgeContent.Themed -> "themed:$titleKey"
}
