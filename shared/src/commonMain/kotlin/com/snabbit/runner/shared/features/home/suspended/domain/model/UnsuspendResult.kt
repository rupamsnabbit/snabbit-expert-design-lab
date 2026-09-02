package com.snabbit.runner.shared.features.home.suspended.domain.model

/**
 * Outcome of the runner's "Come Back to Work" request
 * (`POST api/v1/runners/me/unsuspend`).
 *
 * Three cases, mirroring the Dart `RunnerSuspended._onComeBackToWorkTapped`
 * status handling (`runner_suspended.dart`):
 *  - **200 or 409** → [Reactivated]. 409 means the reactivation request was
 *    already in flight; Dart treats it as success too, so the button locks to
 *    "Request submitted".
 *  - **400** → [Denied]. The backend refused the request; the body carries a
 *    `status` (mapped to [reason]) and a `message`. The button still locks
 *    (the runner has been told why), so the UI treatment matches [Reactivated].
 *  - anything else / transport failure → [Failed]. The button stays tappable
 *    so the runner can retry; a snackbar is shown.
 *
 * This is a bespoke result type rather than `Result<Unit, RunnerActionError>`
 * because 409 is a success and 400 carries a displayable reason — neither fits
 * the generic status-bucket error the other shift actions use.
 */
sealed interface UnsuspendResult {
    /** 200 or 409 — reactivation accepted / already requested. [statusCode] is the
     *  actual code (200 or 409) so analytics can distinguish the two, Dart parity. */
    data class Reactivated(val statusCode: Int) : UnsuspendResult

    /** 400 — request refused; [reason] is the body `status`, [message] its `message`. */
    data class Denied(val reason: String, val message: String) : UnsuspendResult

    /** Any other status, malformed body, or transport failure. [statusCode] is null
     *  when there was no HTTP response; [message] is the server body `message`/`detail`
     *  when present (shown verbatim in the snackbar, Dart parity), else null. */
    data class Failed(val statusCode: Int? = null, val message: String? = null) : UnsuspendResult
}
