package com.snabbit.runner.shared.features.job.presentation.completed.housetasks

import com.snabbit.runner.shared.features.job.domain.model.HouseTask
import com.snabbit.runner.shared.features.job.domain.model.JobMessage

/**
 * Render state for the post-checkout house-tasks sheet
 * ([com.snabbit.runner.shared.features.job.presentation.completed.housetasks.HouseTasksSheetContent]) — the forced,
 * show-once "What tasks did you do?" selector shown on the POST_CHECKOUT stage (ECPO-528).
 *
 * The sheet fetches its [tasks] on open; the runner multi-selects ([selectedKeys]) and confirms, which
 * POSTs the selected keys. A fetch failure surfaces [errorMessage] with a retry; a submit failure keeps
 * the grid up and shows [errorMessage] inline.
 *
 * @property tasks the selectable house tasks (backend `task_collection`); empty until loaded.
 * @property selectedKeys the [HouseTask.key]s the runner has picked.
 * @property isLoading the initial fetch is in flight.
 * @property isSubmitting the `update_task_collection` POST is in flight (Confirm spins).
 * @property errorMessage fetch- or submit-failure copy; null when none.
 */
data class HouseTasksUiState(
    val tasks: List<HouseTask> = emptyList(),
    val selectedKeys: Set<String> = emptySet(),
    val isLoading: Boolean = true,
    val isSubmitting: Boolean = false,
    val errorMessage: JobMessage? = null,
) {
    /** At least one task picked → the Confirm CTA enables (mirrors the Flutter confirm gate). */
    val canSubmit: Boolean get() = selectedKeys.isNotEmpty()

    /**
     * The initial `task_collection` fetch failed (not loading, no tasks, an error set) → the forced sheet
     * becomes dismissible so the runner isn't trapped behind the scrim. A successful-but-empty fetch
     * closes the gate instead, and a submit error keeps [tasks] populated, so this is only ever a real
     * fetch failure.
     */
    val isFetchError: Boolean get() = !isLoading && tasks.isEmpty() && errorMessage != null
}

/**
 * Every user action on the house-tasks sheet, as data. The screen sends these to
 * [HouseTasksViewModel.onIntent] — single input channel, so all transitions live in one exhaustive `when`.
 */
sealed interface HouseTasksUiIntent {
    /** Retry the initial fetch after it failed. */
    data object Retry : HouseTasksUiIntent

    /** Toggle the task with this [key] in/out of the selection. */
    data class Toggle(val key: String) : HouseTasksUiIntent

    /** Confirm the selection — POST the selected keys (`update_task_collection`). */
    data object Submit : HouseTasksUiIntent
}
