package com.snabbit.runner.shared.features.gamification.presentation.postaction

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome

/**
 * Mount-once overlay host that renders whatever [PostActionCoordinator] is
 * currently presenting — the KMP analogue of the Dart `PostActionOverlayController`
 * pushing its `DialogRoute` / `OverlayEntry`. Place it at the root of the KMP nav
 * host (above the current screen) so any feature that calls
 * [PostActionCoordinator.show] gets the popup without knowing about it.
 *
 * Routing mirrors Dart:
 *  - `status == waived` → [onWaived] (the host shows the waiver sheet — e.g.
 *    `home`'s `WaiverSheet` — then calls [PostActionCoordinator.dismiss] on
 *    acknowledgement to resume the suspended caller).
 *  - reward / penalty → [PostActionPopup], which dismisses itself after its hold.
 */
@Composable
fun PostActionOverlayHost(
    coordinator: PostActionCoordinator,
    onWaived: (PostActionOutcome) -> Unit = {},
) {
    val outcome by coordinator.current.collectAsState()
    val current = outcome ?: return

    if (current.isWaived) {
        LaunchedEffect(current) { onWaived(current) }
        return
    }
    PostActionPopup(outcome = current, onComplete = { coordinator.dismiss() })
}
