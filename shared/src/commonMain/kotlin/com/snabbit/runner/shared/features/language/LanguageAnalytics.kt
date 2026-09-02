package com.snabbit.runner.shared.features.language

/**
 * Observability seam for the Language screen. Implementations forward to the
 * app's analytics (CleverTap / Mixpanel) — channel-backed, wired in `:app`.
 * Tests use `FakeLanguageAnalytics`.
 *
 * Fire-and-forget — not suspending; implementations must not block.
 */
interface LanguageAnalytics {
    /** The screen became visible. */
    fun screenViewed()

    /** The runner tapped a language row. */
    fun languageSelected(code: String)

    /** A language change was successfully saved. */
    fun languageConfirmed(code: String)
}
