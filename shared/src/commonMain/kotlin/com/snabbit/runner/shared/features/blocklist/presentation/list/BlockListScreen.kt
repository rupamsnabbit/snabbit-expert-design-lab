package com.snabbit.runner.shared.features.blocklist.presentation.list

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitListContainer
import com.snabbit.design.atoms.SnabbitListItem
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitToast
import com.snabbit.design.atoms.SnabbitToastVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.ui.components.ErrorStateAction
import com.snabbit.runner.shared.ui.components.ErrorStateActions
import com.snabbit.runner.shared.ui.components.GeneralErrorState
import com.snabbit.runner.shared.ui.icons.AppIcons
import com.snabbit.runner.shared.features.blocklist.domain.model.BlockedCustomer

/**
 * Block list feature — the runner's blocked customers with a per-row Unblock action. Figma
 * "Shift — Job Lifecycle DS" node 13:12134. Migrated from the Flutter `ManageBlockList`
 * (`lib/widgets/job_in_progress/rating_block_handler.dart`).
 *
 * Stateful entry: collects [BlockListViewModel.uiState] and renders the stateless overload below.
 * Host-agnostic — it draws no top nav of its own, so it slots into the host's SnabbitTheme +
 * scaffold (e.g. a bottom sheet, as in Flutter).
 */
@Composable
fun BlockList(
    viewModel: BlockListViewModel,
    strings: BlockListStrings,
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsState()
    BlockList(
        state = state,
        strings = strings,
        onIntent = viewModel::onIntent,
        modifier = modifier,
    )
}

/**
 * Stateless Block list — three-state (loading / error+retry / empty / content). A failed unblock
 * surfaces a transient [SnabbitToast] over the still-present list. Previewable and testable with a
 * hand-built [BlockListUiState].
 */
@Composable
fun BlockList(
    state: BlockListUiState,
    strings: BlockListStrings,
    onIntent: (BlockListUiIntent) -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier.fillMaxWidth()) {
        when {
            state.isLoading -> Box(
                modifier = Modifier.fillMaxWidth().padding(24.dp),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(color = SnabbitTheme.colors.iconBrand)
            }

            // On-load failure (list empty + a non-transient load error) → the shared error state with
            // a retry. `errorIsTransient` keeps a failed re-block that emptied the list (a toast) from
            // masquerading as a load failure here.
            // A bounded height is required: the host (UnblockToBlock) wraps this in a verticalScroll
            // and GeneralErrorState weights + self-scrolls its content, so an unbounded height would
            // collapse it (and can crash on nested infinite constraints).
            state.errorMessage != null && !state.errorIsTransient && state.customers.isEmpty() -> GeneralErrorState(
                modifier = Modifier.fillMaxWidth().height(LOAD_ERROR_STATE_HEIGHT),
                title = strings.loadError,
                subtitle = strings.loadErrorSubtitle,
                actions = ErrorStateActions(
                    listOf(
                        ErrorStateAction(
                            label = strings.retryLabel,
                            onClick = { onIntent(BlockListUiIntent.Load) },
                        ),
                    ),
                ),
            )

            // "Nobody blocked" — the plain empty state (no error, so no retry).
            state.customers.isEmpty() -> Column(
                modifier = Modifier.fillMaxWidth().padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                SnabbitText(
                    text = strings.emptyMessage,
                    fontSize = 14.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Normal,
                    color = SnabbitTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }

            else -> BlockListContent(
                state = state,
                strings = strings,
                onUnblock = { onIntent(BlockListUiIntent.Unblock(it)) },
            )
        }

        // Transient action failure → auto-dismissing error toast. Fires for any transient error
        // (unblock / re-block — including one that emptied the list) or a load error while the list is
        // still populated; the empty-list load failure shows the error state above instead.
        if (state.errorMessage != null && (state.errorIsTransient || state.customers.isNotEmpty())) {
            SnabbitToast(
                title = state.errorMessage,
                variant = SnabbitToastVariant.Error,
                durationMillis = ERROR_TOAST_DURATION_MS,
                onDismiss = { onIntent(BlockListUiIntent.ErrorShown) },
                modifier = Modifier.align(Alignment.BottomCenter).padding(16.dp),
            )
        }
    }
}

private const val ERROR_TOAST_DURATION_MS = 3000L

/** Bounded height for the on-load error state. GeneralErrorState weights + self-scrolls its content,
 *  so it needs a finite height inside the host's verticalScroll (see the load-error branch). Roomy
 *  enough for icon + title + subtitle + retry without scrolling; confirm vs Figma node 991:58006. */
private val LOAD_ERROR_STATE_HEIGHT = 320.dp

/** The loaded frame (Figma 13:12134): the "Block list  ·  n[/max] People blocked" header above the
 *  blocked customers, split by gray-100 hairlines. */
