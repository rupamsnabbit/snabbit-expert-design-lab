package com.snabbit.runner.shared.features.job.delayedcheckin.domain.repository

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result

/**
 * Support-funnel network surface for the delayed check-in penalty overlay:
 * submitting a disposition and resolving the helpline number to dial. No
 * use-case layer by design — the (future Tranche 2) ViewModel calls this
 * directly.
 */
interface DelayedCheckinRepository {

    /**
     * `POST api/v1/runner_job/penalty/{runnerJobId}/disposition?ameyo_support=<bool>`.
     * [ameyoSupport] is the `RemoteConfigKeys.ameyoSupport` flag mirrored
     * from Dart — when true, the backend connects the call itself instead
     * of the client dialling [getHelpline]'s number. Ok wraps the ack's
     * optional server-driven confirmation `message` (Dart parity:
     * `response?.data?['message']`), or `null` when the body carries none —
     * callers fall back to their default copy.
     */
    suspend fun submitDisposition(
        runnerJobId: Int,
        jobId: Int,
        runnerId: Int,
        dispositionTag: String,
        dispositionMessage: String,
        ameyoSupport: Boolean,
    ): Result<String?, NetworkError>

    /**
     * `GET api/v1/runners/me/helpline?type=<widgetType>`. Ok wraps the
     * dialable phone number, or `null` when the backend has none configured
     * for [widgetType] — that is a valid response, not an error.
     */
    suspend fun getHelpline(widgetType: String): Result<String?, NetworkError>
}
