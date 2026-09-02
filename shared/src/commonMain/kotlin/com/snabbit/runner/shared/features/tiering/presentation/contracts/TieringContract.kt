package com.snabbit.runner.shared.features.tiering.presentation.contracts

import com.snabbit.runner.shared.features.tiering.domain.model.NudgeTheme
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsData

/**
 * MVI state for the tiering surfaces. Each field is an independent surface the
 * host renders where it belongs — [homeNudge] on Home, [showUdaanBanner] on
 * Home/profile, [showUdaanPlayVideoRow] on the profile card slot (post-intro),
 * [profileTierCard] the profile tier card, [tierBadge] the app-bar pill. All
 * null/false until the Dart-fed data (`current_state.tier_nudge` + `runners/me`) resolves.
 *
 * [profileTierCard] vs [tierBadge] are intentionally gated differently (release temporal→
 * state pivot): the profile card gates on tier identity alone (shows the instant a
 * runner is promoted), while the app-bar pill keeps the full date-based gate and so
 * can lag the card until the effective date. See the ViewModel resolvers.
 */
data class TieringUiState(
    val homeNudge: TieringNudgeContent? = null,
    val showUdaanBanner: Boolean = false,
    /**
     * The post-intro "Play video" row (`SnabbitUdaanPlayVideoRow`) — the profile-card
     * counterpart the banner is replaced by once the intro is viewed. Shown for a
     * service-1, non-suspended runner above BASE; mutually exclusive with
     * [showUdaanBanner] (which needs `!hasViewedIntro`), so at most one of the two renders.
     */
    val showUdaanPlayVideoRow: Boolean = false,
    /** The profile tier card — gated on tier identity (any new-scheme tier), no date gate. */
    val profileTierCard: TierRowContent? = null,
    /** The app-bar tier pill — gated on the full date-based `shouldShowTiering` (unchanged). */
    val tierBadge: TierRowContent? = null,
    /**
     * Raw "tiering is live for this runner" flag — the `runners/me` effective date has been
     * reached (mirrors Flutter `UserProfile.isTieringEnabled`). Independent of the intro/tier
     * gates above; drives the Profile menu's insurance split (Accident + Health when enabled,
     * the generic "Insurance" tile otherwise), matching the Flutter drawer.
     */
    val isTieringEnabled: Boolean = false,
)

/** The resolved home-nudge render variant (mirrors the Flutter `ApplicableTieringNudge` routing). */
sealed interface TieringNudgeContent {
    /** `THE_COIN_NUDGE` → the weekly coins progress card. */
    data class CoinsCard(val tier: Tier, val data: TierCoinsData) : TieringNudgeContent

    /**
     * Job-state nudges (`EARLY_CHECK_IN` / `PERFECT_JOB`) → the coin-chip row.
     * [coinsCount] is null when the backend sent no `coin_amount` (or a non-positive
     * one) — the chip is then hidden entirely (ECPO-1022: no hard-coded default, and
     * a 0 reward shows nothing).
     */
    data class Job(val titleKey: String, val title: String, val coinsCount: Int?) : TieringNudgeContent

    /**
     * Everything else → the themed list-item row. [theme] + [tier] drive the
     * per-theme / per-tier accent (border/title/background); for `TIER_SPECIFIC`
     * the [tier] supplies the accent + tint.
     *
     * [tintImage] gates the `SrcIn` accent tint on the leading icon. Known nudges
     * (monochrome themed glyphs) tint; a dynamic/default nudge tints only when the
     * backend actually sent a theme, so a full-colour backend image is shown as-is.
     */
    data class Themed(
        val titleKey: String,
        val title: String,
        val iconUrl: String,
        val theme: NudgeTheme,
        val tier: Tier?,
        val tintImage: Boolean = true,
    ) : TieringNudgeContent
}

/** A resolved tier row/pill payload — the runner's [tier] (badge + "<Tier> Level" + CTA).
 *  Backs both [TieringUiState.profileTierCard] (profile card) and [TieringUiState.tierBadge] (app-bar pill). */
data class TierRowContent(val tier: Tier)

/** User actions + impressions across the tiering surfaces (one per rendered interaction). */
sealed interface TieringUiIntent {
    data object NudgeShown : TieringUiIntent
    data object NudgeClicked : TieringUiIntent
    /**
     * [showHeaderImage] mirrors the rendered banner variant (home shows the hero
     * header; a header-less variant passes false) so the analytics prop matches
     * what the runner saw — parity with the Flutter banner's own `showHeaderImage`.
     */
    data class BannerShown(val showHeaderImage: Boolean) : TieringUiIntent
    data class BannerClicked(val showHeaderImage: Boolean) : TieringUiIntent
    data object ProfileTierShown : TieringUiIntent
    data object ProfileTierClicked : TieringUiIntent

    /** The app-bar tier badge (replaces the gold-coins pill) — opens tiers home.
     *  Nav-only, no analytics (Flutter `TierBadgeV2` parity). */
    data object TierBadgeClicked : TieringUiIntent

    /** The post-intro profile "Play video" row — re-opens the tiers intro webview.
     *  Nav-only, no analytics (Flutter `SnabbitUdaanPlayVideoRow` parity). */
    data object PlayVideoClicked : TieringUiIntent
}
