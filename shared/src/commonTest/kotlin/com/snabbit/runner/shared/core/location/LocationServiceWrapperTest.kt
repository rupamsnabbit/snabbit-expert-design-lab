package com.snabbit.runner.shared.core.location

import com.snabbit.runner.shared.core.location.fakes.FakeLocationProvider
import com.snabbit.runner.shared.core.permissions.fakes.FakePermissionManager
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

class LocationServiceWrapperTest {

    private fun permissions(status: PermissionStatus) = FakePermissionManager(
        statuses = mutableMapOf(SnabbitPermission.LocationFine to status),
    )

    private val sampleLocation = SnabbitLocation(
        latitude = 12.34,
        longitude = 56.78,
        accuracy = 5f,
        timestamp = 1_000L,
        collectedAt = 2_000L,
    )

    // --- permission gate ---

    @Test
    fun getCurrentLocation_permissionDenied_returnsPermissionDenied_withoutTouchingProvider() = runTest {
        val provider = FakeLocationProvider(currentResult = LocationResult.Success(sampleLocation))
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.DENIED))

        val result = wrapper.getCurrentLocation()

        assertEquals(LocationResult.PermissionDenied, result)
        assertEquals(0, provider.getCurrentLocationCalls)
    }

    @Test
    fun getCurrentLocation_granted_delegatesToProvider() = runTest {
        val provider = FakeLocationProvider(currentResult = LocationResult.Success(sampleLocation))
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.GRANTED))

        val result = wrapper.getCurrentLocation(TrackingConfig(timeoutMs = 12_345))

        assertEquals(LocationResult.Success(sampleLocation), result)
        assertEquals(1, provider.getCurrentLocationCalls)
        assertEquals(12_345, provider.lastConfig?.timeoutMs)
    }

    @Test
    fun getCurrentLocation_deniedAlways_isAlsoTreatedAsDenied() = runTest {
        val provider = FakeLocationProvider(currentResult = LocationResult.Success(sampleLocation))
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.DENIED_ALWAYS))

        assertEquals(LocationResult.PermissionDenied, wrapper.getCurrentLocation())
        assertEquals(0, provider.getCurrentLocationCalls)
    }

    @Test
    fun getLastKnownLocation_permissionDenied_returnsPermissionDenied() = runTest {
        val provider = FakeLocationProvider(lastKnownResult = LocationResult.Success(sampleLocation))
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.NOT_AVAILABLE))

        assertEquals(LocationResult.PermissionDenied, wrapper.getLastKnownLocation())
        assertEquals(0, provider.getLastKnownLocationCalls)
    }

    @Test
    fun getLastKnownLocation_granted_delegates() = runTest {
        val provider = FakeLocationProvider(lastKnownResult = LocationResult.Success(sampleLocation))
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.GRANTED))

        assertEquals(LocationResult.Success(sampleLocation), wrapper.getLastKnownLocation())
        assertEquals(1, provider.getLastKnownLocationCalls)
    }

    // --- getCurrentOrLastKnown (interface default, exercised through the wrapper) ---

    @Test
    fun getCurrentOrLastKnown_success_returnsImmediately_noFallback() = runTest {
        val provider = FakeLocationProvider(
            currentResult = LocationResult.Success(sampleLocation),
            lastKnownResult = LocationResult.Failure("should not be reached"),
        )
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.GRANTED))

        val result = wrapper.getCurrentOrLastKnown()

        assertEquals(LocationResult.Success(sampleLocation), result)
        assertEquals(1, provider.getCurrentLocationCalls)
        assertEquals(0, provider.getLastKnownLocationCalls)
    }

    @Test
    fun getCurrentOrLastKnown_failure_fallsBackToLastKnown() = runTest {
        val provider = FakeLocationProvider(
            currentResult = LocationResult.Failure("timeout"),
            lastKnownResult = LocationResult.Success(sampleLocation),
        )
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.GRANTED))

        val result = wrapper.getCurrentOrLastKnown()

        assertEquals(LocationResult.Success(sampleLocation), result)
        assertEquals(1, provider.getCurrentLocationCalls)
        assertEquals(1, provider.getLastKnownLocationCalls)
    }

    @Test
    fun getCurrentOrLastKnown_serviceDisabled_fallsBackToLastKnown() = runTest {
        val provider = FakeLocationProvider(
            currentResult = LocationResult.ServiceDisabled,
            lastKnownResult = LocationResult.Success(sampleLocation),
        )
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.GRANTED))

        assertEquals(LocationResult.Success(sampleLocation), wrapper.getCurrentOrLastKnown())
        assertEquals(1, provider.getLastKnownLocationCalls)
    }

    @Test
    fun getCurrentOrLastKnown_permissionDenied_shortCircuits_noFallback() = runTest {
        // Permission denied at the wrapper: getCurrentLocation returns PermissionDenied before the
        // provider is touched, and the fallback must NOT run (last-known needs permission too).
        val provider = FakeLocationProvider(lastKnownResult = LocationResult.Success(sampleLocation))
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.DENIED))

        assertEquals(LocationResult.PermissionDenied, wrapper.getCurrentOrLastKnown())
        assertEquals(0, provider.getCurrentLocationCalls)
        assertEquals(0, provider.getLastKnownLocationCalls)
    }

    @Test
    fun getCurrentOrLastKnown_playServicesUnavailable_shortCircuits_noFallback() = runTest {
        val provider = FakeLocationProvider(
            currentResult = LocationResult.PlayServicesUnavailable,
            lastKnownResult = LocationResult.Success(sampleLocation),
        )
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.GRANTED))

        assertEquals(LocationResult.PlayServicesUnavailable, wrapper.getCurrentOrLastKnown())
        assertEquals(1, provider.getCurrentLocationCalls)
        assertEquals(0, provider.getLastKnownLocationCalls)
    }

    // --- tracking ---

    @Test
    fun trackLocation_permissionDenied_emitsPermissionDeniedThenCompletes() = runTest {
        val provider = FakeLocationProvider(
            trackResults = listOf(LocationResult.Success(sampleLocation)),
        )
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.DENIED))

        val emissions = wrapper.trackLocation().toList()

        assertEquals(listOf(LocationResult.PermissionDenied), emissions)
        assertEquals(0, provider.trackLocationCalls)
    }

    @Test
    fun trackLocation_granted_streamsProviderEmissions() = runTest {
        val provider = FakeLocationProvider(
            trackResults = listOf(
                LocationResult.Success(sampleLocation),
                LocationResult.ServiceDisabled,
            ),
        )
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.GRANTED))

        val emissions = wrapper.trackLocation().toList()

        assertEquals(2, emissions.size)
        assertIs<LocationResult.Success>(emissions[0])
        assertEquals(LocationResult.ServiceDisabled, emissions[1])
        assertEquals(1, provider.trackLocationCalls)
    }

    @Test
    fun trackLocation_midStreamRevocation_relaysProviderPermissionDeniedAndTerminates() = runTest {
        // Verifies the WRAPPER's relay behavior — not the provider's detection. Once the start-time
        // gate opens (permission GRANTED), the wrapper forwards provider emissions verbatim via
        // emitAll, including a terminal PermissionDenied that FusedLocationProvider emits on
        // mid-stream revocation (onLocationAvailability + close()). NOTE: the provider's actual
        // revocation *detection* is GMS-dependent and is not unit-covered here; this asserts only
        // that the wrapper relays such a provider-emitted PermissionDenied unchanged (it doesn't
        // transform it). Complements the start-time-denial case above.
        val provider = FakeLocationProvider(
            trackResults = listOf(
                LocationResult.Success(sampleLocation),
                LocationResult.PermissionDenied,
            ),
        )
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.GRANTED))

        val emissions = wrapper.trackLocation().toList()

        assertEquals(2, emissions.size)
        assertIs<LocationResult.Success>(emissions[0])
        assertEquals(LocationResult.PermissionDenied, emissions[1])
        assertEquals(1, provider.trackLocationCalls)
    }

    @Test
    fun stopTracking_delegatesToProvider() {
        val provider = FakeLocationProvider()
        val wrapper = LocationServiceWrapper(provider, permissions(PermissionStatus.GRANTED))

        wrapper.stopTracking()

        assertTrue(provider.stopTrackingCalls == 1)
    }
}
