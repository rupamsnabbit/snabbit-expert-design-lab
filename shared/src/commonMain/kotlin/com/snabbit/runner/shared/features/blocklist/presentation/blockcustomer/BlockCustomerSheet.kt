package com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet
import com.snabbit.runner.shared.features.blocklist.presentation.list.BlockListUiIntent
import com.snabbit.runner.shared.features.blocklist.presentation.unblocktoblock.UnblockToBlock

/**
 * The **block-customer confirmation** bottom sheet — opens when the runner taps **Block** on a
 * [com.snabbit.runner.shared.features.job.presentation.completed.BlockCustomerCard]. Figma "Shift — Job Lifecycle DS"
 * node 13:11381; the KMP analogue of the Flutter `BlockBottomSheet` (`rating_block_handler.dart`).
 *
 * Two steps (driven by [BlockCustomerViewModel]):
 *  - [BlockCustomerStep.Confirm] — "Are you sure you want to block?" with **No** (closes) and **Yes**
 *    (blocks). No = [SnabbitButton] Secondary, Yes = Primary, split half-and-half.
 *  - [BlockCustomerStep.MaxReached] — when at the block cap, the [UnblockToBlock] surface (padded
 *    20/20 L-R, 24 top) so the runner frees a slot; unblocking there re-blocks the pending customer.
 *
 * A successful block fires the host's `onBlocked` — wired into [BlockCustomerViewModel] at
 * construction and invoked on the host scope, so it survives sheet dismissal (the host closes the
 * sheet + refreshes). [onDismiss] handles No / scrim / close. The customer name/address feed the
 * MaxReached header (the customer being blocked).
 */
@Composable
fun BlockCustomerSheet(
    viewModel: BlockCustomerViewModel,
    customerName: String,
    customerAddress: String,
    strings: BlockCustomerStrings,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsState()
    val blockListState by viewModel.blockListState.collectAsState()

    SnabbitBottomSheet(
        onDismissRequest = onDismiss,
        modifier = modifier,
        // Both steps render their own heading in the content, so the sheet's title bar is unused.
        title = null,
        draggable = false,
        dismissible = true,
        showCloseButton = true,
    ) {
        when (state.step) {
            BlockCustomerStep.Confirm -> BlockConfirmContent(
                strings = strings,
                isSubmitting = state.isSubmitting,
                errorMessage = state.errorMessage,
                onNo = onDismiss,
                onYes = { viewModel.onIntent(BlockCustomerUiIntent.ConfirmBlock) },
            )

            BlockCustomerStep.MaxReached -> Box(
                // Per the design spec: pad the unblock-to-block surface 20 L-R, 24 top.
                modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 24.dp),
            ) {
                UnblockToBlock(
                    customerName = customerName,
                    customerAddress = customerAddress,
                    blockListState = blockListState,
                    strings = strings.unblockToBlock,
                    onIntent = { intent ->
                        when (intent) {
                            is BlockListUiIntent.Unblock ->
                                viewModel.onIntent(BlockCustomerUiIntent.Unblock(intent.customerId))
                            BlockListUiIntent.Load ->
                                viewModel.onIntent(BlockCustomerUiIntent.RetryLoadList)
                            BlockListUiIntent.ErrorShown ->
                                viewModel.onIntent(BlockCustomerUiIntent.ErrorShown)
                        }
                    },
                )
            }
        }
    }
}

/** The "Are you sure?" confirm step (Figma 13:11373–11378): centered H2 + subtitle, then No / Yes. */
@Composable
private fun BlockConfirmContent(
    strings: BlockCustomerStrings,
    isSubmitting: Boolean,
    errorMessage: String?,
    onNo: () -> Unit,
    onYes: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        // Figma: 48 between the text block and the buttons.
        verticalArrangement = Arrangement.spacedBy(48.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            // Figma: 20 between the heading and the subtitle.
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            SnabbitText(
                text = strings.title,
                modifier = Modifier.fillMaxWidth(),
                // H2/24-Semibold, gray-900.
                fontSize = 24.sp,
                lineHeight = 32.sp,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textPrimary,
                textAlign = TextAlign.Center,
            )
            SnabbitText(
                // The block failure surfaces in place of the subtitle (no separate error design).
                text = errorMessage ?: strings.subtitle,
                modifier = Modifier.fillMaxWidth(),
                // Body-M/16-Medium, gray-500 (error swaps to textError).
                fontSize = 16.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.Medium,
                color = if (errorMessage != null) SnabbitTheme.colors.textError else SnabbitTheme.colors.textSecondary,
                textAlign = TextAlign.Center,
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SnabbitButton(
                text = strings.noLabel,
                onClick = onNo,
                modifier = Modifier.weight(1f),
                // Secondary = pink-50 fill, pink-600 text (Figma "No").
                style = SnabbitButtonStyle.Secondary,
                size = SnabbitButtonSize.L,
                enabled = !isSubmitting,
            )
            SnabbitButton(
                text = strings.yesLabel,
                onClick = onYes,
                modifier = Modifier.weight(1f),
                // Primary = pink-600 fill, white text (Figma "Yes").
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                enabled = !isSubmitting,
                loading = isSubmitting,
            )
        }
    }
}
