package com.snabbit.runner.shared.features.home.presentation.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.snabbit.runner.shared.core.designsystem.components.HeaderNavPill
import com.snabbit.runner.shared.core.designsystem.components.SnabbitHeaderNav
import com.snabbit.runner.shared.core.designsystem.components.coinsPill
import com.snabbit.runner.shared.core.designsystem.components.redCardPill
import com.snabbit.runner.shared.core.designsystem.components.saathiPill
import com.snabbit.runner.shared.core.designsystem.components.sosPill
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent

/**
 * Home top nav: stacked (icon-button + chip) pills on the right — SOS / Saathi
 * plus the gated rewards pair (coins, red cards). A thin wrapper over the
 * reusable [SnabbitHeaderNav]; the pill styling lives in its factories so the
 * Job header shares it.
 *
 * No leading slot — [SnabbitHeaderNav] then right-aligns the pills
 * (`Arrangement.End`). (The notification bell that used to sit on the left was
 * removed.)
 */
@Composable
fun HomeTopNav(
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
    coinsCount: Int = 0,
    redCardsCount: Int = 0,
    /** Backend `sos_visibility.visible` — hides the pill outside the shift window. Defaults true so
     *  an absent flag (or a preview) always shows it; Flutter parity. */
    sosVisible: Boolean = true,
    /** Profile gate shared by coins + red card ([HomeUiState.rewardsPillsVisible] — rate card
     *  v2, not suspended); defaults true so DI-free previews render the coins pill. */
    coinsVisible: Boolean = true,
    /** [coinsVisible] AND the `expert_show_red_card_pill` RC flag; defaults false (ships dark). */
    redCardVisible: Boolean = false,
    /** When non-null (tiering enabled) the tier badge replaces the gold-coins pill. */
    tierPill: HeaderNavPill? = null,
) {
    SnabbitHeaderNav(
        modifier = modifier,
        trailing = buildList {
            if (sosVisible) add(sosPill(strings.topNavSosLabel) { onIntent(HomeUiIntent.TapSos) })
            add(saathiPill(strings.topNavSaathiLabel) { onIntent(HomeUiIntent.TapSaathi) })
            // Tiering: the tier badge takes the coins pill's slot (Flutter parity —
            // `partner_home` hides HomeRewardsHeaderPill when isTieringEnabled).
            if (tierPill != null) {
                add(tierPill)
            } else if (coinsVisible) {
                add(coinsPill(coinsCount.toString()) { onIntent(HomeUiIntent.TapCoins) })
            }
            if (redCardVisible) {
                add(redCardPill(redCardsCount.toString()) { onIntent(HomeUiIntent.TapRedCards) })
            }
        },
    )
}
