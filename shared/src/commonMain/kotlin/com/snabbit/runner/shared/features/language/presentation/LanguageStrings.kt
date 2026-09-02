package com.snabbit.runner.shared.features.language.presentation

import com.snabbit.runner.shared.core.localization.LocalizationStore

/**
 * UI text for the Language screen, sourced from the app's server-driven i18n
 * map and fed in as data (never CMP `Res`/`stringResource`).
 *
 * Supplied at screen launch by the host. Defaults are the English fallbacks,
 * matching the keys used by the Flutter screen. `title`/`confirmButton` are
 * threaded from the drawer today; the rest fall back to these defaults until
 * the host threads them too (the i18n keys are listed per field).
 *
 * Note: the legacy `language` data-object Strings seam is intentionally exempt
 * from the composeResources fallback standard (see `cmp-architecture-structure.md`).
 */
data class LanguageStrings(
    /** i18n key `choose_preferred_language`. */
    val title: String = "Choose preferred language",
    /** i18n key `confirm`. */
    val confirmButton: String = "Confirm",
    /** i18n key `language_updated` — success toast. */
    val savedMessage: String = "Language updated",
    /** i18n key `retry`. */
    val retryLabel: String = "Retry",
    /** i18n key `no_languages_available` — empty state. */
    val emptyMessage: String = "No languages available",
    /** i18n key `couldnt_load_languages` — load failure. */
    val loadError: String = "Couldn't load languages",
    /** i18n key `saving_language_failed` — save failure. */
    val saveError: String = "Saving language failed",
)

/**
 * Overlays the server-driven i18n map onto these [LanguageStrings]; absent keys fall back
 * to the English defaults. All keys are invented under `language.*` (this picker's copy
 * isn't in the PM CSVs) — inert (English) until backend serves them.
 */
fun LanguageStrings.localized(store: LocalizationStore): LanguageStrings = copy(
    title = store.getMessage("language.title", title),
    confirmButton = store.getMessage("language.cta_confirm", confirmButton),
    savedMessage = store.getMessage("language.toast_updated", savedMessage),
    retryLabel = store.getMessage("language.cta_retry", retryLabel),
    emptyMessage = store.getMessage("language.empty", emptyMessage),
    loadError = store.getMessage("language.error_load", loadError),
    saveError = store.getMessage("language.error_save", saveError),
)