@Composable
private fun BlockListContent(
    state: BlockListUiState,
    strings: BlockListStrings,
    onUnblock: (Int) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        // Figma: 16 between the header and the list. Scrolling is owned by the host (bottom sheet
        // or the unblock-to-block screen), so this frame doesn't self-scroll (avoids nested scroll).
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // ── Header: "Block list"  ⟷  "n[/max] People blocked" (the "/max" shows only when a cap is
        //    known — it's server-enforced, so the client usually has no number and renders just "n"). ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SnabbitText(
                text = strings.title,
                // Body-L/18-Semibold, gray-900.
                fontSize = 18.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textPrimary,
            )
            SnabbitText(
                text = state.maxLimit
                    ?.let { "${state.blockedCount}/$it ${strings.peopleBlocked}" }
                    ?: "${state.blockedCount} ${strings.peopleBlocked}",
                // Body-S/14-Medium, status-red (Figma #e93544 ≈ the `textError` token).
                fontSize = 14.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Medium,
                color = SnabbitTheme.colors.textError,
            )
        }

        // ── Blocked customers, split by hairlines (uniform 16 between every row and divider). ──
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            state.customers.forEachIndexed { index, customer ->
                if (index > 0) BlockListDivider()
                BlockedCustomerRow(
                    customer = customer,
                    strings = strings,
                    unblocking = state.unblockingCustomerId == customer.customerId,
                    enabled = !state.isUnblocking,
                    onUnblock = { onUnblock(customer.customerId) },
                )
            }
        }
    }
}

/**
 * One blocked-customer row (Figma item component): the [AppIcons.Customer] mark + name over the
 * address, with a trailing outline **Unblock** CTA. Built on the DS [SnabbitListItem] slot core.
 */
@Composable
private fun BlockedCustomerRow(
    customer: BlockedCustomer,
    strings: BlockListStrings,
    unblocking: Boolean,
    enabled: Boolean,
    onUnblock: () -> Unit,
) {
    SnabbitListItem(
        container = SnabbitListContainer.Plain,
        titleContent = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SnabbitIcon(
                        imageVector = AppIcons.Customer,
                        size = 12.dp,
                        color = SnabbitTheme.colors.textPrimary,
                    )
                    SnabbitText(
                        text = customer.name ?: strings.fallbackName,
                        modifier = Modifier.weight(1f, fill = false),
                        // Body-S/14-Medium, gray-700.
                        fontSize = 14.sp,
                        lineHeight = 20.sp,
                        fontWeight = FontWeight.Medium,
                        color = SnabbitTheme.colors.textBody,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                customer.address?.let { address ->
                    SnabbitText(
                        text = address,
                        modifier = Modifier.fillMaxWidth(),
                        // Caption/12-Regular, gray-500, single line ellipsised.
                        fontSize = 12.sp,
                        lineHeight = 16.sp,
                        fontWeight = FontWeight.Normal,
                        color = SnabbitTheme.colors.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        },
        trailingContent = {
            SnabbitButton(
                text = strings.unblockLabel,
                onClick = onUnblock,
                // Outline pink CTA (border + text #F70F79) at the 32dp / r-6 XS size.
                style = SnabbitButtonStyle.Tertiary,
                size = SnabbitButtonSize.XS,
                enabled = enabled,
                loading = unblocking,
            )
        },
    )
}

/** 1.2dp gray-100 hairline between rows (Figma: 1.2px #F3F4F6). DS `SnabbitDivider(Line)` is
 *  gray-200, so the lighter gray-100 line is drawn from the `borderSubtle` token. */
@Composable
private fun BlockListDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.2.dp)
            .background(SnabbitTheme.colors.borderSubtle),
    )
}

/* ── Preview ─────────────────────────────────────────────────────────── */

private const val SAMPLE_ADDRESS =
    "HAL Old Airport Rd, Near Railway Over Bridge, LN Pura, Marathahalli, Bengaluru, Karnataka 560037"

@Preview
@Composable
private fun PreviewBlockList() {
    SnabbitTheme {
        Box(Modifier.background(SnabbitTheme.colors.bgPrimary).padding(16.dp)) {
            BlockList(
                state = BlockListUiState(
                    isLoading = false,
                    customers = listOf(
                        BlockedCustomer(1, "Sreelakshmi Raj", SAMPLE_ADDRESS),
                        BlockedCustomer(2, "Prashant K", SAMPLE_ADDRESS),
                        BlockedCustomer(3, "Neha Yadav", SAMPLE_ADDRESS),
                    ),
                    maxLimit = 5,
                ),
                strings = BlockListStrings(),
                onIntent = {},
            )
        }
    }
}

@Preview
@Composable
private fun PreviewBlockListLoadError() {
    SnabbitTheme {
        Box(Modifier.background(SnabbitTheme.colors.bgPrimary).padding(16.dp)) {
            BlockList(
                state = BlockListUiState(
                    isLoading = false,
                    customers = emptyList(),
                    errorMessage = BlockListStrings().loadError,
                ),
                strings = BlockListStrings(),
                onIntent = {},
            )
        }
    }
}
