package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.features.kavach.shield.data.gateway.ShieldProfileGateway

/** Settable runner-profile shield state for enablement/consent-gate tests. */
class FakeShieldProfileGateway(
    var partnerEnabled: Boolean = false,
    var consentGiven: Boolean? = null,
    var at: String? = null,
) : ShieldProfileGateway {
    override suspend fun partnerShieldEnabled(): Boolean = partnerEnabled
    override suspend fun runnerConsentGiven(): Boolean? = consentGiven
    override suspend fun consentAt(): String? = at
}
