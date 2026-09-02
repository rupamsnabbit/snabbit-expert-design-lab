package com.snabbit.runner.shared.features.home.presentation

import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.location.LocationResult
import com.snabbit.runner.shared.core.location.SnabbitLocation
import com.snabbit.runner.shared.core.location.fakes.FakeLocationProvider
import com.snabbit.runner.shared.core.permissions.PermissionObserver
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.ServiceType
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import com.snabbit.runner.shared.features.gamification.data.GamificationProjector
import com.snabbit.runner.shared.features.gamification.presentation.postaction.PostActionCoordinator
import com.snabbit.runner.shared.features.home.banners.FakeHomeBannersRemote
import com.snabbit.runner.shared.features.home.banners.fakeHomeBannersStore
import com.snabbit.runner.shared.features.job.data.contact.FakeCallingDataSource
import com.snabbit.runner.shared.features.home.seeyoutomorrow.data.SeeYouTomorrowProjector
import com.snabbit.runner.shared.features.home.suspended.FakeSuspendedRepository
import com.snabbit.runner.shared.features.home.suspended.data.SuspendedProjector
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import com.snabbit.runner.shared.features.seva.FakeSevaRepository
import com.snabbit.runner.shared.features.shift.FakeShiftRepository
import com.snabbit.runner.shared.features.shift.attendance.FakeAttendanceRepository
import com.snabbit.runner.shared.features.shift.core.data.ShiftProjector
import com.snabbit.runner.shared.features.shift.lunch.FakeLunchRepository
import com.snabbit.runner.shared.features.shift.lunch.data.LunchProjector
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class HomeLocationGateTest {

    private class FakePermissionObserver(val gps: MutableStateFlow<Boolean>) : PermissionObserver {
        override fun observePermission(permission: SnabbitPermission): Flow<PermissionStatus> =
            flowOf(PermissionStatus.GRANTED)
        override fun observeService(service: ServiceType): Flow<Boolean> = gps
    }

    private val activeVms = mutableListOf<HomeViewModel>()

    private fun vmTest(body: suspend TestScope.() -> Unit) = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try { body() } finally {
            activeVms.forEach { it.viewModelScope.cancel() }
            activeVms.clear()
            Dispatchers.resetMain()
        }
    }

    private fun wire(
        scope: TestScope,
        observer: PermissionObserver,
        location: FakeLocationProvider,
        sevaRepository: FakeSevaRepository = FakeSevaRepository(),
        store: RunnerStateStore = RunnerStateStore(FakeLogger()),
    ): HomeViewModel {
        val bg = scope.backgroundScope
        val profileStore = RunnerProfileStore(FakeLogger())
        val vm = HomeViewModel(
            readModel = ShiftProjector(store, bg, FakeLogger()),
            gamification = GamificationProjector(store, bg, CurrentTimeMs { 0L }, CrashReporter { _, _ -> }),
            attendanceRepository = FakeAttendanceRepository(),
            shiftRepository = FakeShiftRepository(),
            postActionCoordinator = PostActionCoordinator(),
            lunchReadModel = LunchProjector(store, bg, FakeLogger()),
            lunchRepository = FakeLunchRepository(),
            sevaRepository = sevaRepository,
            suspendedReadModel = SuspendedProjector(store, profileStore, bg),
            suspendedRepository = FakeSuspendedRepository(),
            seeYouTomorrowReadModel = SeeYouTomorrowProjector(store, bg),
            homeBannersStore = fakeHomeBannersStore(),
            locationProvider = location,
            analytics = object : AnalyticsTracker {
                override fun track(name: String, props: Map<String, Any?>, targets: Set<String>?) = Unit
                override fun identify(userId: String?) = Unit
                override fun reset() = Unit
                override fun setUserProperty(key: String, value: Any?) = Unit
                override fun onUserLogin(profile: Map<String, Any?>) = Unit
                override fun setUserProperties(props: Map<String, Any?>) = Unit
            },
            currentTimeMs = { 0L },
            logger = FakeLogger(),
            profileStore = profileStore,
            callingDataSource = FakeCallingDataSource(),
            permissionObserver = observer,
        ).also { activeVms += it }
        return vm
    }

    @Test fun gpsOff_setsServiceOff() = vmTest {
        val vm = wire(this, FakePermissionObserver(MutableStateFlow(false)), FakeLocationProvider())
        runCurrent()
        assertTrue(vm.uiState.value.locationServiceOff)
    }

    @Test fun gpsBackOn_clearsAndReseedsAndRestarts() = vmTest {
        val location = FakeLocationProvider(
            currentResult = LocationResult.Success(
                SnabbitLocation(latitude = 12.9, longitude = 77.6, accuracy = 0f, timestamp = 0L, collectedAt = 0L),
            ),
            lastKnownResult = LocationResult.Success(
                SnabbitLocation(latitude = 12.9, longitude = 77.6, accuracy = 0f, timestamp = 0L, collectedAt = 0L),
            ),
            // Empty (the default): the init `trackLocation().collectLatest {}` collection
            // completes cleanly against this finite flow instead of hanging the test.
            trackResults = emptyList(),
        )
        val sevaRepository = FakeSevaRepository()
        val gps = MutableStateFlow(false)
        // Seva only fetches on the Map archetype (ECPO-905), so the GPS-re-enable
        // refetch is only observable there — land on SearchingForJobs first.
        val store = RunnerStateStore(FakeLogger())
        val vm = wire(this, FakePermissionObserver(gps), location, sevaRepository, store)
        store.pushState(
            """{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{"show_logout_warning_widgets":false,"shift_end_time":"08:00 pm"}}""",
        )
        runCurrent()
        assertTrue(vm.uiState.value.locationServiceOff)

        // Snapshot call counts IMMEDIATELY BEFORE the re-enable. HomeViewModel.init's
        // fan-out (camera seed via getLastKnownLocation, refreshNearbySeva,
        // startLocationTracking) already fires each of these once on cold start — so a
        // bare "> 0" assertion after re-enabling would pass even if onLocationEnabled()
        // never ran. Asserting the exact post-enable delta is what actually pins the
        // re-enable path down.
        val lastKnownCallsBefore = location.getLastKnownLocationCalls
        val trackCallsBefore = location.trackLocationCalls
        val sevaCallsBefore = sevaRepository.calls.size

        gps.value = true
        runCurrent()

        assertFalse(vm.uiState.value.locationServiceOff)
        // onLocationEnabled → getLastKnownLocation re-seed fired exactly once (not just
        // "at least once", which the cold-start seed already satisfies on its own).
        assertEquals(lastKnownCallsBefore + 1, location.getLastKnownLocationCalls)
        // onLocationEnabled → the gated trackLocation() stream was restarted (init's
        // collection + the post-enable restart == 2 total starts).
        assertEquals(trackCallsBefore + 1, location.trackLocationCalls)
        assertEquals(2, location.trackLocationCalls)
        // onLocationEnabled → seva/nearby refetch fired.
        assertEquals(sevaCallsBefore + 1, sevaRepository.calls.size)
    }

    @Test fun enableLocation_triggersGetCurrentLocation() = vmTest {
        val location = FakeLocationProvider()
        val vm = wire(this, FakePermissionObserver(MutableStateFlow(true)), location)
        runCurrent()
        val before = location.getCurrentLocationCalls
        vm.onIntent(HomeUiIntent.EnableLocation)
        runCurrent()
        assertEquals(before + 1, location.getCurrentLocationCalls)
    }
}
