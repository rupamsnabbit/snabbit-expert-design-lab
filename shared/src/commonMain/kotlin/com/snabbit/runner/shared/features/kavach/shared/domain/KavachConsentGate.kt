package com.snabbit.runner.shared.features.kavach.shared.domain

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.ShieldProfileGateway
import com.snabbit.runner.shared.features.kavach.shield.data.remote.ShieldConsentApi
import com.snabbit.runner.shared.features.profile.RunnerProfileStore

/**
 * Runner-consent gate for the home page. Shows the consent sheet whenever the partner has shield
 * enabled and the runner hasn't consented — irrespective of current_state (any job stage). Records
 * consent on agree. Consent gates ML monitoring + recording downstream (see `arm()`).
 */
class KavachConsentGate(
    private val shieldProfile: ShieldProfileGateway,
    private val consentApi: ShieldConsentApi,
    private val profileStore: RunnerProfileStore?,
    private val analytics: AnalyticsTracker,
) {
    // Home-VM (Main) only: optimistic consent latch + concurrent-submit guard — plain vars are safe.
    private var consented = false
    private var submitting = false

    /** Partner on and runner consent not yet given — no current_state condition. Latches once granted so
     *  a slow/collapsed profile refresh can't briefly re-prompt. */
    suspend fun shouldShow(): Boolean =
        !consented && shieldProfile.partnerShieldEnabled() && shieldProfile.runnerConsentGiven() != true

    /** POST runner consent, then refresh `runners/me` so `consent_given` flips true. Concurrent taps
     *  collapse to one POST; the local latch flips immediately on success (no re-prompt window). */
    suspend fun submit(): Boolean {
        if (submitting) return false
        submitting = true
        try {
            val ok = consentApi.submitConsent()
            if (ok) {
                consented = true
                analytics.track("expert_shield_consent_given", mapOf("runner_id" to profileStore?.snapshot()?.expertId))
                profileStore?.requestRefresh()
            }
            return ok
        } finally {
            submitting = false
        }
    }
}
