package com.snabbit.runner.shared.features.loan.data.remote.dto

import com.snabbit.runner.shared.features.loan.domain.model.LoanDetails
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for `GET api/v1/runners/me/loan_details` — mirrors Dart's
 * `LoanDetails.fromJson`. Unknown keys are ignored by the data source's lenient
 * JSON; missing flags default to the safe value.
 */
@Serializable
internal data class LoanDetailsDto(
    @SerialName("is_early_payout_taken") val isEarlyPayoutTaken: Boolean? = null,
    @SerialName("is_loan_processed") val isLoanProcessed: Boolean? = null,
    @SerialName("vendor_url") val vendorUrl: String? = null,
) {
    fun toDomain(): LoanDetails = LoanDetails(
        isEarlyPayoutTaken = isEarlyPayoutTaken == true,
        isLoanProcessed = isLoanProcessed == true,
        vendorUrl = vendorUrl.orEmpty(),
    )
}
