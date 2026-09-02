package com.snabbit.runner.shared.features.seva.data.remote.dto

import com.snabbit.runner.shared.features.seva.domain.model.SevaKind
import com.snabbit.runner.shared.features.seva.domain.model.SevaPoint
import kotlinx.serialization.Serializable

/**
 * Wire shape for `GET /seva/nearby`. JSON keys are camelCase and match the
 * Kotlin property names, so no `@SerialName` is needed. The `Json` instance
 * decoding this uses `ignoreUnknownKeys`, so the `radius` echo costs nothing
 * to leave in.
 *
 * `userLat/userLng` are the origin the per-point `dLat/dLng` deltas are
 * measured from — [toDomain] rebases each point to `userLat + dLat` /
 * `userLng + dLng` to get an absolute coordinate for the map marker.
 *
 * Both arrays are `[]` (never null) when nothing is in range — the default
 * keeps decode total. [toDomain] flattens them into one `List<SevaPoint>`,
 * tagging each with its [SevaKind].
 */
@Serializable
internal data class SevaNearbyDto(
    val userLat: Double = 0.0,
    val userLng: Double = 0.0,
    val washrooms: List<SevaPointDto> = emptyList(),
    val restingPlaces: List<SevaPointDto> = emptyList(),
) {
    fun toDomain(): List<SevaPoint> =
        washrooms.map { it.toDomain(SevaKind.Washroom, userLat, userLng) } +
            restingPlaces.map { it.toDomain(SevaKind.Resting, userLat, userLng) }
}

/**
 * A single point from either array. `id`, `dLat`, `dLng` are required — a
 * point missing them is malformed and fails the whole decode (surfaced as a
 * synthetic HttpError → empty list upstream). Everything else defaults so a
 * sparse washroom entry still parses.
 *
 * `dLat`/`dLng` are offsets from the request origin, not absolute coords —
 * [toDomain] adds the `userLat`/`userLng` base to resolve the real position.
 *
 * Resting-only fields (`photos`, `contact*`) are parsed but unused in MVP —
 * they exist so the wire contract round-trips and the card can pick them up
 * later without a DTO change.
 */
@Serializable
internal data class SevaPointDto(
    val id: String,
    val name: String = "",
    val category: String = "",
    val dLat: Double,
    val dLng: Double,
    val road: String = "",
    val distance: Int = 0,
    val photos: List<String> = emptyList(),
    val contactName: String? = null,
    val contactNumber: String? = null,
    val contactDetail: String? = null,
) {
    fun toDomain(kind: SevaKind, userLat: Double, userLng: Double): SevaPoint = SevaPoint(
        id = id,
        name = name,
        category = category,
        lat = userLat + dLat,
        lng = userLng + dLng,
        road = road,
        distanceMeters = distance,
        kind = kind,
    )
}
