package com.snabbit.runner.shared.features.tiering.presentation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.snabbit.runner.shared.core.localization.LocalizationStore
import org.koin.mp.KoinPlatform.getKoin

/**
 * Resolved chrome copy for the tiering surfaces — the intro banner, the drawer /
 * profile "level" row, and the coins card / week flags. (The per-nudge titles are
 * resolved separately in [TieringViewModel] via [tierNudgeCopy], since they need
 * per-nudge `nudge_details`.)
 *
 * Localization mirrors Flutter: the keys Flutter's `LanguageProvider` already uses
 * are matched exactly — [bannerTitle] (`snabbit_udaan_banner_title`), [bannerSubtitle]
 * (`snabbit_udaan_banner_subtitle`), [bannerCta] (`View`), [viewLevel] (`view_tier`).
 * The strings Flutter renders raw ([levelWord], [weekWord], [coinsLabel],
 * [playVideoTitle], [playVideoCta]) are given KMP keys here so they localize too;
 * their English fallback renders identically to Flutter until a bundle value lands
 * (so today the surfaces look the same on both).
 *
 * Defaults are the English fallbacks; [rememberTieringStrings] overlays the
 * Koin-resolved [LocalizationStore], exactly like `rememberCameraStrings`.
 */
data class TieringStrings(
    val bannerTitle: String = "Introducing Snabbit Udaan",
    val bannerSubtitle: String = "A new way to reward good work",
    val bannerCta: String = "View",
    val viewLevel: String = "View level",
    /** Suffix in the "<Tier> Level" row title — Flutter interpolates the raw word. */
    val levelWord: String = "Level",
    /** Prefix in the "Week N" flag label — Flutter renders it raw. */
    val weekWord: String = "Week",
    /** Unit label after the coin count on the coins card. */
    val coinsLabel: String = "Snabbit coins",
    /** Post-intro "Play video" row title — the "Snabbit Udaan" brand label (Flutter renders it raw). */
    val playVideoTitle: String = "Snabbit Udaan",
    /** Post-intro "Play video" row CTA — re-opens the tiers intro (Flutter renders it raw). */
    val playVideoCta: String = "Play video",
)

/**
 * The localized [TieringStrings] — English defaults overlaid with the
 * [LocalizationStore] (Koin-resolved). Call from tiering composables as the default
 * for a `strings` parameter so every call site localizes yet stays test-overridable.
 */
@Composable
fun rememberTieringStrings(): TieringStrings =
    remember { TieringStrings() }.localized(getKoin().get())

/** Overlays the localization store onto the English defaults (Flutter-key parity). */
fun TieringStrings.localized(store: LocalizationStore): TieringStrings = copy(
    bannerTitle = store.getMessage("snabbit_udaan_banner_title", bannerTitle),
    bannerSubtitle = store.getMessage("snabbit_udaan_banner_subtitle", bannerSubtitle),
    bannerCta = store.getMessage("View", bannerCta),
    viewLevel = store.getMessage("view_tier", viewLevel),
    levelWord = store.getMessage("tiering_level_word", levelWord),
    weekWord = store.getMessage("tiering_week_word", weekWord),
    coinsLabel = store.getMessage("tiering_snabbit_coins", coinsLabel),
    playVideoTitle = store.getMessage("tiering_snabbit_udaan", playVideoTitle),
    playVideoCta = store.getMessage("tiering_play_video", playVideoCta),
)
