package com.snabbit.runner.shared.features.home.suspended.domain.model

/**
 * Typed read model for the `RUNNER_SUSPENDED` state — emitted by
 * `SuspendedProjector` when the runner is suspended, `null` otherwise.
 *
 * [isAadhaarRekyc] selects the Home suspended-card variant (documents-verifying
 * vs Aadhaar re-KYC). [isRateCardV2Effective] selects where "Go to Earnings"
 * lands (monthly-summary webview vs native Payout Home) — Dart parity with
 * `navigateToEarningsPage`. Both are read from the bridge-fed `runners/me`
 * profile ([com.snabbit.runner.shared.features.profile.RunnerProfileStore]);
 * they degrade to `false` when the profile hasn't been pushed yet.
 *
 * Kept as its own model (not a bare `Boolean`) so later parity additions from
 * `widget_data` (e.g. a suspension reason) extend it without reshaping the
 * projector's stream.
 */
data class SuspendedInfo(
    val isAadhaarRekyc: Boolean,
    val isRateCardV2Effective: Boolean,
)
