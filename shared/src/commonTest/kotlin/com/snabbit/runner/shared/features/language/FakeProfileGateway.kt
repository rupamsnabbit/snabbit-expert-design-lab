package com.snabbit.runner.shared.features.language

import com.snabbit.runner.shared.features.language.domain.ProfileGateway

/** Test [ProfileGateway]. Set [applyLanguageError] to make [applyLanguage] throw. */
class FakeProfileGateway(
    var applyLanguageError: Throwable? = null,
) : ProfileGateway {

    /** Codes passed to [applyLanguage], in order. */
    val applyLanguageCalls = mutableListOf<String>()

    override suspend fun applyLanguage(code: String) {
        applyLanguageError?.let { throw it }
        applyLanguageCalls.add(code)
    }
}
