package com.snabbit.runner.shared.features.language

/** Test [LanguageAnalytics] — records every event for assertions. */
class FakeLanguageAnalytics : LanguageAnalytics {

    var screenViewedCount = 0
        private set

    /** Codes from [languageSelected], in order. */
    val selected = mutableListOf<String>()

    /** Codes from [languageConfirmed], in order. */
    val confirmed = mutableListOf<String>()

    override fun screenViewed() {
        screenViewedCount++
    }

    override fun languageSelected(code: String) {
        selected.add(code)
    }

    override fun languageConfirmed(code: String) {
        confirmed.add(code)
    }
}
