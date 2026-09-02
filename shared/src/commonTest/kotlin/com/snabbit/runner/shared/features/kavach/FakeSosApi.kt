package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.features.kavach.sos.data.remote.ActiveSosState
import com.snabbit.runner.shared.features.kavach.sos.data.remote.ResolveOutcome
import com.snabbit.runner.shared.features.kavach.sos.data.remote.SosApi
import com.snabbit.runner.shared.features.kavach.sos.data.remote.SosUserAction

/** Deterministic fake — records calls; returns configurable results. */
class FakeSosApi : SosApi {
    var initiateCalls = 0
    var resolveCalls = 0
    var activeCalls = 0
    var callSosTeamCalls = 0
    var lastCallPhone: String? = null
    var lastInitiateJobId: Int? = null

    var initiateResult: Int? = 1
    var resolveResult: String? = "0000000000"
    var resolveDelivered = true   // false → backend never got the action (S2: marker must be retained)
    var activeResult: ActiveSosState? = null
    var callResult = true
    var activeThrows = false   // reconcile() failure toggle (tests the reconciler's ack-after-apply retention)

    override suspend fun initiate(source: String, triggerType: String, jobId: Int?): Int? {
        initiateCalls++; lastInitiateJobId = jobId; return initiateResult
    }

    override suspend fun resolve(sosId: Int?, action: SosUserAction): ResolveOutcome {
        resolveCalls++
        return ResolveOutcome(delivered = resolveDelivered, phoneNumber = resolveResult)
    }

    override suspend fun active(): ActiveSosState? {
        activeCalls++
        if (activeThrows) throw IllegalStateException("active failed")
        return activeResult
    }

    override suspend fun callSosTeam(phoneNumber: String): Boolean {
        callSosTeamCalls++; lastCallPhone = phoneNumber; return callResult
    }
}
