package com.snabbit.runner.shared.features.loan.domain.model

/**
 * The runner's loan eligibility/status, as the Get-loan bottom sheet needs it
 * (`GET api/v1/runners/me/loan_details`). Pure domain — no serialization.
 *
 * The sheet renders one of three outcomes from these flags (mirrors the Flutter
 * `showLoanUnifiedSheet`):
 *  - [isEarlyPayoutTaken] → "loan not available, you took Early Payout".
 *  - [isLoanProcessed]    → "already processed", CTA opens [vendorUrl].
 *  - otherwise (eligible) → open [vendorUrl] directly (no interstitial).
 */
data class LoanDetails(
    val isEarlyPayoutTaken: Boolean,
    val isLoanProcessed: Boolean,
    val vendorUrl: String,
)
