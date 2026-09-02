package com.snabbit.runner.shared.features.language.domain.usecase

import com.snabbit.runner.shared.features.language.domain.LanguageDataSource
import com.snabbit.runner.shared.features.language.domain.ProfileGateway
import kotlin.coroutines.cancellation.CancellationException

/**
 * Confirms a language change — the feature's one piece of domain policy.
 *
 * Persists [code] server-side (authoritative) and then best-effort applies it to
 * Flutter-owned state (i18n + local profile) over the bridge:
 *  - the **persist** is authoritative — its failure propagates so the caller can
 *    surface a save error;
 *  - the **apply** is best-effort — a bridge failure is swallowed (the persist
 *    already succeeded), so it must never surface as "Saving failed".
 *
 * Cancellation is always re-thrown so structured concurrency is preserved.
 */
class SetLanguageUseCase(
    private val dataSource: LanguageDataSource,
    private val profileGateway: ProfileGateway,
) {
    /** @throws Throwable if the server-side persist fails; the caller handles it. */
    suspend operator fun invoke(code: String) {
        dataSource.setLanguage(code)
        try {
            profileGateway.applyLanguage(code)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Throwable) {
            // Best-effort — the persist already succeeded, so a bridge/apply
            // failure must not surface as a save error. The gateway impl reports
            // + swallows its own failures (its contract is "never throws"), so
            // this catch is a defensive fallback for a misbehaving impl.
        }
    }
}
