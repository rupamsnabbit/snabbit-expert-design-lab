package com.snabbit.runner.shared.features.job.domain.model

/**
 * A semantic, resolvable message the job flow emits into its UiState — instead of resolved copy — so
 * the strings stay out of the ViewModels and are resolved in composition from `JobStrings`
 * (PR #452, mirroring the `ContactFeedback` enum). The screen turns one into display text via
 * `JobStrings.resolve`.
 *
 * Lives in `domain/model` (next to [JobActionError]) rather than `presentation` because the shared
 * `JobActionStore` (`data/`) carries these too, and `data` may depend on `domain` but not on
 * `presentation`.
 */
sealed interface JobMessage {
    /** 2xx `accept_job` success toast. */
    data object JobAccepted : JobMessage

    /** 2xx `deny_job` success toast. */
    data object JobDenied : JobMessage

    /** HTTP 409 — the job was reassigned to another expert. */
    data object Reassigned : JobMessage

    /** Generic action failure ("Something went wrong…"). */
    data object Generic : JobMessage

    /** Check-in `failure_type: LOCATION` — the runner isn't at the job location. */
    data object CheckInLocation : JobMessage

    /** Wrong OTP entered on check-in / checkout. */
    data object OtpIncorrect : JobMessage

    /**
     * The request never reached the backend (no internet / timeout / TLS) — a
     * [JobActionError.Network]. Distinct from [OtpIncorrect] so a check-in/checkout that failed on a
     * poor connection no longer reads as a wrong OTP (ECPO-1059).
     */
    data object NetworkError : JobMessage

    /** No-OTP phone check-in didn't match the booking number. */
    data object PhoneMismatch : JobMessage

    /** House-tasks Confirm tapped with nothing selected. */
    data object SelectTaskHint : JobMessage

    /** A server-supplied message ([JobActionError.Server]) shown verbatim. */
    data class Server(val text: String) : JobMessage
}
