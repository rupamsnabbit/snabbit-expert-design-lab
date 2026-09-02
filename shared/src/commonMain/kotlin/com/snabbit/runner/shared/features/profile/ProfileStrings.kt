package com.snabbit.runner.shared.features.profile

import com.snabbit.runner.shared.core.localization.LocalizationStore

/**
 * Server-driven-ready UI text for the Profile screen. Defaults are the English
 * copy; the host may override from the runner's language bundle (parity with
 * [com.snabbit.runner.shared.features.language.LanguageStrings]).
 */
data class ProfileStrings(
    val title: String = "Profile",
    val errorMessage: String = "Couldn't load your profile",
    val retryLabel: String = "Retry",
    /** Shown when the loan vendor page can't be opened (Flutter's "Could not open loan details"). */
    val loanUrlOpenFailed: String = "Could not open loan details",
)

/**
 * Overlays the server-driven i18n map onto these [ProfileStrings]; absent keys fall back
 * to the English defaults. `title` = `common.nav_profile`; the rest are invented under
 * `profile.*` (pending backend), so inert (English) until then.
 */
fun ProfileStrings.localized(store: LocalizationStore): ProfileStrings = copy(
    title = store.getMessage("common.nav_profile", title),
    errorMessage = store.getMessage("profile.error_message", errorMessage),
    retryLabel = store.getMessage("profile.cta_retry", retryLabel),
    loanUrlOpenFailed = store.getMessage("profile.loan_url_open_failed", loanUrlOpenFailed),
)
