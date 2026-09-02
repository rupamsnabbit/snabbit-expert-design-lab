package com.snabbit.runner.shared.features.language

import com.snabbit.runner.shared.features.language.domain.LanguageDataSource
import com.snabbit.runner.shared.features.language.domain.model.LanguageOption

/**
 * Test [LanguageDataSource]. Set [error] to make [getLanguages] throw, or
 * [setLanguageError] to make [setLanguage] throw.
 */
class FakeLanguageDataSource(
    var languages: List<LanguageOption> = sampleLanguages,
    var error: Throwable? = null,
    var setLanguageError: Throwable? = null,
) : LanguageDataSource {

    var getLanguagesCallCount = 0
        private set

    /** Codes passed to [setLanguage], in order. */
    val setLanguageCalls = mutableListOf<String>()

    override suspend fun getLanguages(): List<LanguageOption> {
        getLanguagesCallCount++
        error?.let { throw it }
        return languages
    }

    override suspend fun setLanguage(code: String) {
        setLanguageError?.let { throw it }
        setLanguageCalls.add(code)
    }

    companion object {
        val sampleLanguages = listOf(
            LanguageOption("en", "English", "English", "A", "a"),
            LanguageOption("hi", "Hindi", "हिन्दी", "अ", "आ"),
            LanguageOption("kn", "Kannada", "ಕನ್ನಡ", "ಕ", "ನ"),
        )
    }
}
