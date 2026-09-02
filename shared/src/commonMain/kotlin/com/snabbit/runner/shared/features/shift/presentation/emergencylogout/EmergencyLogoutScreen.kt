package com.snabbit.runner.shared.features.shift.presentation.emergencylogout
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.snabbit.design.organisms.SnabbitBottomSheet
import com.snabbit.runner.shared.features.gamification.domain.model.CtaOverride
import com.snabbit.runner.shared.features.shift.presentation.emergencylogout.EmergencyLogoutSheet
import com.snabbit.runner.shared.features.shift.presentation.emergencylogout.TakeCareSheet

/**
 * Hosts the emergency-logout flow as a pure overlay — no `SnabbitScreen`
 * wrap and no opaque background. Renders only the DS `SnabbitBottomSheet`
 * (a Popup with its own scrim + slide-in animation), so the caller's
 * underlying screen stays mounted and visible behind it — Dart-parity with
 * `showModalBottomSheet(context: ...)`.
 *
 * Sheet selection switches on VM state:
 *  - period-leave success → [TakeCareSheet]
 *  - otherwise → [EmergencyLogoutSheet] (loading / error / content)
 *  - after Finish effect → [onFinish] (host clears its overlay flag)
 *
 * The sheet is non-dismissible while a confirm is in flight so the runner
 * can't kill the POST mid-call.
 */
@Composable
fun EmergencyLogoutScreen(
    viewModel: EmergencyLogoutViewModel,
    strings: EmergencyLogoutStrings = rememberEmergencyLogoutStrings(),
    onFinish: () -> Unit,
    @Suppress("UNUSED_PARAMETER") modifier: Modifier = Modifier,
    // Gamification data threaded from the Koin-aware host (HomeTabContent).
    logoutCta: CtaOverride? = null,
) {
    val state by viewModel.uiState.collectAsState()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                EmergencyLogoutUiEffect.Finish -> onFinish()
            }
        }
    }

    // Both sheets are always composed and toggled via `visible` (the DS sheet
    // animates in/out internally); their bodies read the live `state`, so no
    // last-value cache is needed. Mutually exclusive: take-care hides the main
    // sheet. The main sheet is non-dismissible while a confirm is in flight —
    // X hidden and scrim/back dismissal gated — so the runner can't kill the
    // POST mid-call.
    SnabbitBottomSheet(
        visible = state.showTakeCare,
        onDismissRequest = { viewModel.onIntent(EmergencyLogoutUiIntent.AcknowledgeTakeCare) },
        contentDescription = strings.sheetCloseContentDescription,
    ) {
        TakeCareSheet(
            strings = strings,
            onDone = { viewModel.onIntent(EmergencyLogoutUiIntent.AcknowledgeTakeCare) },
        )
    }
    SnabbitBottomSheet(
        visible = !state.showTakeCare && !state.finished,
        onDismissRequest = { if (!state.isSubmitting) viewModel.onIntent(EmergencyLogoutUiIntent.Dismiss) },
        showClose = !state.isSubmitting,
        contentDescription = strings.sheetCloseContentDescription,
    ) {
        EmergencyLogoutSheet(
            state = state,
            strings = strings,
            onTogglePeriodLeave = { viewModel.onIntent(EmergencyLogoutUiIntent.TogglePeriodLeave(it)) },
            onGoBack = { viewModel.onIntent(EmergencyLogoutUiIntent.Dismiss) },
            onConfirm = { viewModel.onIntent(EmergencyLogoutUiIntent.Confirm) },
            onRetry = { viewModel.onIntent(EmergencyLogoutUiIntent.Load) },
            logoutCta = logoutCta,
            // "Lose ₹X" tile — decoded off the availability payload
            // (ECPO-753); null (absent / non-positive) hides the tile.
            earningLossLabel = state.availability?.earningLossAmount?.let { "₹$it" },
        )
    }
}
