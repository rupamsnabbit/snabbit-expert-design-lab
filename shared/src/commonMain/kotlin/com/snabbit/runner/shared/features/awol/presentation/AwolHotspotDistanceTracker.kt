package com.snabbit.runner.shared.features.awol.presentation

import com.snabbit.runner.shared.core.location.SnabbitLocation
import com.snabbit.runner.shared.core.location.distanceMeters
import com.snabbit.runner.shared.features.awol.domain.AwolHotspot
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.awol.presentation.ui.formatAwolDistance
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/**
 * Live "3.2 km away" text for the hotspot tile — the KMP mirror of the Dart
 * job_login distance label (position stream + per-fix distance, graceful
 * degradation to no text). Owned by whatever hosts the HOME_CARD surface and
 * scoped to its lifetime: the host constructs it and tears it down by
 * cancelling [scope], so this is **not** a Koin single.
 *
 * **It opens no location stream of its own.** [runnerLocation] is the host
 * screen's already-running fix (`HomeViewModel.runnerLocation`), because
 * `LocationProvider.trackLocation` gives every collector its own
 * FusedLocationProvider request: calling it here meant two concurrent
 * HIGH_ACCURACY streams — and two `LocationCallback`s — for one screen. Reading
 * the host's stream keeps the accuracy and cadence the 1-metre label needs
 * (the home stream uses the same default [com.snabbit.runner.shared.core.location.TrackingConfig])
 * at half the GPS cost. A `null` element means "no usable fix" (permission
 * denied / GPS off / failure), exactly as the host publishes it.
 *
 * Behaviour:
 *  - Distance is computed only while the coordinator routes to `HOME_CARD` and
 *    the snapshot's hotspot has coordinates; any other state emits null (tile
 *    hides the line) and stops collecting.
 *  - Every fix recomputes against the *current* hotspot ([collectLatest]
 *    re-collects when the hotspot changes). [runnerLocation] is a StateFlow, so
 *    the latest known fix paints immediately on (re)subscription.
 *  - A null fix → null text. Collection stays open, so the line reappears as
 *    soon as the host publishes a fix again.
 */
class AwolHotspotDistanceTracker(
    private val runnerLocation: StateFlow<SnabbitLocation?>,
    private val uiState: StateFlow<AwolUiState>,
    private val scope: CoroutineScope,
    private val strings: AwolStrings = AwolStrings(),
) {
    private val _distanceText = MutableStateFlow<String?>(null)
    val distanceText: StateFlow<String?> = _distanceText.asStateFlow()

    private var job: Job? = null

    /** Idempotent; teardown is [scope] cancellation (or [stop]). */
    fun start() {
        if (job?.isActive == true) return
        job = scope.launch {
            uiState
                .map { it.trackedHotspot() }
                .distinctUntilChanged()
                .collectLatest { hotspot ->
                    if (hotspot == null) {
                        _distanceText.value = null
                        return@collectLatest
                    }
                    // trackedHotspot() guarantees coordinates.
                    val lat = hotspot.latitude ?: return@collectLatest
                    val lng = hotspot.longitude ?: return@collectLatest
                    runnerLocation.collect { emit(it, lat, lng) }
                }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        _distanceText.value = null
    }

    private fun emit(fix: SnabbitLocation?, hotspotLat: Double, hotspotLng: Double) {
        _distanceText.value = fix?.let {
            formatAwolDistance(
                distanceMeters(it.latitude, it.longitude, hotspotLat, hotspotLng),
                strings.hotspotDistanceAwaySuffix,
            )
        }
    }
}

/** The hotspot to measure against, or null when the tile isn't the live surface. */
private fun AwolUiState.trackedHotspot(): AwolHotspot? =
    snapshot?.hotspot?.takeIf { surface == AwolSurface.HOME_CARD && it.hasCoordinates }
