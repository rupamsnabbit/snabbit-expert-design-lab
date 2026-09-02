package com.snabbit.runner.shared.features.job.data

import com.snabbit.runner.shared.core.location.LocationProvider as CoreLocationProvider
import com.snabbit.runner.shared.core.location.LocationResult
import com.snabbit.runner.shared.core.location.TrackingConfig
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.features.job.domain.model.JobLocation
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Supplies the device's current location for job-action payloads. The Flutter
 * `JobHttp` attaches `location:{lat,lng}` to `accept_job` / `deny_job` /
 * `start_job` / `check_out`; `commonMain` can't read GPS, so this seam is backed
 * by the shared `core.location` module (see [CoreJobLocationProvider]). Tests use a fake.
 *
 * `suspend` + main-safe. Returns null when location is unavailable / denied — which is safe:
 * `location` is optional on every job action server-side (`accept_job` included — the API takes
 * `AcceptJobRequest | None`, so a missing location is accepted, not a 400). Callers must tolerate
 * a null.
 */
interface LocationProvider {
    suspend fun currentLocation(): JobLocation?
}

/**
 * Production [LocationProvider]: adapts the shared `core.location` module to the job-action
 * seam. Requests a fix via [CoreLocationProvider.getCurrentOrLastKnown] — fresh preferred,
 * cached fallback, the same best-effort strategy Flutter's `fetchCurrentLocation()` uses — and
 * maps a [LocationResult.Success] to [JobLocation]. Any non-success (permission denied, GPS off,
 * Play-services missing, transient failure) maps to null.
 *
 * The whole fetch is bounded by [withTimeoutOrNull] with an RC-tunable budget
 * ([JOB_LOCATION_TIMEOUT_RC_KEY], default [JOB_LOCATION_TIMEOUT_DEFAULT_MS] ms): job actions must
 * not block on GPS, so if no fix lands in the budget we send no location rather than stall the
 * action. The outer timeout is also the *only* hard ceiling on the fresh-fix step — the core
 * provider's optional system "turn on location" dialog is otherwise un-time-bounded. The fresh-fix
 * step gets **half** the budget as `TrackingConfig.timeoutMs` (the core default is 30 s): if it
 * were the full budget, a slow fix would time out at the same instant the outer timeout cancels
 * the coroutine and the instant last-known-cache fallback would lose that race — halving leaves
 * it real room on both fast-failing *and* slow-fix paths.
 *
 * Bound in [jobModule], replacing the [NoLocationProvider] placeholder now that the location
 * module has merged.
 */
class CoreJobLocationProvider(
    private val core: CoreLocationProvider,
    private val remoteConfig: RemoteConfigGateway,
) : LocationProvider {
    override suspend fun currentLocation(): JobLocation? {
        val timeoutMs = remoteConfig
            .getString(JOB_LOCATION_TIMEOUT_RC_KEY, JOB_LOCATION_TIMEOUT_DEFAULT_MS)
            .toLongOrNull() ?: JOB_LOCATION_TIMEOUT_DEFAULT_MS.toLong()
        return withTimeoutOrNull(timeoutMs) {
            // Half the budget for the fresh fix so its timeout fires before the outer one —
            // leaving the remaining half for the last-known-cache fallback (see class KDoc).
            core.getCurrentOrLastKnown(TrackingConfig(timeoutMs = timeoutMs / 2))
        }
            ?.let { it as? LocationResult.Success }
            ?.location
            ?.let { JobLocation(lat = it.latitude, lng = it.longitude) }
    }

    private companion object {
        /** Max wait (ms, as a numeric string) for a job-action location fix before it's skipped.
         *  Mirrored from Flutter `RemoteConfigKeys.jobLocationTimeoutMs`; default MUST match the
         *  Flutter-side default in `KmpRemoteConfigMirror`. */
        const val JOB_LOCATION_TIMEOUT_RC_KEY = "expert_job_location_timeout_ms"
        const val JOB_LOCATION_TIMEOUT_DEFAULT_MS = "500"
    }
}

/**
 * No-op [LocationProvider] that always returns null. No longer the production binding
 * (see [CoreJobLocationProvider]); kept as a null-location default for tests.
 */
internal object NoLocationProvider : LocationProvider {
    override suspend fun currentLocation(): JobLocation? = null
}
