package com.snabbit.runner.shared.features.job.domain.model

/**
 * Canonical `widget_name` values for the JOB lifecycle — the subset of the
 * `current_state` envelope this module renders. Everything else (attendance,
 * login, lunch, logout, …) is out of scope and falls back to the legacy Dart UI
 * via [JobUiState.NotInJobFlow].
 *
 * Mirrors the Flutter `widgets_util.dart` switch + `AppStrings.postCheckoutWidgetName`.
 */
internal object JobWidgetName {
    const val NEW_JOB = "RUNNER_NEW_JOB"
    const val POST_ACCEPT = "RUNNER_JOB_POST_ACCEPT"
    const val CHECK_IN = "RUNNER_JOB_CHECK_IN"
    const val IN_PROGRESS = "RUNNER_JOB_IN_PROGRESS"
    const val POST_CHECKOUT = "RUNNER_POST_CHECKOUT"
}

/** Backend default for the accept countdown when `timer_duration` is absent (matches Flutter). */
internal const val DEFAULT_ACCEPT_TIMER_SEC = 120

/** Backend default for `checkout_before_mins` — remaining ≤ this·60 flips the in-progress timer to yellow. */
internal const val DEFAULT_CHECKOUT_BEFORE_MINS = 5
