package com.snabbit.runner.shared.features.home.seeyoutomorrow.data

import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Read model for the `RUNNER_SEE_YOU_TOMORROW` state — the post-shift-logout
 * takeover (CMP port of Dart `see_you_tomorrow.dart`). Folds the `current_state`
 * envelope stream into a single [active] boolean: `true` while the widget is
 * `RUNNER_SEE_YOU_TOMORROW`, `false` for every other widget. Sibling of
 * `ShiftProjector` / `SuspendedProjector`, each owning its own widget slice.
 *
 * Deliberately a bare boolean, not a typed info model like `SuspendedInfo`: the
 * see-you-tomorrow envelope carries no `widget_data` the card renders (it is a
 * static "See you tomorrow!" panel with two nav CTAs), and the runner
 * rate-card-v2 flag the "Go to Earnings" CTA needs already rides on the VM's
 * `RunnerProfileStore`. Grow into an info model only if real per-widget fields
 * appear.
 *
 * Concrete class, no interface — matches `ShiftProjector` / `SuspendedProjector`.
 */
class SeeYouTomorrowProjector(
    private val store: RunnerStateStore,
    scope: CoroutineScope,
) {
    private val _active = MutableStateFlow(false)

    /** `true` while the runner is in the post-logout see-you-tomorrow state. */
    val active: StateFlow<Boolean> = _active.asStateFlow()

    init {
        scope.launch {
            store.state.collect { _active.value = it?.widgetName == RUNNER_SEE_YOU_TOMORROW }
        }
    }

    private companion object {
        const val RUNNER_SEE_YOU_TOMORROW = "RUNNER_SEE_YOU_TOMORROW"
    }
}
