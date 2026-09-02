package com.snabbit.runner.shared.features.kavach.shield.data.gateway

import com.snabbit.runner.shared.features.kavach.shield.data.remote.RunnerMeDto
import com.snabbit.runner.shared.features.kavach.shield.data.remote.SafetyShieldDto
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import kotlinx.serialization.json.Json

/**
 * Prod [ShieldProfileGateway] backed by the in-memory [RunnerProfileStore] — the raw `runners/me`
 * body Dart already pushes on device (KMP does not fetch it natively; that would double the API).
 * Resolves the deferred "Decision A" to the store-read path: no runners/me re-fetch on activate/restore.
 *
 * [profileStore] is nullable because its Koin binding lives in `profileModule`, which is NOT loaded on
 * iOS (bridge populators are Android-only today, mirroring how [com.snabbit.runner.shared.features.kavach.shared.domain.JobKavachCoordinator]
 * already consumes the runner-state store). A null store / absent `safety_shield` resolves to the
 * fail-closed defaults, exactly like [DefaultShieldProfileGateway]; `consent_given` null is preserved.
 */
class StoreShieldProfileGateway(
    private val profileStore: RunnerProfileStore?,
) : ShieldProfileGateway {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    // Decode only the safety_shield slice out of the retained profile body (RunnerMeDto ignores the
    // rest). null when nothing pushed yet / on iOS (no store) / on a decode failure → fail-closed.
    private fun shield(): SafetyShieldDto? {
        val raw = profileStore?.rawSnapshot() ?: return null
        return runCatching { json.decodeFromJsonElement(RunnerMeDto.serializer(), raw).safetyShield }.getOrNull()
    }

    override suspend fun partnerShieldEnabled(): Boolean = shield()?.enabled ?: false
    override suspend fun runnerConsentGiven(): Boolean? = shield()?.consentGiven   // null preserved
    override suspend fun consentAt(): String? = shield()?.consentAt
}
