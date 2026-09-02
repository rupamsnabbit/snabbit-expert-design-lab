package com.snabbit.runner.shared.features.gamification.presentation.postaction

import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Orchestrates the post-action outcome overlay — the KMP port of Dart
 * `PostActionOverlayController`. A Koin single, observed by
 * [PostActionOverlayHost] (mounted once in the KMP host).
 *
 * [show] publishes the outcome to [current] and **suspends the caller until the
 * overlay is dismissed** ([dismiss]), so a feature VM can `await` it before
 * calling `GamificationProjector.requestRefresh()` — preserving Dart's
 * "block the state refresh until the animation finishes" contract. A [Mutex]
 * serialises overlapping outcomes (re-entrancy guard) so a second action can't
 * stomp a popup that's still on screen.
 *
 * Routing (waived → sheet vs reward/penalty → popup) is decided by the host from
 * [PostActionOutcome.isWaived]; the coordinator is transport-only.
 */
class PostActionCoordinator {

    private val mutex = Mutex()
    private val _current = MutableStateFlow<PostActionOutcome?>(null)
    private var pending: CompletableDeferred<Unit>? = null

    /** The outcome currently being presented, or null when the overlay is idle. */
    val current: StateFlow<PostActionOutcome?> = _current.asStateFlow()

    /**
     * Present [outcome] and suspend until [dismiss] is called. Serialised: a
     * concurrent [show] waits for the current one to finish before presenting.
     */
    suspend fun show(outcome: PostActionOutcome) = mutex.withLock {
        val signal = CompletableDeferred<Unit>()
        pending = signal
        _current.value = outcome
        signal.await()
    }

    /**
     * Fire-and-forget present, for **cross-screen** triggers (e.g. login) where
     * the caller's scope won't outlive the navigation back to the surface that
     * hosts [PostActionOverlayHost]. Unlike [show] it does not suspend or take
     * the mutex — it just publishes the outcome; the host renders it once it's
     * composed, and [dismiss] clears it. Overwrites any idle/previous outcome.
     */
    fun present(outcome: PostActionOutcome) {
        _current.value = outcome
    }

    /** Dismiss the current overlay and resume the suspended [show] caller. */
    fun dismiss() {
        _current.value = null
        pending?.complete(Unit)
        pending = null
    }
}
