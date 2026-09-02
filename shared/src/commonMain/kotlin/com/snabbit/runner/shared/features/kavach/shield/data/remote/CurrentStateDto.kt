package com.snabbit.runner.shared.features.kavach.shield.data.remote

import com.snabbit.runner.shared.features.job.data.asIntOrNull
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

/**
 * `GET api/v1/runners/me/app/current_state` — full envelope. `widget_data` is polymorphic per
 * widget, so it is kept RAW ([JsonObject], nothing truncated) and the shield view is decoded
 * on demand via [ShieldWidgetSlice]. This is the faithful "full payload": the envelope is typed
 * and the entire widget payload is preserved verbatim.
 */
@Serializable
data class CurrentStateDto(
    @SerialName("widget_name") val widgetName: String? = null,
    @SerialName("widget_data") val widgetData: JsonObject? = null,
)

/** The shield-relevant view of `widget_data`. */
@Serializable
data class ShieldWidgetSlice(
    @SerialName("snabbit_shield_consent_enabled") val customerConsentEnabled: Boolean = false,
    @SerialName("snabbit_shield_auto_enabled") val autoEnabled: Boolean = false,
    @SerialName("job_id") val jobId: JsonElement? = null,
)

/**
 * job_id tolerates int / double (`650.0`) / numeric string. Delegates to the job feature's canonical
 * [asIntOrNull] so kavach and JobProjector parse job_id identically — the previous local parser
 * lacked its `.trim()`, so a whitespace-padded `" 650 "` read as null here while the coordinator saw
 * a live job, and the shield silently never armed.
 */
fun ShieldWidgetSlice.jobIdAsInt(): Int? = jobId.asIntOrNull()
