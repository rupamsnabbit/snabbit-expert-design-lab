package com.snabbit.runner.shared.features.blocklist.presentation.unblocktoblock

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.ui.components.SnabbitNavigationCard
import com.snabbit.runner.shared.ui.icons.AppIcons
import com.snabbit.runner.shared.features.blocklist.presentation.list.BlockList
import com.snabbit.runner.shared.features.blocklist.presentation.list.BlockListUiIntent
import com.snabbit.runner.shared.features.blocklist.presentation.list.BlockListUiState
import com.snabbit.runner.shared.features.blocklist.presentation.list.BlockListViewModel
import com.snabbit.runner.shared.features.blocklist.domain.model.BlockedCustomer

/**
 * **Unblock to block** — shown when the runner tries to block a customer but has already hit the
 * block cap. A gradient alert header ("Unblock someone to block <name>"), the customer they want to
 * block in a [SnabbitNavigationCard], then the [BlockList] so they can free a slot by unblocking
 * someone. Figma "Shift — Job Lifecycle DS" node 13:12128; the KMP analogue of the full Flutter
 * `ManageBlockList` (`lib/widgets/job_in_progress/rating_block_handler.dart`).
 *
 * Host-agnostic (draws no top nav / scaffold) so it drops into a bottom sheet or screen — the caller
 * provides the SnabbitTheme + insets. This composable owns the outer scroll ([BlockList] no longer
 * self-scrolls, so there's no nested scrollable).
 *
 * @param customerName the customer the runner is trying to block (shown pink in the title + card).
 * @param customerAddress that customer's address, for the navigation card.
 */
@Composable
fun UnblockToBlock(
    customerName: String,
    customerAddress: String,
    viewModel: BlockListViewModel,
    strings: UnblockToBlockStrings = UnblockToBlockStrings(),
    modifier: Modifier = Modifier,
) {
    val blockListState by viewModel.uiState.collectAsState()
    UnblockToBlock(
        customerName = customerName,
        customerAddress = customerAddress,
        blockListState = blockListState,
        onIntent = viewModel::onIntent,
        strings = strings,
        modifier = modifier,
    )
}

/** Stateless overload — previewable/testable with a hand-built [BlockListUiState]. */
@Composable
fun UnblockToBlock(
    customerName: String,
    customerAddress: String,
    blockListState: BlockListUiState,
    onIntent: (BlockListUiIntent) -> Unit,
    strings: UnblockToBlockStrings = UnblockToBlockStrings(),
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState()),
        // Figma: 20 between the header, the customer card, and the block list.
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        UnblockToBlockHeader(customerName = customerName, titlePrefix = strings.titlePrefix)

        // The customer being blocked — the DS navigation card in its name-only variant.
        SnabbitNavigationCard(
            customerName = customerName,
            address = customerAddress,
        )

        // The block list — reuses the existing feature (renders its own loading / error / toast).
        BlockList(
            state = blockListState,
            strings = strings.blockList,
            onIntent = onIntent,
        )
    }
}

/** Gradient alert icon over the two-tone "Unblock someone to block <name>" heading (centered). */
@Composable
private fun UnblockToBlockHeader(customerName: String, titlePrefix: String) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Image(
            imageVector = AppIcons.UnblockWarning,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
        )
        // Two-tone H2 title — prefix gray-900, the customer name brand-pink. Rendered as two centered
        // lines (SnabbitText takes no AnnotatedString); matches the Figma line break for this copy.
        Column(modifier = Modifier.fillMaxWidth()) {
            SnabbitText(
                text = titlePrefix,
                modifier = Modifier.fillMaxWidth(),
                fontSize = 24.sp,
                lineHeight = 32.sp,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textPrimary,
                textAlign = TextAlign.Center,
            )
            SnabbitText(
                text = customerName,
                modifier = Modifier.fillMaxWidth(),
                fontSize = 24.sp,
                lineHeight = 32.sp,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textBrand,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/* ── Preview ─────────────────────────────────────────────────────────── */

private const val PREVIEW_ADDRESS =
    "HAL Old Airport Rd, Near Railway Over Bridge, LN Pura, Marathahalli, Bengaluru, Karnataka 560037"

@Preview
@Composable
private fun PreviewUnblockToBlock() {
    SnabbitTheme {
        Column(Modifier.background(SnabbitTheme.colors.bgPrimary).padding(16.dp)) {
            UnblockToBlock(
                customerName = "Radhika S",
                customerAddress = "HAL Old Airport rd, near railway over bridge, LN Pura, Marathahalli, Bengaluru",
                blockListState = BlockListUiState(
                    isLoading = false,
                    customers = listOf(
                        BlockedCustomer(1, "Sreelakshmi Raj", PREVIEW_ADDRESS),
                        BlockedCustomer(2, "Prashant K", PREVIEW_ADDRESS),
                        BlockedCustomer(3, "Neha Yadav", PREVIEW_ADDRESS),
                    ),
                    maxLimit = 5,
                ),
                onIntent = {},
            )
        }
    }
}
