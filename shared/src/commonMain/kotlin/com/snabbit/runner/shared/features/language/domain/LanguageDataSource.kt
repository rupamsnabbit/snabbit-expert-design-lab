package com.snabbit.runner.shared.features.language.domain

import com.snabbit.runner.shared.features.language.domain.model.LanguageOption

/**
 * Network seam for the Language screen — KMP-native, via `SnabbitHttpClient`:
 *  - [getLanguages] → `GET api/v1/runners/language_list`
 *  - [setLanguage]  → `PATCH api/v1/runners/me/change_language`
 *
 * This is the feature's single data seam. Its responses map 1:1 onto
 * [LanguageOption] (no DTO/mapping) and there is no cache/fallback, so per the
 * collapse rules there is **no** `Repository` wrapper — the ViewModel and
 * [SetLanguageUseCase][com.snabbit.runner.shared.features.language.domain.usecase.SetLanguageUseCase]
 * depend on this port directly. In tests, use `FakeLanguageDataSource`.
 *
 * `suspend` + main-safe: implementations switch off the main thread internally.
 */
interface LanguageDataSource {
    suspend fun getLanguages(): List<LanguageOption>

    /**
     * Persists [code] as the runner's language preference. Throws on
     * HTTP/transport failure; the caller surfaces the error.
     */
    suspend fun setLanguage(code: String)
}
