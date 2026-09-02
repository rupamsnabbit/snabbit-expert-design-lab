package com.snabbit.runner.shared.features.home.presentation.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * Live map surface — Google Maps in **Lite Mode** on Android, empty stub on iOS.
 *
 * Lite Mode = one-shot bitmap of tiles, no gestures, no per-frame GL — the
 * cheapest possible map render on low-end devices. Together with the fixed
 * camera in [MapBackgroundDefaultCoords] this stays essentially free after
 * first paint.
 *
 * A single default pin sits at [coordinates] with a pulsing halo drawn on the
 * Compose layer above the map (not the map's own overlay pipeline — see the
 * Android actual). Pulse is a pure Compose infinite transition, so animating
 * it doesn't nudge the map tile snapshot.
 *
 * We removed `kmp-maps` because it wraps `GoogleMap()` without exposing
 * `googleMapOptionsFactory`, so `GoogleMapOptions().liteMode(true)` can't be
 * set — the whole point on low-end devices. iOS is Android-only in prod, so
 * the iOS actual is a compile-only Box stub.
 */
@Composable
expect fun MapBackground(
    modifier: Modifier = Modifier,
    coordinates: MapCoords = MapBackgroundDefaultCoords,
    sevaMarkers: List<SevaMarker> = emptyList(),
    onSevaClick: (String) -> Unit = {},
    /** Runner's profile photo, shown inside the "you are here" marker (falls
     *  back to the Person glyph while null/loading — see [CurrentLocationMarker]). */
    profilePhotoUrl: String? = null,
)

/** commonMain-safe lat/lng carrier so `MapBackground(...)` stays platform-free. */
data class MapCoords(val latitude: Double, val longitude: Double)

/** A Seva pin to plot on the map. [id] is echoed back through `onSevaClick` so
 *  the screen can look the tapped facility up in state. [selected] is set for
 *  the pin whose detail card is currently up, which swaps it to the filled
 *  marker art. */
data class SevaMarker(
    val id: String,
    val coords: MapCoords,
    val selected: Boolean = false,
)

/** Cap on plotted seva pins. Each pin is an [Image] with its own infinite pulse
 *  animation, so an unbounded `/seva/nearby` payload = one live animation per
 *  point. Within a 500 m radius the realistic count is far below this; the cap
 *  is a backstop, and the nearest ones are kept (they carry `distanceMeters`). */
const val MAX_SEVA_MARKERS = 12

// Neutral country-level fallback (approx. geographic centre of India) shown
// only for the brief moment before a real fix lands — the VM seeds the camera
// from the last-known GPS fix on init, and caller-supplied [coordinates] (from
// `Shift.hotspot` / live GPS) override it. Deliberately not a specific
// person's/dev's location.
val MapBackgroundDefaultCoords: MapCoords = MapCoords(latitude = 22.5937, longitude = 78.9629)
