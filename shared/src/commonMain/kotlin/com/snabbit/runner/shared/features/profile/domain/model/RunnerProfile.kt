package com.snabbit.runner.shared.features.profile.domain.model

/**
 * The runner's profile as the Profile screen needs it — the fields that drive the
 * header, each section tile's visibility gate, and the top nudge carousel.
 *
 * Sourced from `GET api/v1/runners/me` (the `app_config` object is embedded in
 * that response, not a separate call). Pure domain data — no serialization, no
 * platform types — so `commonMain` stays iOS-safe. The DTO + mapper live in
 * `data/`.
 *
 * Note: `pan` / `bankAccountNumber` / `bankIfscCode` ARE available but are
 * deliberately not surfaced as detail rows (product decision: Bank/PAN stay
 * nudge-only when unverified). They're kept here for completeness / future use.
 */
data class RunnerProfile(
    // Header
    val name: String?,
    val expertId: Long? = null,
    val photoUrl: String?,
    val tier: String?,
    val deliveryMethod: String?,
    val currentMonthRating: Double?,
    val languagePreference: String?,
    // Verification state (drives the top nudge carousel)
    val isPanVerified: Boolean,
    val isBankVerified: Boolean,
    val isPanAadhaarLinked: Boolean,
    val isAadhaarRekyc: Boolean,
    // Present but not displayed (nudge-only decision)
    val pan: String?,
    val bankAccountNumber: String?,
    val bankIfscCode: String?,
    // Section-tile visibility gates
    val isLoanEligible: Boolean,
    val isWashroomFinderEnabled: Boolean,
    val sevaUrl: String?,
    val isMerchStoreEnabled: Boolean,
    val merchStoreUrl: String?,
    val showEarlyPayout: Boolean,
    val showTransactionHistory: Boolean,
    val isRateCardV2Effective: Boolean,
    val hasLowerEarningsInNewRateCard: Boolean,
    val showSilentNotification: Boolean = false,
    // Vishwaas banner gate (rateCardVersion) + switch-RC analytics cohort props.
    val rateCard: String? = null,
    val rateCardVersion: String? = null,
    val rateCardOptinMonth: String? = null,
    val clusterId: Long? = null,
    val regionId: Long? = null,
) {
    /**
     * Rate card v1 unless the version is explicitly "V2" (mirrors Dart's
     * `parseRateCardVersion` — null/blank/unknown all fall back to v1). Drives
     * the Vishwaas banner gate (`shouldShowVishwaasBanner` = on v1).
     */
    val isRateCardV1: Boolean get() = !"V2".equals(rateCardVersion?.trim(), ignoreCase = true)
    /** Runner/expert id for the header — "#<id>" (e.g. "#2413"); null when unknown. */
    val displayId: String? get() = expertId?.let { "#$it" }

    /** Seva tile shows only when enabled AND a URL is present (Dart parity). */
    val showSeva: Boolean get() = isWashroomFinderEnabled && !sevaUrl.isNullOrBlank()

    /** Snabbit-store (merch) tile shows only when enabled AND a URL is present. */
    val showMerchStore: Boolean get() = isMerchStoreEnabled && !merchStoreUrl.isNullOrBlank()

    /** Verification nudges (top carousel) — one per unmet requirement. */
    val hasBankNudge: Boolean get() = !isBankVerified
    val hasPanNudge: Boolean get() = !isPanVerified
    val hasPanAadhaarNudge: Boolean get() = !isPanAadhaarLinked
    val hasAadhaarRekycNudge: Boolean get() = isAadhaarRekyc
}
