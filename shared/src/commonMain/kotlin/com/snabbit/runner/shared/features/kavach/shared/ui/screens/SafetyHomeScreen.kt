package com.snabbit.runner.shared.features.kavach.shared.ui.screens

import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.kavach_activation_error
import com.snabbit.runner.shared.resources.kavach_sos
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.kavach.shared.ui.components.KavachOverlaySheets
import com.snabbit.runner.shared.features.kavach.shared.ui.components.SafetyHomeCard
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetyHomeIntent
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetyHomeUiState
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import org.jetbrains.compose.resources.stringResource

/**
 * Kavach home skeleton — the SOS entry, the Kavach card, and the "no storage"
 * pill, with the condition/consent sheets overlaid from [SafetyHomeUiState.sheet].
 * Stateless: renders [uiState] and forwards actions via [onIntent].
 */
@Composable
fun SafetyHomeScreen(
    uiState: SafetyHomeUiState,
    onIntent: (SafetyHomeIntent) -> Unit,
) {
    val snackbarHostState = remember { SnackbarHostState() }
    // Activation/consent failure was invisible before — surface it as a transient snackbar (D2 clear).
    val activationError = stringResource(Res.string.kavach_activation_error)
    LaunchedEffect(uiState.error) {
        if (uiState.error != null) {
            snackbarHostState.showSnackbar(activationError)
            onIntent(SafetyHomeIntent.ErrorShown)
        }
    }

    SnabbitScreen(snackbarHostState = snackbarHostState) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(SnabbitTheme.spacing.`5`),
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`5`),
        ) {
            SnabbitButton(
                text = stringResource(Res.string.kavach_sos),
                onClick = { onIntent(SafetyHomeIntent.OpenSos) },
                style = SnabbitButtonStyle.Destructive,
                size = SnabbitButtonSize.S,
                modifier = Modifier.align(Alignment.End),
            )
            SafetyHomeCard(
                recording = uiState.recording,
                noStorage = uiState.noStorage,
                onActivate = { onIntent(SafetyHomeIntent.Activate) },
                onStorageClick = { onIntent(SafetyHomeIntent.RetryStorage) },
                activationLottiePlaying = uiState.activationLottiePlaying,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }

    // Overlay sheets (condition/consent, SOS alert, permission dialog) — shared with the job screen.
    KavachOverlaySheets(uiState = uiState, onIntent = onIntent)
}
