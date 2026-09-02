package com.snabbit.runner.shared.features.job.domain.model

import com.snabbit.runner.shared.core.network.AppErrorType

/**
 * The domain vocabulary of a failed job action (accept / deny / check-in / checkout / rate).
 * The data source maps transport/HTTP failures to one of these so the presentation layer
 * branches on meaning, never on HTTP status codes or raw `NetworkError`.
 *
 * - [Reassigned]  — HTTP 409: the job was reassigned to another expert (a normal race).
 * - [CheckInLocation]     — check-in `failure_type: LOCATION` (runner not at the job location).
 * - [CheckInPhoneMismatch]— check-in `failure_type: PHONE_NUMBER` (booking phone didn't match).
 * - [Network]     — the request never got an HTTP answer (no internet, timeout, TLS, cold-start
 *   gate). Split out of [Generic] so telemetry can say `is_network_error` truthfully — it was
 *   hardcoded `false` before, which made "no internet" and "the backend rejected this"
 *   indistinguishable in the error funnel. Carries no new UX: it still shows the generic message.
 * - [Generic]     — everything else (other 4xx/5xx that carried no message); the data source has
 *   already reported the crash non-fatal, so the caller only needs a user-facing message.
 * - [Server]      — a server-rendered CustomError message (`errors[0].message`) shown verbatim;
 *   preferred over [Reassigned] / [Generic] whenever the error body carries a message.
 */
sealed class JobActionError {
    data object Reassigned : JobActionError()
    data object CheckInLocation : JobActionError()
    data object CheckInPhoneMismatch : JobActionError()
    data object Generic : JobActionError()

    /** No HTTP answer at all — [errorType] carries which transport failure it was. */
    data class Network(val errorType: AppErrorType) : JobActionError()

    /**
     * A server-provided CustomError [message] (`errors[0].message`), surfaced verbatim so the user
     * sees the backend copy instead of a hardcoded string (ECPO #8). The other variants are the
     * no-message fallbacks (Reassigned for a 409 race, Generic otherwise).
     */
    data class Server(val message: String) : JobActionError()
}

/**
 * Coarse, PII-safe failure class for instrumentation (`error_reason` / `error_kind`): the domain
 * meaning of the failure, never the raw server body. Shared by the accept/deny resolution
 * (`JobViewModel`) and the check-in/checkout OTP CTA events, so a "wrong OTP" a runner reported can be
 * told apart from a dropped connection or a backend reject in the error funnel (ECPO-1059). Exhaustive
 * `when` — a new [JobActionError] variant is a compile error here, not a silent `null` reason.
 */
fun JobActionError.errorKind(): String = when (this) {
    JobActionError.Reassigned -> "reassigned"
    is JobActionError.Server -> "server"
    is JobActionError.Network -> "network"
    JobActionError.CheckInLocation -> "check_in_location"
    JobActionError.CheckInPhoneMismatch -> "check_in_phone_mismatch"
    JobActionError.Generic -> "generic"
}
