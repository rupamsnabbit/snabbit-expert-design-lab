package com.snabbit.runner.shared.features.tiering.data

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import com.snabbit.runner.shared.features.tiering.data.mapper.toDomain
import com.snabbit.runner.shared.features.tiering.data.remote.dto.TierCoinsDto
import com.snabbit.runner.shared.features.tiering.data.remote.dto.TierNudgeDto
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsData
import com.snabbit.runner.shared.features.tiering.domain.model.TierNudge
import com.snabbit.runner.shared.features.tiering.domain.model.TieringProfile
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull

/**
 * Default [TieringDataSource]: folds the Dart-fed [RunnerStateStore] envelope +
 * [RunnerProfileStore] into the tiering read models. Decoding runs on
 * [AppDispatchers.default]; a malformed slice degrades to null / empty defaults
 * (breadcrumb only) so a transient bad payload never crashes a collector.
 */
class DefaultTieringDataSource(
    private val runnerState: RunnerStateStore,
    private val profileStore: RunnerProfileStore,
    private val dispatchers: AppDispatchers,
    private val currentTimeMs: CurrentTimeMs,
    private val logger: Logger,
) : TieringDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override val nudge: Flow<TierNudge?> =
        runnerState.envelope.map { decodeNudge(it) }.flowOn(dispatchers.default)

    // Observe the raw body (NOT profileStore.state): `state` dedupes on the decoded RunnerProfile,
    // which drops the tiering-only fields — so a `has_viewed_intro` / `tier_effective_date` change
    // (intro watched, promotion becomes effective) would be swallowed and the tiering UI would never
    // update. Triggering on the raw body also collapses the old trigger≠source read into one value.
    override val profile: Flow<TieringProfile> =
        profileStore.rawProfile.map { decodeProfile(it) }.flowOn(dispatchers.default)

    override val widgetName: Flow<String?> =
        runnerState.state.map { it?.widgetName }

    override fun coins(nudge: TierNudge): TierCoinsData? {
        val details = nudge.nudgeDetails ?: return null
        return runCatching {
            json.decodeFromJsonElement(TierCoinsDto.serializer(), details).toDomain()
        }.getOrElse {
            logger.e(TAG, "coins decode failed", it)
            null
        }
    }

    /** Decode the top-level `tier_nudge` sibling from the raw `current_state` envelope. */
    private fun decodeNudge(envelope: JsonObject?): TierNudge? {
        val element = envelope?.get(KEY_TIER_NUDGE) ?: return null
        if (element is JsonNull) return null
        return runCatching {
            json.decodeFromJsonElement(TierNudgeDto.serializer(), element).toDomain()
        }.getOrElse {
            logger.e(TAG, "tier_nudge decode failed", it)
            null
        }
    }

    /**
     * Decodes the tiering slice of the raw `runners/me` body **field-by-field** with tolerant
     * primitive reads — mirroring Flutter's `as T? ?? default` / `.toString()` parsing.
     *
     * Deliberately NOT a strict `@Serializable` DTO decode: kotlinx decodes the whole object
     * atomically, so ONE unexpected field — a present-but-null `has_viewed_intro`, a
     * `service_id` / `tier_effective_date` of the wrong JSON type — threw, and the old
     * `getOrElse` fell back to an EMPTY profile. That nulled `tier` and hid EVERY tiering
     * surface even for a fully-eligible runner (the "nudges + tiers invisible" bug). Here a bad
     * field only nulls itself; `tier` (and the rest) still resolve — [optString] / [optBoolean]
     * / [optInt] never throw.
     */
    private fun decodeProfile(raw: JsonObject?): TieringProfile {
        if (raw == null) return TieringProfile()
        return TieringProfile(
            tier = Tier.fromWire(raw.optString(KEY_TIER)),
            hasViewedIntro = raw.optBoolean(KEY_HAS_VIEWED_INTRO) ?: false,
            isTieringEnabled = isEnabled(raw.optString(KEY_TIER_EFFECTIVE_DATE)),
            serviceId = raw.optInt(KEY_SERVICE_ID),
            isSuspended = raw.optString(KEY_STATUS)?.trim()?.uppercase() == STATUS_SUSPENDED,
        )
    }

    // Tolerant single-field reads: a missing key, JSON null, or non-primitive / wrong-typed value
    // yields null instead of throwing — so one bad field can't take the whole slice down with it.
    private fun JsonObject.optString(key: String): String? = (this[key] as? JsonPrimitive)?.contentOrNull
    private fun JsonObject.optBoolean(key: String): Boolean? = (this[key] as? JsonPrimitive)?.booleanOrNull
    private fun JsonObject.optInt(key: String): Int? = (this[key] as? JsonPrimitive)?.intOrNull

    /**
     * Mirrors Flutter `UserProfile.isTieringEnabled`: the effective date is
     * on/before today, evaluated in the **device-local** zone (Flutter uses a
     * local `DateTime`, so KMP matches it rather than pinning to IST).
     */
    private fun isEnabled(effectiveRaw: String?): Boolean {
        val effective = parseDate(effectiveRaw) ?: return false
        return effective <= today()
    }

    /** Lenient parse — a full instant/timestamp first, then a bare `yyyy-MM-dd`; unparseable → null. */
    private fun parseDate(raw: String?): LocalDate? {
        if (raw.isNullOrBlank()) return null
        val zone = TimeZone.currentSystemDefault()
        return runCatching { Instant.parse(raw).toLocalDateTime(zone).date }.getOrNull()
            ?: runCatching { LocalDate.parse(raw.take(DATE_LEN)) }.getOrNull()
    }

    private fun today(): LocalDate =
        Instant.fromEpochMilliseconds(currentTimeMs()).toLocalDateTime(TimeZone.currentSystemDefault()).date

    private companion object {
        const val TAG = "TieringDataSource"
        const val KEY_TIER_NUDGE = "tier_nudge"
        const val KEY_TIER = "tier"
        const val KEY_TIER_EFFECTIVE_DATE = "tier_effective_date"
        const val KEY_HAS_VIEWED_INTRO = "has_viewed_intro"
        const val KEY_SERVICE_ID = "service_id"
        const val KEY_STATUS = "status"
        const val DATE_LEN = 10 // "yyyy-MM-dd"
        const val STATUS_SUSPENDED = "SUSPENDED"
    }
}
