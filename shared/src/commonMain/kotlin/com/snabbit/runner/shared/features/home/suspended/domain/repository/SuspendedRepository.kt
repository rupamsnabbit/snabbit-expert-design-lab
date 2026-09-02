package com.snabbit.runner.shared.features.home.suspended.domain.repository

import com.snabbit.runner.shared.features.home.suspended.domain.model.UnsuspendResult

/**
 * Domain port for the runner-suspension actions surfaced by the Home
 * `RUNNER_SUSPENDED` card. Lives in `domain` so the Home ViewModel never
 * reaches into the data layer; the production implementation translates the
 * data-layer `NetworkError` (and the special 409 / 400 statuses) into the
 * domain [UnsuspendResult].
 */
interface SuspendedRepository {
    /**
     * Request reactivation for a suspended runner
     * (`POST api/v1/runners/me/unsuspend`, empty body). Never throws — the
     * network failure is folded into [UnsuspendResult.Failed]. Caller refreshes
     * `current_state` on [UnsuspendResult.Reactivated] to pick up the next
     * widget envelope.
     */
    suspend fun unsuspend(): UnsuspendResult
}
