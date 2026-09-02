package com.snabbit.runner.shared.features.blocklist.presentation.list

import com.snabbit.runner.shared.core.localization.LocalizationStore

/**
 * UI text for the Block list, fed in as data (server-driven i18n; never CMP `Res`/`stringResource`),
 * mirroring [com.snabbit.runner.shared.features.language.presentation.LanguageStrings]. Defaults are the English fallbacks
 * matching the copy used by the Flutter screen; the host threads localised values at launch.
 */
data class BlockListStrings(
    /** i18n key `block_list`. Section heading. */
    val title: String = "Block list",
    /** i18n key `people_blocked` — the "{n}/{max} People blocked" suffix. */
    val peopleBlocked: String = "People blocked",
    /** i18n key `unblock`. Row CTA. */
    val unblockLabel: String = "Unblock",
    /** Fallback when a blocked customer has no name. */
    val fallbackName: String = "Snabbit Customer",
    /** i18n key `retry`. */
    val retryLabel: String = "Retry",
    /** Empty state (no one blocked). */
    val emptyMessage: String = "No blocked customers",
    /** Load failure (screen-level). */
    val loadError: String = "Couldn't load your block list",
    /** Load failure supporting line (screen-level). */
    val loadErrorSubtitle: String = "This might be a network issue. Please try again.",
    /** Unblock failure (transient). */
    val unblockError: String = "Couldn't unblock. Please try again.",
)

/**
 * Overlays the server-driven i18n map onto these [BlockListStrings]; absent keys fall back
 * to the English defaults. Reached via the cascade from [UnblockToBlockStrings.localized] at
 * the running host — never baked into a data-class default (keeps Koin-less tests/@Previews safe).
 */
fun BlockListStrings.localized(store: LocalizationStore): BlockListStrings = copy(
    title = store.getMessage("block_list.section_block_list", title),
    peopleBlocked = store.getMessage("block_list.people_blocked", peopleBlocked),
    unblockLabel = store.getMessage("block_list.cta_unblock", unblockLabel),
    fallbackName = store.getMessage("block_list.fallback_customer_name", fallbackName),
    retryLabel = store.getMessage("block_list.retry", retryLabel),
    emptyMessage = store.getMessage("block_list.empty_message", emptyMessage),
    loadError = store.getMessage("block_list.load_error", loadError),
    loadErrorSubtitle = store.getMessage("block_list.load_error_subtitle", loadErrorSubtitle),
    unblockError = store.getMessage("block_list.unblock_error", unblockError),
)
