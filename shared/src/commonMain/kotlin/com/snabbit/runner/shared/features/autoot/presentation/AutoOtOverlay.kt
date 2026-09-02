package com.snabbit.runner.shared.features.autoot.presentation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import org.koin.compose.viewmodel.koinViewModel

/**
 * Always-composed Auto-OT layer for the bottom-nav shell (`TabNavigator`'s `overlay`), mirroring
 * `ActiveJobOverlay`. The shell-lived [AutoOtViewModel] observes the `AutoOtCoordinator` trigger
 * (derived from the runner-state stream) and drives its own visibility: [AutoOtSheet] renders a
 * `SnabbitBottomSheet` when there's an active offer/flow, and nothing otherwise.
 *
 * Sits over all tabs, matching Flutter's global (navigatorKey) Auto-OT bottom sheet. Job stages
 * preempt OT (the coordinator emits `Preempt`), so it never overlaps the active-job screen.
 */
@Composable
fun AutoOtOverlay(viewModel: AutoOtViewModel = koinViewModel()) {
    val state by viewModel.uiState.collectAsState()
    AutoOtSheet(state = state, onIntent = viewModel::onIntent)
}
