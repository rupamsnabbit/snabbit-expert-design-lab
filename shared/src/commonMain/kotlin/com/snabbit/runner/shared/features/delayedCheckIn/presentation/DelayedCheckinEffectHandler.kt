package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import com.snabbit.runner.shared.features.job.data.contact.CustomerContactLauncher
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.receiveAsFlow

/**
 * Maps [DelayedCheckinEffect]s onto the v2 job surfaces (DC-81, LLD "Map
 * effects to v2 navigation"): the platform-level effect
 * ([DelayedCheckinEffect.Dial]) is performed directly against the
 * injected seam; the screen-level [DelayedCheckinEffect.Toast] is
 * re-emitted as a flow for `JobScreen` to collect — the feedback banner
 * lives in its composition, not at the host.
 *
 * Mirrors the [com.snabbit.runner.shared.features.job.presentation.contact.CustomerContactHandler]
 * split: the host ([JobActivity]) constructs the default implementation with
 * real seams and passes it down; previews / un-hosted screens / tests get
 * [NoOpDelayedCheckinEffectHandler].
 */
interface DelayedCheckinEffectHandler {

    /** Route one effect. Safe to call from any thread; never throws on unwired surfaces. */
    fun handle(effect: DelayedCheckinEffect)

    /** Screen-level: transient feedback for the job screen's top banner. */
    val toasts: Flow<DelayedCheckinEffect.Toast>
}

/** No-op handler — the default when no host handler is wired (previews, tests, un-hosted screens). */
object NoOpDelayedCheckinEffectHandler : DelayedCheckinEffectHandler {
    override fun handle(effect: DelayedCheckinEffect) = Unit
    override val toasts: Flow<DelayedCheckinEffect.Toast> = emptyFlow()
}

/**
 * Production handler. A buffered channel (not `MutableSharedFlow(replay = 0)`)
 * so a toast fired just before the screen (re)subscribes is delivered, not
 * dropped.
 */
class DefaultDelayedCheckinEffectHandler(
    private val launcher: CustomerContactLauncher,
) : DelayedCheckinEffectHandler {

    private val _toasts = Channel<DelayedCheckinEffect.Toast>(Channel.BUFFERED)
    override val toasts: Flow<DelayedCheckinEffect.Toast> = _toasts.receiveAsFlow()

    override fun handle(effect: DelayedCheckinEffect) {
        when (effect) {
            is DelayedCheckinEffect.Dial -> launcher.dial(effect.number)
            is DelayedCheckinEffect.Toast -> _toasts.trySend(effect)
        }
    }
}
