package com.snabbit.runner.shared.features.home.presentation.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import com.google.android.gms.maps.GoogleMapOptions
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.maps.android.compose.CameraPositionState
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapEffect
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapType
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.rememberCameraPositionState
import com.snabbit.design.theme.SnabbitTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot

// Google Maps greyscale style — one rule desaturates every layer + label.
// Lite Mode applies this before snapshotting the tile bitmap, so the whole
// map paints black-and-white for free.
private const val MAP_STYLE_GREYSCALE_JSON = "[{\"stylers\":[{\"saturation\":-100}]}]"

// Re-centre only once the runner has actually moved this far. Every Lite-Mode
// camera move triggers a fresh server-side bitmap fetch (the map goes grey
// until it lands), and the GPS fix jitters a few metres every tick — so
// following it verbatim re-snapshots forever and the map never settles. 40m is
// well below what's visible on a zoom-16.8 backdrop.
private const val CAMERA_MOVE_THRESHOLD_M = 40.0

// Single-slot disk cache of the last rendered map bitmap, shown as an instant
// placeholder on the next cold start so first paint isn't the grey grid while
// the live Lite-Mode snapshot fetches.
// ponytail: one slot, last-render-wins — a runner who relocates cities sees the
// old view for the ~1 frame until the live map loads and overwrites it. Key the
// filename by rounded coords if per-location freshness ever matters.
private const val MAP_SNAPSHOT_CACHE_FILE = "home_map_snapshot.png"

/**
 * Android actual — [GoogleMap] in Lite Mode + Compose-drawn overlays.
 *
 * Everything above the map (halo, current-location disc, seva pins) is Compose
 * and lives in [MapMarkers.kt] (commonMain) so an iOS actual can reuse the
 * exact same overlay layer over a MapKit surface. Only the map surface + its
 * greyscale styling stays platform-specific here.
 *
 * The camera tracks [coordinates] (the runner's location) but only jumps past
 * [CAMERA_MOVE_THRESHOLD_M] — see that const for why. Markers project against
 * the same gated [camera] so they stay pinned to what's actually drawn. Each
 * [sevaMarkers] pin is placed via [latLngToScreenOffsetPx] — a straight
 * Web-Mercator projection, no `Projection.toScreenLocation` roundtrip (lags on
 * first frame in Lite Mode).
 */
