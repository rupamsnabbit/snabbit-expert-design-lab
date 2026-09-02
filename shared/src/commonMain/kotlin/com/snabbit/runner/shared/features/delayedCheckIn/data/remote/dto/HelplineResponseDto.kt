package com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Response body for `GET api/v1/runners/me/helpline`. Wire shape matches
 * what `RunnerHttp.runnersMeHelpline` / `JobSupportBottomSheet` read on the
 * Dart side (`response.data['ph_no']` — see
 * `lib/widgets/delayed_checkin/job_support_bottom_sheet.dart`, read-only).
 */
@Serializable
data class HelplineResponseDto(
    @SerialName("ph_no") val phoneNumber: String? = null,
)
