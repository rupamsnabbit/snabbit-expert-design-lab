package com.snabbit.runner.shared.features.kavach.shield.data.remote

/**
 * Runner Safety-Shield consent (D-5). A single write: the runner grants consent before the
 * shield may record. Best-effort — the impl reports transport failures and returns false.
 */
interface ShieldConsentApi {
    /** POST the runner's consent. `true` on HTTP 200, `false` otherwise. */
    suspend fun submitConsent(): Boolean
}

/** Thrown by `activate()` when the consent POST fails — the engine must not start without it. */
class ShieldConsentException(message: String) : Exception(message)
