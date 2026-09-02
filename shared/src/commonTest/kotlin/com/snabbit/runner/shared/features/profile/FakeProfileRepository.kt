package com.snabbit.runner.shared.features.profile

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import com.snabbit.runner.shared.features.profile.domain.repository.ProfileRepository

/**
 * Test fake for [ProfileRepository]. Default returns [sampleRunnerProfile] so VM
 * tests don't need to enqueue for the happy path. Push canned responses via
 * [enqueue] (FIFO). Records each call in [callCount].
 */
class FakeProfileRepository : ProfileRepository {

    private val responses: ArrayDeque<Result<RunnerProfile, RunnerActionError>> = ArrayDeque()
    var callCount: Int = 0
        private set

    fun enqueue(result: Result<RunnerProfile, RunnerActionError>) {
        responses.addLast(result)
    }

    override suspend fun getProfile(): Result<RunnerProfile, RunnerActionError> {
        callCount++
        return responses.removeFirstOrNull() ?: Result.Ok(sampleRunnerProfile())
    }
}

/** Convenience builder for a [RunnerProfile] in tests — override only what matters. */
fun sampleRunnerProfile(
    name: String? = "Test Runner",
    expertId: Long? = null,
    photoUrl: String? = null,
    tier: String? = null,
    deliveryMethod: String? = null,
    currentMonthRating: Double? = null,
    languagePreference: String? = null,
    isPanVerified: Boolean = true,
    isBankVerified: Boolean = true,
    isPanAadhaarLinked: Boolean = true,
    isAadhaarRekyc: Boolean = false,
    pan: String? = null,
    bankAccountNumber: String? = null,
    bankIfscCode: String? = null,
    isLoanEligible: Boolean = false,
    isWashroomFinderEnabled: Boolean = false,
    sevaUrl: String? = null,
    isMerchStoreEnabled: Boolean = false,
    merchStoreUrl: String? = null,
    showEarlyPayout: Boolean = false,
    showTransactionHistory: Boolean = false,
    isRateCardV2Effective: Boolean = false,
    hasLowerEarningsInNewRateCard: Boolean = false,
    showSilentNotification: Boolean = false,
    rateCard: String? = null,
    rateCardVersion: String? = null,
    rateCardOptinMonth: String? = null,
    clusterId: Long? = null,
    regionId: Long? = null,
): RunnerProfile = RunnerProfile(
    name = name,
    expertId = expertId,
    photoUrl = photoUrl,
    tier = tier,
    deliveryMethod = deliveryMethod,
    currentMonthRating = currentMonthRating,
    languagePreference = languagePreference,
    isPanVerified = isPanVerified,
    isBankVerified = isBankVerified,
    isPanAadhaarLinked = isPanAadhaarLinked,
    isAadhaarRekyc = isAadhaarRekyc,
    pan = pan,
    bankAccountNumber = bankAccountNumber,
    bankIfscCode = bankIfscCode,
    isLoanEligible = isLoanEligible,
    isWashroomFinderEnabled = isWashroomFinderEnabled,
    sevaUrl = sevaUrl,
    isMerchStoreEnabled = isMerchStoreEnabled,
    merchStoreUrl = merchStoreUrl,
    showEarlyPayout = showEarlyPayout,
    showTransactionHistory = showTransactionHistory,
    isRateCardV2Effective = isRateCardV2Effective,
    hasLowerEarningsInNewRateCard = hasLowerEarningsInNewRateCard,
    showSilentNotification = showSilentNotification,
    rateCard = rateCard,
    rateCardVersion = rateCardVersion,
    rateCardOptinMonth = rateCardOptinMonth,
    clusterId = clusterId,
    regionId = regionId,
)
