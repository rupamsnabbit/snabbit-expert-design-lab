package com.snabbit.runner.shared.features.profile.data.remote.dto

import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for `GET api/v1/runners/me` — only the fields the Profile screen
 * needs. `@SerialName`s mirror Dart's `UserProfile.fromMap`: `name` is nested
 * under `user`; everything else is top-level; `app_config` is embedded (not a
 * separate call). Unknown keys are ignored by the data source's lenient JSON.
 */
@Serializable
internal data class RunnerProfileDto(
    @SerialName("user") val user: UserDto? = null,
    @SerialName("public_pic") val publicPic: String? = null,
    @SerialName("tier") val tier: String? = null,
    @SerialName("adm") val adm: String? = null,
    @SerialName("current_month_rating") val currentMonthRating: Double? = null,
    @SerialName("language_preference") val languagePreference: String? = null,
    @SerialName("pan_verified") val panVerified: Boolean? = null,
    @SerialName("bank_verified") val bankVerified: Boolean? = null,
    @SerialName("aadhaar_pan_linked") val aadhaarPanLinked: Boolean? = null,
    @SerialName("is_aadhaar_rekyc") val isAadhaarRekyc: Boolean? = null,
    @SerialName("pan") val pan: String? = null,
    @SerialName("bank_account_number") val bankAccountNumber: String? = null,
    @SerialName("bank_ifsc_code") val bankIfscCode: String? = null,
    @SerialName("is_loan_eligible") val isLoanEligible: Boolean? = null,
    @SerialName("is_rate_card_v2_effective") val isRateCardV2Effective: Boolean? = null,
    @SerialName("has_lower_earnings_in_new_rate_card") val hasLowerEarningsInNewRateCard: Boolean? = null,
    // Vishwaas banner gate + switch-RC analytics cohort props.
    @SerialName("rate_card") val rateCard: String? = null,
    @SerialName("rate_card_version") val rateCardVersion: String? = null,
    @SerialName("rate_card_optin_month") val rateCardOptinMonth: String? = null,
    @SerialName("cluster_id") val clusterId: Long? = null,
    @SerialName("region_id") val regionId: Long? = null,
    @SerialName("app_config") val appConfig: RunnerAppConfigDto? = null,
) {
    fun toDomain(): RunnerProfile = RunnerProfile(
        name = user?.name,
        expertId = user?.id,
        photoUrl = publicPic,
        tier = tier,
        deliveryMethod = adm,
        currentMonthRating = currentMonthRating,
        languagePreference = languagePreference,
        isPanVerified = panVerified == true,
        isBankVerified = bankVerified == true,
        isPanAadhaarLinked = aadhaarPanLinked == true,
        isAadhaarRekyc = isAadhaarRekyc == true,
        pan = pan,
        bankAccountNumber = bankAccountNumber,
        bankIfscCode = bankIfscCode,
        isLoanEligible = isLoanEligible == true,
        isWashroomFinderEnabled = appConfig?.isWashroomFinderEnabled == true,
        sevaUrl = appConfig?.webViews?.seva,
        isMerchStoreEnabled = appConfig?.isMerchStoreEnabled == true,
        merchStoreUrl = appConfig?.webViews?.merchStore,
        showSilentNotification = appConfig?.showSilentNotification == true,
        showEarlyPayout = appConfig?.payrollConfig?.showEarlyPayout == true,
        showTransactionHistory = appConfig?.payrollConfig?.showTransactionHistory == true,
        isRateCardV2Effective = isRateCardV2Effective == true,
        hasLowerEarningsInNewRateCard = hasLowerEarningsInNewRateCard == true,
        rateCard = rateCard,
        rateCardVersion = rateCardVersion,
        rateCardOptinMonth = rateCardOptinMonth,
        clusterId = clusterId,
        regionId = regionId,
    )
}

/** Runner identity block (`user`) — `name` + the numeric runner/expert `id` (shown as "#id"). */
@Serializable
internal data class UserDto(
    @SerialName("name") val name: String? = null,
    @SerialName("id") val id: Long? = null,
)

/** Embedded `app_config` — the payout/seva/merch gates the Profile tiles read. */
@Serializable
internal data class RunnerAppConfigDto(
    @SerialName("payroll_config") val payrollConfig: PayrollConfigDto? = null,
    @SerialName("is_washroom_finder_enabled") val isWashroomFinderEnabled: Boolean? = null,
    @SerialName("is_merch_store_enabled") val isMerchStoreEnabled: Boolean? = null,
    @SerialName("show_silent_notification") val showSilentNotification: Boolean? = null,
    @SerialName("web_views") val webViews: WebViewsDto? = null,
)

@Serializable
internal data class PayrollConfigDto(
    @SerialName("show_early_payout") val showEarlyPayout: Boolean? = null,
    @SerialName("show_transaction_history") val showTransactionHistory: Boolean? = null,
)

@Serializable
internal data class WebViewsDto(
    @SerialName("seva") val seva: String? = null,
    @SerialName("merch_store") val merchStore: String? = null,
)
