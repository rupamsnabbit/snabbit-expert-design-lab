package com.snabbit.runner.shared.features.job.data.state

import com.snabbit.runner.shared.features.job.data.asBoolean
import com.snabbit.runner.shared.features.job.data.asDoubleOrNull
import com.snabbit.runner.shared.features.job.data.asIntOrNull
import com.snabbit.runner.shared.features.job.data.asStringOrNull
import com.snabbit.runner.shared.features.job.data.obj
import com.snabbit.runner.shared.features.job.domain.model.DEFAULT_ACCEPT_TIMER_SEC
import com.snabbit.runner.shared.features.job.domain.model.DEFAULT_CHECKOUT_BEFORE_MINS
import com.snabbit.runner.shared.features.job.domain.model.JobState
import com.snabbit.runner.shared.features.job.domain.model.JobCategory
import com.snabbit.runner.shared.features.job.domain.model.JobPayout
import com.snabbit.runner.shared.features.job.domain.model.JobPreference
import com.snabbit.runner.shared.features.job.domain.model.JobWidgetName
import com.snabbit.runner.shared.features.job.domain.model.NewJobModel
import com.snabbit.runner.shared.features.job.domain.model.PayoutBreakdownLine
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject

/**
 * Pure projection from the bridged `current_state` envelope to a raw domain [JobState].
 * Only JOB lifecycle widget_names are recognised; everything else (attendance, login,
 * lunch, logout) returns null so the caller can fall back to the legacy Dart UI.
 * Loading (nothing pushed yet) is decided by the caller from the nullable envelope.
 *
 * Kept a pure function (no ViewModel / scope / clock / formatting) so it is directly
 * unit-testable. Timing seeds and string formatting are applied later in JobState.toUiState.
 */
internal fun RunnerState.toJob(): JobState? {
    val data = widgetData
    return when (widgetName) {
        JobWidgetName.NEW_JOB -> JobState.New(parseNewJob(data))
        JobWidgetName.POST_ACCEPT, JobWidgetName.CHECK_IN ->
            JobState.AwaitingCheckIn(
                jobId = data?.get("job_id").asIntOrNull(),
                allowNoOtp = data?.get("allow_check_in_without_otp").asBoolean(),
                customerName = data?.get("customer_name").asStringOrNull(),
                customerPhone = data?.get("customer_ph_no").asStringOrNull(),
                address = data?.get("address").asStringOrNull(),
                geoAddress = data?.get("geo_address").asStringOrNull(),
                latitude = data?.get("lat").asDoubleOrNull(),
                longitude = data?.get("lng").asDoubleOrNull(),
                payout = parsePayout(data.obj("payout_info")),
                notifiedAtIso = data?.get("notified_at").asStringOrNull(),
                startTimeClock = data?.get("start_time").asStringOrNull(),
                checkInDeadlineIso = data?.get("checkin_promise").asStringOrNull(),
            )
        JobWidgetName.IN_PROGRESS ->
            JobState.InProgress(
                jobId = data?.get("job_id").asIntOrNull(),
                customerName = data?.get("customer_name").asStringOrNull(),
                customerPhone = data?.get("customer_ph_no").asStringOrNull(),
                startTimeIso = data?.get("start_time").asStringOrNull(),
                endTimeIso = data?.get("end_time").asStringOrNull(),
                durationMinutes = data?.get("duration").asIntOrNull(),
                preferences = parsePreferences(data.obj("cooking_preference")),
                nextJobReady = data?.get("next_job_ready").asBoolean(),
                showCheckoutOtp = data?.get("show_checkout_otp").asBoolean(),
                cashToBeCollected = data?.get("cash_to_be_collected").asBoolean(),
                // TODO(ECPO-528): confirm the campaign-image key with backend — null skips the campaign step.
                campaignImageUrl = data?.get("job_end_campaign_image").asStringOrNull(),
                checkoutBeforeMins = data?.get("checkout_before_mins").asIntOrNull()
                    ?: DEFAULT_CHECKOUT_BEFORE_MINS,
                autoCheckoutSeconds = data?.get("auto_checkout_seconds").asIntOrNull(),
            )
        JobWidgetName.POST_CHECKOUT ->
            JobState.Completed(
                jobId = data?.get("job_id").asIntOrNull(),
                customerId = data?.get("customer_id").asIntOrNull(),
                customerName = data?.get("customer_name").asStringOrNull(),
                customerAddress = data?.get("address").asStringOrNull(),
                payout = parsePayout(data.obj("payout_info")),
            )
        else -> null
    }
}

