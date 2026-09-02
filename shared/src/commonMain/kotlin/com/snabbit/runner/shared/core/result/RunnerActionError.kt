package com.snabbit.runner.shared.core.result

/**
 * Domain failure mode for runner write actions against the backend. Feature
 * repositories (attendance, shift, …) collapse the data-layer `NetworkError`
 * (HTTP vs transport) into these cases so domain + presentation never see Ktor
 * / HTTP types — the UI just picks a snackbar string + retry policy.
 *
 * Shared rather than per-feature because the categories are network-shape
 * (status-code buckets), not feature-specific, and `HomeViewModel.launchAction`
 * needs one error type to dispatch a mix of attendance + shift use cases.
 */
sealed interface RunnerActionError {
    /** No network / DNS / SSL / timeout. UI: "Check your connection". */
    data object NoConnection : RunnerActionError

    /** 401 / 403. UI: "Session expired" (Dart's auth refresh will recover next poll). */
    data object Unauthorized : RunnerActionError

    /** 5xx — server is broken. UI: "Something went wrong, try again". */
    data object Server : RunnerActionError

    /**
     * Any other 4xx, or an unexpected condition. [statusCode] is null for
     * non-HTTP failures the data layer couldn't classify.
     */
    data class Unknown(val statusCode: Int? = null) : RunnerActionError
}