@Composable
actual fun MapBackground(
    modifier: Modifier,
    coordinates: MapCoords,
    sevaMarkers: List<SevaMarker>,
    onSevaClick: (String) -> Unit,
    profilePhotoUrl: String?,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // B: the drawn camera. Advances to the live fix only past the move
    // threshold, so a stationary/​jittering runner keeps one settled snapshot.
    var camera by remember { mutableStateOf(coordinates) }
    LaunchedEffect(coordinates) {
        if (distanceMeters(camera, coordinates) > CAMERA_MOVE_THRESHOLD_M) {
            camera = coordinates
        }
    }

    val latLng = LatLng(camera.latitude, camera.longitude)
    val cameraPositionState: CameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(latLng, CAMERA_ZOOM)
    }
    // Lite Mode has no camera animation — set the position directly (instant
    // re-snapshot). Only fires when [camera] crossed the threshold above.
    LaunchedEffect(latLng) {
        cameraPositionState.position = CameraPosition.fromLatLngZoom(latLng, CAMERA_ZOOM)
    }
    val brand = SnabbitTheme.colors.iconBrand
    val density = LocalDensity.current.density

    // Pre-project each pin to a device-pixel offset from the gated camera
    // centre. Keyed on camera + markers + density so it only recomputes on a
    // real change.
    val markerOffsets = remember(camera, density, sevaMarkers) {
        sevaMarkers.map { marker ->
            marker to latLngToScreenOffsetPx(
                camera = camera,
                target = marker.coords,
                zoom = CAMERA_ZOOM,
                density = density,
            )
        }
    }

    // True once the live map has drawn its tiles; until then we cover the grey
    // grid with the cached snapshot (if any).
    var mapLoaded by remember { mutableStateOf(false) }
    val cachedSnapshot by produceState<ImageBitmap?>(initialValue = null, context) {
        value = withContext(Dispatchers.IO) { loadCachedSnapshot(context) }
    }

    Box(modifier = modifier) {
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            // Seed the camera at MapView creation: without it, Lite Mode's first
            // one-shot bitmap fetch happens at Google's default camera (lat 0 /
            // lng 0 / zoom 0 = world map), which flashes until cameraPositionState
            // is applied and a second fetch lands. Runs once per MapView, so on a
            // tab return it captures the VM-retained centre — no world frame.
            googleMapOptionsFactory = {
                GoogleMapOptions()
                    .liteMode(true)
                    .camera(CameraPosition.fromLatLngZoom(latLng, CAMERA_ZOOM))
            },
            properties = MapProperties(
                mapType = MapType.NORMAL,
                mapStyleOptions = MapStyleOptions(MAP_STYLE_GREYSCALE_JSON),
            ),
            uiSettings = MapUiSettings(
                compassEnabled = false,
                indoorLevelPickerEnabled = false,
                mapToolbarEnabled = false,
                myLocationButtonEnabled = false,
                rotationGesturesEnabled = false,
                scrollGesturesEnabled = false,
                scrollGesturesEnabledDuringRotateOrZoom = false,
                tiltGesturesEnabled = false,
                zoomControlsEnabled = false,
                zoomGesturesEnabled = false,
            ),
            onMapLoaded = { mapLoaded = true },
        ) {
            // Best-effort: once tiles are up, cache the rendered bitmap for the
            // next cold start. Snapshot/onMapLoaded may no-op in Lite Mode on
            // some renderers — if so this simply never populates and the
            // placeholder stays empty (today's behaviour), no regression.
            MapEffect(mapLoaded) { map ->
                if (mapLoaded) {
                    runCatching {
                        map.snapshot { bmp ->
                            if (bmp != null) {
                                scope.launch { saveCachedSnapshot(context, bmp) }
                            }
                        }
                    }
                }
            }
        }
        // Cold-start placeholder: last-rendered map, shown until the live map
        // reports its tiles. Above the grey GoogleMap surface, below the markers.
        val placeholder = cachedSnapshot
        if (!mapLoaded && placeholder != null) {
            Image(
                bitmap = placeholder,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }
        // Lite Mode maps launch the Google Maps app on tap by default. Swallow
        // taps on the map surface with a transparent overlay so only the seva
        // pins (drawn ABOVE this) stay interactive.
        Box(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(Unit) { detectTapGestures { } },
        )
        // Markers only once the live map reports its tiles. Their positions are
        // computed against the CURRENT camera, so drawing them over the grey grid
        // — or worse, over the cached snapshot from wherever the runner was last
        // time — puts pins on a map that isn't theirs.
        if (mapLoaded) {
            HaloRings(color = brand, modifier = Modifier.fillMaxSize())
            CurrentLocationMarker(
                color = brand,
                photoUrl = profilePhotoUrl,
                modifier = Modifier.align(Alignment.Center),
            )
            markerOffsets.forEach { (marker, offset) ->
                PulsingSevaMarker(
                    onClick = { onSevaClick(marker.id) },
                    selected = marker.selected,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .offset { offset },
                )
            }
        }
    }
}

/** Flat-earth metre distance between two fixes — ample for a 40m backdrop gate,
 *  no haversine needed at city scale. */
private fun distanceMeters(a: MapCoords, b: MapCoords): Double {
    val dLat = (b.latitude - a.latitude) * 111_320.0
    val dLng = (b.longitude - a.longitude) * 111_320.0 * cos(a.latitude * PI / 180.0)
    return hypot(dLat, dLng)
}

private fun loadCachedSnapshot(context: Context): ImageBitmap? = runCatching {
    val file = File(context.cacheDir, MAP_SNAPSHOT_CACHE_FILE)
    if (!file.exists()) return null
    BitmapFactory.decodeFile(file.absolutePath)?.asImageBitmap()
}.getOrNull()

private suspend fun saveCachedSnapshot(context: Context, bitmap: Bitmap) {
    withContext(Dispatchers.IO) {
        runCatching {
            File(context.cacheDir, MAP_SNAPSHOT_CACHE_FILE).outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
            }
        }
    }
}
