package com.snabbit.runner.shared.features.kavach.sos.data.remote

/**
 * App-side SOS backend calls (distinct from the plugin). Best-effort, 1:1 with the
 * Flutter SOS flow: failures return null/false (logged), never throw — the SoS
 * state machine (later increment) drives these + reconciles via [active].
 *
 *  - E1 [initiate] `POST api/v1/runners/me/sos/initiate` → `sos_id`
 *  - E2 [resolve]  `POST api/v1/runners/me/sos` (confirm/deny/dismiss) → `ph_no`
 *  - E3 [active]   `GET  api/v1/runners/me/sos/active` → active-SOS snapshot
 *  - E4 [callSosTeam] `POST api/v1/runners/phone_call/{phone}` → success
 */
interface SosApi {
    suspend fun initiate(source: String, triggerType: String, jobId: Int?): Int?
    /**
     * E2 resolve. Returns [ResolveOutcome] rather than the phone alone: `ph_no` is legitimately null
     * on a successful deny/dismiss, so a bare `String?` made a failed call indistinguishable from a
     * delivered one — and the caller then cleared local state for an SOS the backend still had open.
     */
    suspend fun resolve(sosId: Int?, action: SosUserAction): ResolveOutcome
    suspend fun active(): ActiveSosState?
    suspend fun callSosTeam(phoneNumber: String): Boolean
}

/**
 * Result of an E2 resolve. [delivered] = the backend accepted the action; it is the only reliable
 * signal, since [phoneNumber] is null on a successful deny/dismiss as well as on failure.
 */
data class ResolveOutcome(val delivered: Boolean, val phoneNumber: String? = null)

/** E2 `user_action` values (the backend's fixed set). */
enum class SosUserAction(val apiValue: String) {
    CONFIRM("confirm"),
    DENY("deny"),
    DISMISS("dismiss"),
}

/** Parsed `GET /sos/active` snapshot. */
data class ActiveSosState(
    val hasActiveSos: Boolean,
    val status: String?,
    val sosId: Int?,
    val phoneNumber: String?,
)
