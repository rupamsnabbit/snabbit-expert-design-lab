package com.snabbit.runner.shared.features.job.data

import com.snabbit.runner.shared.core.location.LocationProvider as CoreLocationProvider
import com.snabbit.runner.shared.core.location.LocationResult
import com.snabbit.runner.shared.core.location.SnabbitLocation
import com.snabbit.runner.shared.core.location.TrackingConfig
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull

/**
 * [CoreJobLocationProvider] bounds the job-action location fetch by an RC-tunable timeout: a fix
 * that lands in time is mapped to [com.snabbit.runner.shared.features.job.domain.model.JobLocation];
 * a fetch that outruns the budget yields null (the action is sent without a location). Uses
 * [runTest]'s virtual clock so the timeout fires without real waiting.
 */
class CoreJobLocationProviderTest {

    /** Core [CoreLocationProvider] double whose fresh fix optionally [delayMs] before returning. */
    private class DelayingCore(
        private val result: LocationResult,
        private val delayMs: Long = 0,
    ) : CoreLocationProvider {
        override suspend fun getCurrentLocation(config: TrackingConfig): LocationResult {
            if (delayMs > 0) delay(delayMs)
            return result
        }
        override suspend fun getLastKnownLocation(): LocationResult = result
        override fun trackLocation(config: TrackingConfig): Flow<LocationResult> = emptyFlow()
        override fun stopTracking() = Unit
    }

    /** [RemoteConfigGateway] returning [timeout] for any string key, or the caller's default when null. */
    private fun gateway(timeout: String? = null) = object : RemoteConfigGateway {
        override fun getBool(key: String, default: Boolean) = default
        override fun getString(key: String, default: String) = timeout ?: default
    }

    private val success = LocationResult.Success(
        SnabbitLocation(latitude = 12.34, longitude = 56.78, accuracy = 5f, timestamp = 0, collectedAt = 0),
    )

    @Test
    fun `maps the fix to JobLocation when it lands within the timeout`() = runTest {
        val provider = CoreJobLocationProvider(DelayingCore(success), gateway())

        val location = provider.currentLocation()

        assertEquals(12.34, location?.lat)
        assertEquals(56.78, location?.lng)
    }

    @Test
    fun `returns null when the fix outruns the timeout budget`() = runTest {
        // Default budget is 500ms; the fresh fix takes 5s → skipped.
        val provider = CoreJobLocationProvider(DelayingCore(success, delayMs = 5_000), gateway())

        assertNull(provider.currentLocation())
    }

    @Test
    fun `returns null when location is unavailable`() = runTest {
        val provider = CoreJobLocationProvider(
            DelayingCore(LocationResult.PermissionDenied),
            gateway(),
        )

        assertNull(provider.currentLocation())
    }

    @Test
    fun `honours an RC-overridden timeout budget`() = runTest {
        // Budget lowered to 50ms; a 200ms fix now misses the window.
        val provider = CoreJobLocationProvider(
            DelayingCore(success, delayMs = 200),
            gateway(timeout = "50"),
        )

        assertNull(provider.currentLocation())
    }

    @Test
    fun `falls back to last-known when the fresh fix runs out its own timeout`() = runTest {
        // The worst case for the outer/inner race: the fresh fix fails at exactly its
        // TrackingConfig budget (what the real provider does on a slow fix). The inner budget is
        // half the outer one, so the instant last-known cache still lands within the outer window.
        val core = object : CoreLocationProvider {
            override suspend fun getCurrentLocation(config: TrackingConfig): LocationResult {
                delay(config.timeoutMs)
                return LocationResult.Failure("fix timed out")
            }
            override suspend fun getLastKnownLocation(): LocationResult = success
            override fun trackLocation(config: TrackingConfig): Flow<LocationResult> = emptyFlow()
            override fun stopTracking() = Unit
        }
        val provider = CoreJobLocationProvider(core, gateway())

        val location = provider.currentLocation()

        assertEquals(12.34, location?.lat)
        assertEquals(56.78, location?.lng)
    }

    @Test
    fun `uses the default budget when the RC value is not numeric`() = runTest {
        // "abc" fails toLongOrNull → the 500ms default applies, so a quick fix still lands.
        val provider = CoreJobLocationProvider(
            DelayingCore(success, delayMs = 100),
            gateway(timeout = "abc"),
        )

        val location = provider.currentLocation()

        assertEquals(12.34, location?.lat)
    }

    @Test
    fun `an RC budget of 0 skips the fetch without touching the core provider`() = runTest {
        // The rollout kill-switch: "0" must short-circuit — no location, no GPS work at all.
        var coreCalled = false
        val core = object : CoreLocationProvider {
            override suspend fun getCurrentLocation(config: TrackingConfig): LocationResult {
                coreCalled = true
                return success
            }
            override suspend fun getLastKnownLocation(): LocationResult {
                coreCalled = true
                return success
            }
            override fun trackLocation(config: TrackingConfig): Flow<LocationResult> = emptyFlow()
            override fun stopTracking() = Unit
        }
        val provider = CoreJobLocationProvider(core, gateway(timeout = "0"))

        assertNull(provider.currentLocation())
        assertFalse(coreCalled)
    }
}
