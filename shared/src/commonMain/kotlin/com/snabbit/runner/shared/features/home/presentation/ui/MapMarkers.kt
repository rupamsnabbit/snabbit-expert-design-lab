@file:Suppress("ForbiddenImport") // white map-pin border/tint on map canvas — no DS map-overlay surface (DS_GAPS.md)

package com.snabbit.runner.shared.features.home.presentation.ui

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.snabbit.runner.shared.core.image.isNetworkImageUrl
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.seva_marker
import com.snabbit.runner.shared.resources.seva_marker_selected
import kotlin.math.PI
import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.sin
import org.jetbrains.compose.resources.painterResource

// Camera zoom is a Web-Mercator concept — Android GoogleMap and any future
// MapKit-backed iOS actual must agree with the projection math below.
internal const val CAMERA_ZOOM = 16.8f

// Profile / current-location marker (pink disc + white border + Person icon).
private const val PROFILE_DIAMETER_DP = 32
private const val PROFILE_BORDER_DP = 2
private const val PROFILE_ICON_DP = 22

// Halo — matches Figma 322:29798. Two staggered filled discs @ ~15% pink,
// growing from just outside the profile disc to ~2× its radius.
private const val HALO_MIN_RADIUS_DP = 22
private const val HALO_MAX_RADIUS_DP = 44
private const val HALO_PEAK_ALPHA = 0.18f
private const val HALO_PERIOD_MS = 2200

// Seva marker — scale nudge + alpha blink, both hanging off the same infinite
// transition so peak-scale and peak-dim land on the same frame.
// Tuned deliberately shallow (UAT): the pin should read as quietly alive, not
// as something demanding a tap. The blink is the subtlest channel of the two —
// alpha barely leaves opaque; a deep dim made a static map look like it was
// flashing. Widening the period alongside keeps the motion calm rather than
// just small-and-fast.
private const val SEVA_ICON_SIZE_DP = 32

// The drawn pin is smaller than a finger. The tap area stays at the 48dp
// Android minimum via a transparent box around it, so shrinking the art
// doesn't make the pin harder to hit.
private const val SEVA_TOUCH_TARGET_DP = 48
private const val SEVA_PULSE_PERIOD_MS = 2000
private const val SEVA_SCALE_PEAK = 1.03f
private const val SEVA_SCALE_DIP = 0.99f
private const val SEVA_ALPHA_LOW = 0.90f

// Google Maps' Web-Mercator tile size (unchanged since inception).
private const val TILE_SIZE_PX = 256.0

/** Two staggered expanding rings — one Canvas, one animation channel per ring,
 *  the second half a period behind the first. */
@Composable
internal fun HaloRings(color: Color, modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "halo")
    // Two channels off one transition, the second half a period behind — a
    // ring-count loop would need `List(n){}` (composable-in-loop) for no gain
    // at n=2.
    val phaseA by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(HALO_PERIOD_MS, delayMillis = 0, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "ring-0",
    )
    val phaseB by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(HALO_PERIOD_MS, delayMillis = HALO_PERIOD_MS / 2, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "ring-1",
    )
    Canvas(modifier = modifier) {
        val minR = HALO_MIN_RADIUS_DP.dp.toPx()
        val maxR = HALO_MAX_RADIUS_DP.dp.toPx()
        val centre = Offset(size.width / 2f, size.height / 2f)
        fun ring(p: Float) = drawCircle(
            color = color.copy(alpha = HALO_PEAK_ALPHA * (1f - p)),
            radius = minR + (maxR - minR) * p,
            center = centre,
        )
        ring(phaseA)
        ring(phaseB)
    }
}

/**
 * Current-location indicator — filled brand disc, white border, the runner's
 * profile photo (same `runners/me` photo the Profile header shows). The Person
 * glyph draws underneath as the fallback, so a null [photoUrl], an in-flight
 * load, or a failed fetch all degrade to the old icon instead of a blank disc.
 */
