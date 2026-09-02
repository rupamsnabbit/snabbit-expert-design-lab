package com.snabbit.runner.shared.features.language.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.atoms.SnabbitToast
import com.snabbit.design.atoms.SnabbitToastVariant
import com.snabbit.design.molecules.SnabbitSelectionCard
import com.snabbit.design.molecules.SnabbitSelectionCardType
import com.snabbit.design.molecules.SnabbitSelectionCardVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen

/**
 * The Language screen — a Compose Multiplatform UI shell over a Flutter
 * data/logic backend (see [LanguageViewModel]).
 *
 * Stateless: it receives the [state] + [strings] and an [onIntent] lambda, never
 * the ViewModel. The host collects `uiState` (via `collectAsStateWithLifecycle`)
 * and forwards intents here; dismissal is the VM's job via the injected
 * `NavigationController` (no one-shot effect channel).
 *
 * Chrome — theme, `bgPrimary`, status/nav-bar insets, top nav, snackbar host —
 * comes from [SnabbitScreen], the app's standard screen scaffold. This screen
 * supplies only its unique parts: the confirm CTA, the body, and the save-error
 * snackbar effect.
 *
 * Body visuals use Snabbit Design System components (`com.snabbit:design-system`):
 * - [SnabbitSelectionCard] for each language row (radio + title + description)
 * - [SnabbitButton] for the confirm CTA
 *
 * Note: We dropped the original per-row icon circles. The DS selection card's
 * layout puts the radio on the *left* with title/description to its right and
 * a *trailing* slot reserved for small affordances (badges, chevrons) — not a
 * 48 dp visual. Going with DS consistency over the legacy layout.
 */
@Composable
fun LanguageScreen(
    state: LanguageUiState,
    strings: LanguageStrings,
    onIntent: (LanguageUiIntent) -> Unit,
    modifier: Modifier = Modifier,
    onNavigateUp: (() -> Unit)? = null,
) {
    val snackbarHostState = remember { SnackbarHostState() }

    // Save failures surface as a transient snackbar (the list is still shown).
    // Load failures render inline instead — see the `when` in LanguageContent.
    LaunchedEffect(state.errorMessage) {
        val message = state.errorMessage
        if (message != null && state.languages.isNotEmpty()) {
            snackbarHostState.showSnackbar(message)
            onIntent(LanguageUiIntent.ErrorShown)
        }
    }

    SnabbitScreen(
        modifier = modifier,
        title = strings.title,
        onNavigateUp = onNavigateUp,
        snackbarHostState = snackbarHostState,
        bottomBar = {
            SnabbitButton(
                text = strings.confirmButton,
                onClick = { onIntent(LanguageUiIntent.Confirm) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 16.dp),
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                enabled = state.canConfirm,
                loading = state.isSaving,
                fullWidth = true,
            )
        },
    ) { contentPadding ->
        Box(modifier = Modifier.fillMaxSize()) {
            LanguageContent(
                state = state,
                strings = strings,
                contentPadding = contentPadding,
                onSelect = { onIntent(LanguageUiIntent.Select(it)) },
                onRetry = { onIntent(LanguageUiIntent.Load) },
            )

            // Success feedback: a DS toast that auto-dismisses, then closes the
            // screen (onDismiss -> SaveAcknowledged -> Dismiss effect). Floats
            // bottom-center, clear of the top nav + confirm CTA via contentPadding.
            if (state.saveSucceeded) {
                SnabbitToast(
                    title = strings.savedMessage,
                    variant = SnabbitToastVariant.Success,
                    durationMillis = SUCCESS_TOAST_DURATION_MS,
                    onDismiss = { onIntent(LanguageUiIntent.SaveAcknowledged) },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(contentPadding)
                        .padding(16.dp),
                )
            }
        }
    }
}

private const val SUCCESS_TOAST_DURATION_MS = 2500L

@Composable
private fun LanguageContent(
    state: LanguageUiState,
    strings: LanguageStrings,
    contentPadding: PaddingValues,
    onSelect: (String) -> Unit,
    onRetry: () -> Unit,
) {
    when {
        state.isLoading -> Box(
            modifier = Modifier.fillMaxSize().padding(contentPadding),
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator(color = SnabbitTheme.colors.iconBrand)
        }

        state.languages.isEmpty() -> Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(contentPadding)
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            SnabbitText(
                text = state.errorMessage ?: strings.emptyMessage,
                variant = SnabbitTextVariant.BodyMd,
                color = SnabbitTheme.colors.textSecondary,
                textAlign = TextAlign.Center,
            )
            SnabbitButton(
                text = strings.retryLabel,
                onClick = onRetry,
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = false,
            )
        }

        else -> LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                top = contentPadding.calculateTopPadding() + 8.dp,
                bottom = contentPadding.calculateBottomPadding() + 8.dp,
                start = 16.dp,
                end = 16.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(state.languages, key = { it.code }) { language ->
                SnabbitSelectionCard(
                    title = language.nameNative,
                    description = language.name,
                    type = SnabbitSelectionCardType.Radio,
                    variant = SnabbitSelectionCardVariant.Default,
                    selected = language.code == state.selectedCode,
                    onSelectedChange = { onSelect(language.code) },
                )
            }
        }
    }
}
