package com.snabbit.runner.awol

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import com.snabbit.runner.overlayhost.OverlayHostSession
import com.snabbit.runner.overlayhost.OverlaySpec
import com.snabbit.runner.overlayhost.OverlayWindowStyle
import com.snabbit.runner.shared.features.awol.data.hasAwolPayload
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.awol.domain.localized
import com.snabbit.runner.shared.features.awol.presentation.AwolEffect
import com.snabbit.runner.shared.features.awol.presentation.AwolSurface
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * The AWOL alert as a [ComposeOverlayHost] plug-in (TRD §8): dim-modal
 * window, `visible = surface == OVERLAY`, renders the shared
 * [com.snabbit.runner.shared.features.awol.presentation.ui.AwolOverlaySurface].
 * The spec holds no state of its own — the process-lived [AwolViewModel]
 * (Koin single) owns episode memory and routing, so the window content and
 * the dismissal signal can never disagree (FR-09), and "I Understand"
 * (surface → NONE) tears the window down through the same `visible` flow
 * (FR-05, feed-driven dismissal).
 *
 * [shouldTrigger] answers the generic launcher's store-driven `maybeLaunch`
 * from the emission itself ([hasAwolPayload]) — deterministic, so a
 * killed-state launch never races the coordinator's processing of the same
 * emission. The launcher gates background + RC flag + `canDrawOverlays`; the
 * ViewModel re-checks flag + permission + dismissal when routing, so a
 * misfire (e.g. a dismissed episode) self-dismisses via `visible` instead of
 * misrouting.
 *
 * `priority` beats new-job: penalty beats opportunity (job-v2 policy carried
 * forward as a host-internal comparison — the legacy `OverlayService.instance`
 * mechanism is gone).
 */
class AwolOverlaySpec : OverlaySpec, KoinComponent {

    private val viewModel: AwolViewModel by inject()
    private val store: LocalizationStore by inject()

    override val key: String = KEY
    override val window: OverlayWindowStyle = OverlayWindowStyle.DimModal
    override val priority: Int = PRIORITY

    // AWOL is a safety alert: draw over the app even when it's open (foreground), not
    // just backgrounded/locked. The VM routes OVERLAY in foreground too, so the window's
    // `visible` flow stays true; "I Understand" flips the surface to HOME_CARD and this
    // window self-dismisses, leaving the in-app pink card underneath.
    override val drawsOverForegroundApp: Boolean = true

    override fun shouldTrigger(state: RunnerState?): Boolean = state.hasAwolPayload()

    // Dismissed-this-episode memory lives in the process-lived VM (FR-05);
    // answering the launcher from the emission itself keeps a dismissed phase
    // from churning the host FGS up on every store refresh, while a phase flip
    // within the episode (a NEW alert, FR-06) is not suppressed and presents.
    override fun suppressedFor(state: RunnerState?): Boolean = viewModel.isPhaseDismissed(state)

    override fun visible(session: OverlayHostSession): Flow<Boolean> =
        viewModel.uiState.map { it.surface == AwolSurface.OVERLAY }

    @Composable
    override fun Content(session: OverlayHostSession) {
        val context = LocalContext.current
        LaunchedEffect(Unit) {
            viewModel.effects.collect { effect ->
                when (effect) {
                    is AwolEffect.OpenDirections -> openAwolDirections(context, effect)
                }
            }
        }
        com.snabbit.runner.shared.features.awol.presentation.ui.AwolOverlaySurface(
            viewModel = viewModel,
            strings = AwolStrings().localized(store),
        )
    }

    companion object {
        const val KEY = "awol"

        /** Above new-job: an active penalty warning beats an incoming job. */
        const val PRIORITY = 100
    }
}
