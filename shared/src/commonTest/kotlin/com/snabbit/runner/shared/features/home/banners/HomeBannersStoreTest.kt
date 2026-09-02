package com.snabbit.runner.shared.features.home.banners

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.home.banners.data.HomeBannersStore
import com.snabbit.runner.shared.features.home.banners.data.remote.BannerRemoteDataSource
import com.snabbit.runner.shared.features.home.banners.data.remote.dto.HomeBannersResponseDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class HomeBannersStoreTest {

    private fun store(remote: FakeHomeBannersRemote) = fakeHomeBannersStore(remote)

    @Test fun startsUnknown_soTheFirstFrameDoesNotClaimZero() {
        val s = store(FakeHomeBannersRemote(FakeHomeBannersRemote.ok(unreadCount = 3)))
        assertNull(s.state.value.unreadCount)
        assertTrue(!s.state.value.hasUnreadNotifications)
        assertNull(s.state.value.banners)
    }

    @Test fun countAndBannersArrivePublishedTogether() = runTest {
        val s = store(
            FakeHomeBannersRemote(
                FakeHomeBannersRemote.ok(
                    banners = listOf(FakeHomeBannersRemote.bannerDto("b1")),
                    unreadCount = 13,
                ),
            ),
        )
        s.refresh()

        assertEquals(13, s.state.value.unreadCount)
        assertTrue(s.state.value.hasUnreadNotifications)
        assertEquals(listOf("b1"), (s.state.value.banners as Result.Ok).value.map { it.id })
    }

    @Test fun zeroClearsTheBadge() = runTest {
        val s = store(FakeHomeBannersRemote(FakeHomeBannersRemote.ok(unreadCount = 0)))
        s.refresh()
        assertEquals(0, s.state.value.unreadCount)
        assertTrue(!s.state.value.hasUnreadNotifications)
    }

    /** A merch outage must not read as "nothing unread". */
    @Test fun nullSectionKeepsTheLastKnownCount() = runTest {
        val remote = FakeHomeBannersRemote(FakeHomeBannersRemote.ok(unreadCount = 7))
        val s = store(remote)
        s.refresh()

        remote.result = FakeHomeBannersRemote.ok(unreadCount = null)
        s.refresh()

        assertEquals(7, s.state.value.unreadCount)
    }

    @Test fun networkErrorKeepsTheCountAndSurfacesTheBannerFailure() = runTest {
        val remote = FakeHomeBannersRemote(FakeHomeBannersRemote.ok(unreadCount = 7))
        val s = store(remote)
        s.refresh()

        remote.result = Result.Err(FakeHomeBannersRemote.transportError())
        s.refresh()

        assertEquals(7, s.state.value.unreadCount)
        assertTrue(s.state.value.banners is Result.Err)
    }

    /**
     * The shell's badge refresh and Home's banners both fire at launch. They
     * must collapse into ONE request — the fake has to suspend, or the
     * scheduler runs them sequentially and the test proves nothing.
     */
    @Test fun concurrentCallersShareOneFetch() = runTest {
        val gate = CompletableDeferred<Unit>()
        val remote = GatedRemote(gate, FakeHomeBannersRemote.ok(unreadCount = 5))
        val s = HomeBannersStore(remote, FakeLogger())

        val a = async { s.refresh() }
        val b = async { s.refresh() }
        val c = async { s.refresh() }
        runCurrent()
        gate.complete(Unit)
        a.await(); b.await(); c.await()

        assertEquals(1, remote.calls)
        assertEquals(5, s.state.value.unreadCount)
    }

    /** A later caller, once the first finished, does fetch again — that is what resume is. */
    /** A caller can die mid-fetch: OnAppResumed launches on the composition's
     *  scope, and leaving the shell cancels it. The in-flight marker must still
     *  clear, or every later refresh joins a fetch that never completes and the
     *  badge and banners freeze for the rest of the process. */
    @Test fun aCancelledCallerDoesNotWedgeTheStore() = runTest {
        val gate = CompletableDeferred<Unit>()
        val remote = GatedRemote(gate, FakeHomeBannersRemote.ok(unreadCount = 7))
        val s = HomeBannersStore(remote, FakeLogger())

        val doomed = launch { s.refresh() }
        runCurrent()
        assertEquals(1, remote.calls)
        doomed.cancelAndJoin()

        gate.complete(Unit)
        val later = launch { s.refresh() }
        runCurrent()

        assertTrue(later.isCompleted, "refresh() never returned — the store is wedged")
        assertEquals(2, remote.calls)
        assertEquals(7, s.state.value.unreadCount)
    }

    @Test fun sequentialCallersEachFetch() = runTest {
        val remote = GatedRemote(CompletableDeferred(Unit), FakeHomeBannersRemote.ok(unreadCount = 5))
        val s = HomeBannersStore(remote, FakeLogger())

        s.refresh()
        s.refresh()

        assertEquals(2, remote.calls)
    }

    /** The exact body the live endpoint returns, so contract drift fails here. */
    @Test fun parsesTheLiveWireBody() {
        val json = Json { ignoreUnknownKeys = true; isLenient = true }
        val body = """{"banners":[],"notifications":{"unread_count":13}}"""
        assertEquals(13, json.decodeFromString<HomeBannersResponseDto>(body).notifications?.unreadCount)
    }

    /** Older servers omit the section entirely; that must decode, not throw. */
    @Test fun parsesAResponseWithoutTheSection() {
        val json = Json { ignoreUnknownKeys = true; isLenient = true }
        assertNull(json.decodeFromString<HomeBannersResponseDto>("""{"banners":[]}""").notifications)
    }

    private class GatedRemote(
        private val gate: CompletableDeferred<Unit>,
        private val result: Result<HomeBannersResponseDto, NetworkError>,
    ) : BannerRemoteDataSource {
        var calls = 0
            private set

        override suspend fun fetchHomeBanners(): Result<HomeBannersResponseDto, NetworkError> {
            calls++
            gate.await()
            return result
        }
    }
}
