package com.snabbit.runner.shared.features.home.banners.data

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.home.banners.data.remote.BannerRemoteDataSource
import com.snabbit.runner.shared.features.home.banners.domain.model.HomeBannersState
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

private const val TAG = "HomeBannersStore"

/**
 * The one fetch of `/me/home_banners`, shared by Home's banner section and the
 * bottom nav's Updates badge.
 *
 * Owned above Home because the badge is drawn on every tab, while
 * `HomeViewModel` is constructed lazily on first Home composition — a runner who
 * launches onto Profile would otherwise never see a dot. Exposed as a
 * [StateFlow] so a late collector replays the last result rather than waiting
 * for the next fetch.
 */
class HomeBannersStore internal constructor(
    private val remote: BannerRemoteDataSource,
    private val logger: Logger,
) {

    private val _state = MutableStateFlow(HomeBannersState())
    val state: StateFlow<HomeBannersState> = _state.asStateFlow()

    // Guards [inFlight] only. A lock around the fetch itself would serialise
    // callers into N sequential requests instead of collapsing them into one.
    private val mutex = Mutex()

    // Non-null while a fetch runs; later callers await it and read the state it
    // produced rather than issuing their own request.
    private var inFlight: CompletableDeferred<Unit>? = null

    /**
     * Fetch, or join a fetch already running. `suspend` rather than
     * scope-owning: the caller supplies the scope, matching the store
     * convention here (no class holds a `CoroutineScope`).
     *
     * The shell's badge refresh and Home's banners land here within a frame of
     * each other at launch; a second caller waits on the first so only one
     * request goes out and nobody reads an unresolved state.
     */
    suspend fun refresh() {
        var mine: CompletableDeferred<Unit>? = null
        val running = mutex.withLock {
            inFlight ?: CompletableDeferred<Unit>().also { mine = it; inFlight = it }
        }
        if (mine == null) return running.await()

        try {
            when (val result = remote.fetchHomeBanners()) {
                is Result.Ok -> {
                    val count = result.value.notifications?.unreadCount
                    // A null section carries no information — keep the last
                    // known count rather than clearing the dot.
                    _state.update {
                        it.copy(
                            banners = Result.Ok(result.value.banners.toBanners()),
                            unreadCount = count ?: it.unreadCount,
                        )
                    }
                    if (count == null) {
                        logger.d(TAG, "home_banners returned no notifications section; badge unchanged")
                    }
                }
                is Result.Err -> {
                    logger.e(TAG, "home_banners fetch failed: ${result.error}")
                    // The badge keeps its last value; banners surface the
                    // failure so Home settles to its Refer fallback as before.
                    _state.update { it.copy(banners = Result.Err(result.error)) }
                }
            }
        } finally {
            // NonCancellable: a caller cancelled mid-fetch (the shell's
            // composition going away under OnAppResumed) must still clear the
            // marker. Suspending on a contended mutex in a cancelled coroutine
            // would throw here and leave every later refresh joining a fetch
            // that never completes.
            withContext(NonCancellable) {
                mutex.withLock { inFlight = null }
                mine.complete(Unit)
            }
        }
    }
}