@Composable
internal fun CurrentLocationMarker(
    color: Color,
    modifier: Modifier = Modifier,
    photoUrl: String? = null,
) {
    Box(
        modifier = modifier
            .size(PROFILE_DIAMETER_DP.dp)
            .clip(CircleShape)
            .background(color)
            .border(PROFILE_BORDER_DP.dp, Color.White, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.Filled.Person,
            contentDescription = "Current location",
            tint = Color.White,
            modifier = Modifier.size(PROFILE_ICON_DP.dp),
        )
        // http(s) only — same gate as core/image RemoteImage. `photoUrl` is
        // server-supplied and Coil's default file:/content: fetchers stay registered
        // alongside our Ktor one; a local-scheme URL would paint local content into
        // this marker. Rejected URLs leave the Person glyph showing.
        if (!photoUrl.isNullOrBlank() && isNetworkImageUrl(photoUrl)) {
            AsyncImage(
                model = photoUrl,
                contentDescription = "Current location",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(PROFILE_DIAMETER_DP.dp)
                    .clip(CircleShape),
            )
        }
    }
}

/**
 * Seva pin — softer scale nudge paired with an alpha blink. Both channels hang
 * off the same [rememberInfiniteTransition], so peak-scale hits at the same
 * frame as peak-dim; when the icon settles, the blink resolves too.
 */
@Composable
internal fun PulsingSevaMarker(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    selected: Boolean = false,
) {
    val transition = rememberInfiniteTransition(label = "seva-pulse")
    val scale by transition.animateFloat(
        initialValue = 1f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = keyframes {
                durationMillis = SEVA_PULSE_PERIOD_MS
                1f at 0
                SEVA_SCALE_PEAK at (SEVA_PULSE_PERIOD_MS * 25 / 100) using FastOutSlowInEasing
                SEVA_SCALE_DIP at (SEVA_PULSE_PERIOD_MS * 45 / 100) using FastOutSlowInEasing
                1f at (SEVA_PULSE_PERIOD_MS * 60 / 100) using FastOutSlowInEasing
                1f at SEVA_PULSE_PERIOD_MS // rest
            },
        ),
        label = "seva-scale",
    )
    val alpha by transition.animateFloat(
        initialValue = 1f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = keyframes {
                durationMillis = SEVA_PULSE_PERIOD_MS
                1f at 0
                SEVA_ALPHA_LOW at (SEVA_PULSE_PERIOD_MS * 25 / 100) using FastOutSlowInEasing
                1f at (SEVA_PULSE_PERIOD_MS * 45 / 100) using FastOutSlowInEasing
                1f at (SEVA_PULSE_PERIOD_MS * 60 / 100) using FastOutSlowInEasing
                1f at SEVA_PULSE_PERIOD_MS // rest
            },
        ),
        label = "seva-alpha",
    )
    // Tap target is the box, art is the child — the box is centred on the same
    // point the caller offsets to, so padding it out to 48dp doesn't move the
    // pin. Scale/alpha stay on the image so the pulse never animates the
    // hit area.
    Box(
        modifier = modifier
            .size(SEVA_TOUCH_TARGET_DP.dp)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        SnabbitImage(
            // Selected art is the filled pink marker shown while this pin's
            // detail card is up. Same footprint as the default pin, so the swap
            // doesn't shift the pin's anchor on the map.
            painter = painterResource(
                if (selected) Res.drawable.seva_marker_selected else Res.drawable.seva_marker,
            ),
            contentDescription = "Seva",
            modifier = Modifier
                .size(SEVA_ICON_SIZE_DP.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    this.alpha = alpha
                },
        )
    }
}

/**
 * Web Mercator projection: given the camera coords, target coords, zoom, and
 * device density, returns the target's on-screen offset (in device pixels)
 * relative to the composable's centre. Google Maps' world is
 * `256 * 2^zoom` CSS px per side; multiplying by [density] gives device px.
 * See https://developers.google.com/maps/documentation/javascript/coordinates
 */
internal fun latLngToScreenOffsetPx(
    camera: MapCoords,
    target: MapCoords,
    zoom: Float,
    density: Float,
): IntOffset {
    val worldPx = TILE_SIZE_PX * 2.0.pow(zoom.toDouble())
    val (cx, cy) = worldPx.projectLatLng(camera)
    val (tx, ty) = worldPx.projectLatLng(target)
    val dxDevice = ((tx - cx) * density).toInt()
    val dyDevice = ((ty - cy) * density).toInt()
    return IntOffset(dxDevice, dyDevice)
}

private fun Double.projectLatLng(coords: MapCoords): Pair<Double, Double> {
    val siny = sin(coords.latitude * PI / 180.0).coerceIn(-0.9999, 0.9999)
    val x = this * (0.5 + coords.longitude / 360.0)
    val y = this * (0.5 - ln((1 + siny) / (1 - siny)) / (4 * PI))
    return x to y
}
