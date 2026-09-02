package com.snabbit.runner.shared.features.seva.domain.model

/**
 * A single "Seva" facility near the runner — a washroom or a resting place —
 * decoded from `GET /seva/nearby`. Plotted as a marker on the Home map
 * background; tapping one surfaces its name / road / distance in the seva
 * helper card.
 *
 * Coordinates are plain doubles (mirrors [com.snabbit.runner.shared.features.shift.core.domain.model.Hotspot])
 * so this domain model stays free of any presentation `MapCoords` dependency —
 * the map layer converts at the call site.
 *
 * MVP carries only what the marker + helper card render. Resting-only extras
 * (photos, contact) are parsed by the DTO but deliberately dropped here until
 * the card design confirms them (ponytail: see [SevaKind]).
 */
data class SevaPoint(
    val id: String,
    val name: String,
    val category: String,
    val lat: Double,
    val lng: Double,
    val road: String,
    val distanceMeters: Int,
    val kind: SevaKind,
)

/** Which `/seva/nearby` array the point came from. MVP renders one marker icon
 *  for both (the DS ships a single `seva_marker` asset); distinct icons land
 *  when the assets do. */
enum class SevaKind { Washroom, Resting }