private fun parseNewJob(data: JsonObject?): NewJobModel = NewJobModel(
    jobId = data?.get("job_id").asIntOrNull(),
    isDeniable = data?.get("is_deniable").asBoolean(),
    isLastHourJob = data?.get("is_last_hour_job").asBoolean(),
    showDeallocationWarning = data?.get("show_deallocation_warning").asBoolean(),
    notifiedAtIso = data?.get("notified_at").asStringOrNull(),
    timerDurationSec = data?.get("timer_duration").asIntOrNull() ?: DEFAULT_ACCEPT_TIMER_SEC,
    denyRate = data?.get("deny_rate").asIntOrNull(),
    lossAmount = data?.get("loss_amount").asIntOrNull(),
    address = data?.get("address").asStringOrNull(),
    geoAddress = data?.get("geo_address").asStringOrNull(),
    isLongDistance = data?.get("is_long_distance").asBoolean(),
    category = parseCategory(data),
    payout = parsePayout(data.obj("payout_info")),
)

/** `title.key` the backend uses for the check-in bonus breakdown line — deduped in [parsePayout]. */
private const val CHECK_IN_BONUS_LINE_KEY = "check_in_bonus"

private fun parsePayout(payout: JsonObject?): JobPayout? {
    if (payout == null) return null
    val checkInAmount = payout["check_in_amount"].asIntOrNull()
    val rawLines = payout["breakdown"] as? JsonArray
    val lines = rawLines?.mapNotNull { element ->
        val line = element as? JsonObject ?: return@mapNotNull null
        val title = line["title"] as? JsonObject
        val subtitle = line["subtitle"] as? JsonObject
        PayoutBreakdownLine(
            labelKey = title?.get("key").asStringOrNull().orEmpty(),
            labelDefault = title?.get("default_text").asStringOrNull(),
            pillText = line["pill_text"].asStringOrNull(),
            iconUrl = line["icon_url"].asStringOrNull(),
            // Read the server copy (`subtitle.default_text`) exactly like the label above; params
            // substitution is not handled here (matches the current title behaviour).
            subtitle = subtitle?.get("default_text").asStringOrNull(),
            amount = line["amount"].asIntOrNull(),
        )
    }
        // The check-in bonus is shown once — as the derived "Check In by <time>" row built from
        // check_in_amount (see [JobPayout.lines]' contract: the check-in line is NOT in `lines`). If
        // the backend ALSO lists it as a `check_in_bonus` breakdown line, drop that so the earnings
        // accordion doesn't render the bonus twice. Only when check_in_amount is present (otherwise
        // the breakdown line is the sole representation, so it's kept).
        ?.filterNot { checkInAmount != null && it.labelKey == CHECK_IN_BONUS_LINE_KEY }
        ?: emptyList()
    return JobPayout(
        totalEarning = payout["total_earning"].asIntOrNull(),
        lines = lines,
        checkInAmount = checkInAmount,
        checkInTimeIso = payout["check_in_time"].asStringOrNull(),
    )
}

/**
 * `cooking_preference` map (`{ key: { title, value } }`) → ordered [JobPreference] rows, mirroring
 * the Flutter `CookingPreferenceDetails`: only object entries with a non-blank `value` are kept, the
 * label falls back to a humanised key when `title` is absent, and rows sort by key for a stable order.
 */
private fun parsePreferences(prefs: JsonObject?): List<JobPreference> {
    if (prefs == null) return emptyList()
    return prefs.keys.sorted().mapNotNull { key ->
        val entry = prefs[key] as? JsonObject ?: return@mapNotNull null
        val value = entry["value"].asStringOrNull()?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
        val label = entry["title"].asStringOrNull()?.takeIf { it.isNotBlank() } ?: humanizeKey(key)
        JobPreference(key = key, label = label, value = value)
    }
}

/** `spice_level` → "Spice Level" — the snake_case fallback label when the backend omits `title`. */
private fun humanizeKey(key: String): String =
    key.split('_').joinToString(" ") { part -> part.replaceFirstChar { it.uppercase() } }

/**
 * Expert vs Cook drives the header glyph only. The backing field is not yet
 * confirmed in the `current_state` contract — read a few plausible keys and
 * default to [JobCategory.Expert]. TODO(ECPO-528): pin the canonical field with
 * backend once the cook flow is wired.
 */
private fun parseCategory(data: JsonObject?): JobCategory {
    val raw = (data?.get("job_category") ?: data?.get("category") ?: data?.get("service_type"))
        .asStringOrNull()
        ?.lowercase()
    return if (raw != null && ("cook" in raw || "chef" in raw)) JobCategory.Cook else JobCategory.Expert
}
