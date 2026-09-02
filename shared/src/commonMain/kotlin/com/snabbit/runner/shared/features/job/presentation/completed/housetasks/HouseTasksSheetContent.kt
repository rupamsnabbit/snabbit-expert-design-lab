package com.snabbit.runner.shared.features.job.presentation.completed.housetasks

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.domain.model.HouseTask
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.resolve

// Grid geometry — a 3-column grid of aspect-ratio (337:372) tiles with 12dp gaps. (The Flutter
// `TasksDoneByRunner` used `crossAxisCount: 2`; this sheet is 3-column by product decision — confirmed
// 2026-07-13, do not "fix" back to 2.) Each tile renders the task's remote `asset_link` illustration
// (Crop-filled) from the `task_collection` response. The grid is sized to its content height (fits all
// tiles) but capped at 90% of the space the sheet affords, rather than the fixed 268dp Figma "Slot"; the
// tile height follows the aspect, so it is derived from the measured column width.
private const val GRID_COLUMNS = 3
private val GRID_GAP = 12.dp
private const val TILE_ASPECT = 337f / 372f // width : height of a tile.
private val LOADING_HEIGHT = 160.dp

/**
 * **"What tasks did you do?"** — the post-checkout house-tasks picker body (ECPO-528): a title, then one
 * of three states over [HouseTasksUiState] — a loading spinner, a fetch-error message + **Try again**, or
 * a 3-column grid of tappable task illustrations plus a **Confirm** button. The task list is backend-driven
 * (`task_collection`); each tile renders the task's remote `asset_link` illustration. The KMP analogue of
 * `TasksDoneByRunner` in `rate_customer.dart`.
 *
 * **Content only** — not wrapped in a [com.snabbit.runner.shared.ui.components.SnabbitBottomSheet]; the
 * caller ([com.snabbit.runner.shared.features.job.presentation.JobScreen]) adds the forced (non-dismissible)
 * sheet chrome. Design tokens + DS components only.
 *
 * @param onToggle a tile was tapped → toggle its [HouseTask.key] in the selection.
 * @param onRetry the fetch-error **Try again** was tapped → refetch.
 * @param onSubmit the **Confirm** was tapped → submit the selection.
 */
@Composable
internal fun HouseTasksSheetContent(
    state: HouseTasksUiState,
    strings: JobStrings,
    onToggle: (key: String) -> Unit,
    onRetry: () -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(32.dp),
    ) {
        SnabbitText(
            text = strings.tasksDoneTitle,
            variant = SnabbitTextVariant.Heading2,
            color = SnabbitTheme.colors.textPrimary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )

        when {
            // Initial fetch in flight.
            state.isLoading -> Box(
                modifier = Modifier.fillMaxWidth().height(LOADING_HEIGHT),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(color = SnabbitTheme.colors.iconBrand)
            }

            // Nothing to show (fetch failed, or an unexpected empty list) — offer a retry, the only way
            // forward on a forced sheet.
            state.tasks.isEmpty() -> Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                SnabbitText(
                    text = state.errorMessage?.let { strings.resolve(it) } ?: strings.genericError,
                    variant = SnabbitTextVariant.BodyMd,
                    color = SnabbitTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
                SnabbitButton(
                    text = strings.tryAgain,
                    onClick = onRetry,
                    style = SnabbitButtonStyle.Primary,
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                )
            }

            // Loaded — the selectable grid + Confirm.
            else -> {
                HouseTasksGrid(
                    tasks = state.tasks,
                    selectedKeys = state.selectedKeys,
                    onToggle = onToggle,
                )
                // A submit failure (or an empty-selection tap) shows its message inline above Confirm.
                if (state.errorMessage != null) {
                    SnabbitText(
                        text = strings.resolve(state.errorMessage),
                        variant = SnabbitTextVariant.BodyMd,
                        color = SnabbitTheme.colors.textError,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                SnabbitButton(
                    text = strings.confirmAction,
                    onClick = onSubmit,
                    style = SnabbitButtonStyle.Primary,
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                    // Disabled until at least one task is picked ([canSubmit]); also disabled while the
                    // submit POST is in flight, where it shows a spinner instead.
                    enabled = state.canSubmit && !state.isSubmitting,
                    loading = state.isSubmitting,
                )
            }
        }
    }
}

/**
 * The multi-select task grid: a 3-column grid of [HouseTaskTile]s. Height wraps the grid, capped at 90%
 * of the space the sheet affords, so a short list wraps snugly and a long list scrolls inside the grid.
 * Tile height is derived from the measured column width to hold the 337:372 illustration aspect.
 */
@Composable
private fun HouseTasksGrid(
    tasks: List<HouseTask>,
    selectedKeys: Set<String>,
    onToggle: (key: String) -> Unit,
) {
    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        val columnWidth = (maxWidth - GRID_GAP * (GRID_COLUMNS - 1)) / GRID_COLUMNS
        val tileHeight = columnWidth / TILE_ASPECT
        val rows = (tasks.size + GRID_COLUMNS - 1) / GRID_COLUMNS
        val wrapHeight = tileHeight * rows + GRID_GAP * (rows - 1).coerceAtLeast(0)
        val gridHeight =
            if (constraints.hasBoundedHeight) minOf(wrapHeight, maxHeight * 0.9f) else wrapHeight

        LazyVerticalGrid(
            columns = GridCells.Fixed(GRID_COLUMNS),
            modifier = Modifier
                .fillMaxWidth()
                .height(gridHeight),
            horizontalArrangement = Arrangement.spacedBy(GRID_GAP),
            verticalArrangement = Arrangement.spacedBy(GRID_GAP),
        ) {
            items(tasks, key = { it.key }) { task ->
                HouseTaskTile(
                    task = task,
                    selected = task.key in selectedKeys,
                    onToggle = { onToggle(task.key) },
                )
            }
        }
    }
}

/**
 * One selectable task tile: the task's remote `asset_link` illustration (Crop-filled), clipped to r-12.
 * Selection is shown by a 2dp brand-pink border and nothing else.
 */
@Composable
private fun HouseTaskTile(
    task: HouseTask,
    selected: Boolean,
    onToggle: () -> Unit,
) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(TILE_ASPECT)
            .clip(shape)
            .clickable(onClick = onToggle)
            .then(
                if (selected) Modifier.border(2.dp, SnabbitTheme.colors.iconBrand, shape) else Modifier,
            ),
    ) {
        SnabbitRemoteImage(
            model = task.imageUrl,
            contentDescription = task.key,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop,
        )
    }
}
