package com.snabbit.runner.shared.features.autoot.domain.repository

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDenyReason
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails

/**
 * Domain contract for Auto-OT write actions + the pre-shift (START_OT) fetch —
 * a port of Flutter `AutoOtHttp`. Collapses the data-layer network error into
 * [RunnerActionError] so domain + presentation never see HTTP types.
 */
interface AutoOtRepository {
    /** Accept the offer — `POST api/v1/auto-ot/requests/{id}/accept`. */
    suspend fun accept(requestId: Int): Result<Unit, RunnerActionError>

    /** Reject / dismiss the offer — `POST .../reject` with `rejection_reason`. Best-effort. */
    suspend fun reject(requestId: Int, reason: AutoOtDenyReason): Result<Unit, RunnerActionError>

    /**
     * Pre-shift (START_OT) fetch after attendance is marked —
     * `POST api/v1/auto-ot/start-ot/request`. `Ok(null)` = no offer (empty body /
     * missing request id); `Ok(details)` = an offer to present.
     */
    suspend fun requestStartOt(): Result<AutoOtDetails?, RunnerActionError>
}
