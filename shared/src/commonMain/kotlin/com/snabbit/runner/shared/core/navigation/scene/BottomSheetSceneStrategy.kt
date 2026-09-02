package com.snabbit.runner.shared.core.navigation.scene

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.runtime.Composable
import androidx.navigation3.runtime.NavEntry
import androidx.navigation3.scene.OverlayScene
import androidx.navigation3.scene.Scene
import androidx.navigation3.scene.SceneStrategy
import androidx.navigation3.scene.SceneStrategyScope

/**
 * Renders a destination whose entry carries [bottomSheet] metadata as a material3
 * [ModalBottomSheet] overlaying the screen beneath it. No such metadata → returns
 * `null` so the next strategy (dialog / single-pane) handles the entry.
 *
 * Nav3 1.1.2 ships a `DialogSceneStrategy` but no bottom-sheet equivalent, so this is
 * the app-authored `OverlayScene` strategy (Google's recipe). Dismiss (swipe / scrim)
 * funnels through [SceneStrategyScope.onBack], keeping the controller's back stack the
 * single source of truth.
 */
class BottomSheetSceneStrategy<T : Any> : SceneStrategy<T> {
    // calculateScene is an extension on SceneStrategyScope (the scope is the receiver,
    // exposing `onBack`).
    override fun SceneStrategyScope<T>.calculateScene(
        entries: List<NavEntry<T>>,
    ): Scene<T>? {
        val top = entries.lastOrNull() ?: return null
        if (top.metadata[BOTTOM_SHEET_KEY] != true) return null
        return BottomSheetScene(
            key = top.contentKey,
            sheetEntry = top,
            overlaid = entries.dropLast(1),
            onBack = onBack,
        )
    }

    companion object {
        private const val BOTTOM_SHEET_KEY = "com.snabbit.runner.shared.core.navigation.bottomSheet"

        /** Entry metadata that makes a destination render as a bottom sheet. */
        fun bottomSheet(): Map<String, Any> = mapOf(BOTTOM_SHEET_KEY to true)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
private class BottomSheetScene<T : Any>(
    override val key: Any,
    private val sheetEntry: NavEntry<T>,
    private val overlaid: List<NavEntry<T>>,
    private val onBack: () -> Unit,
) : OverlayScene<T> {
    override val entries: List<NavEntry<T>> = listOf(sheetEntry)
    override val previousEntries: List<NavEntry<T>> = overlaid
    override val overlaidEntries: List<NavEntry<T>> = overlaid
    override val content: @Composable () -> Unit = {
        ModalBottomSheet(onDismissRequest = onBack) {
            sheetEntry.Content()
        }
    }
}
