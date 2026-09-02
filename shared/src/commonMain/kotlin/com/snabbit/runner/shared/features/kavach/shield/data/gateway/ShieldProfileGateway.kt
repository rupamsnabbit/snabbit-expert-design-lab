package com.snabbit.runner.shared.features.kavach.shield.data.gateway

/**
 * Runner-profile shield state from `runners/me.safety_shield` (partner enablement + runner
 * consent). Named `Shield…` to avoid colliding with the language feature's `ProfileGateway`.
 * commonMain [DefaultShieldProfileGateway] is the safe no-host fallback.
 */
interface ShieldProfileGateway {
    /** `safety_shield.enabled` (partner turned the feature on). */
    suspend fun partnerShieldEnabled(): Boolean
    /** `safety_shield.consent_given` — null ≠ false (null still needs the consent prompt). */
    suspend fun runnerConsentGiven(): Boolean?
    suspend fun consentAt(): String?
}

class DefaultShieldProfileGateway : ShieldProfileGateway {
    override suspend fun partnerShieldEnabled(): Boolean = false
    override suspend fun runnerConsentGiven(): Boolean? = null
    override suspend fun consentAt(): String? = null
}
