package com.snabbit.runner.shared.features.language.presentation

import com.snabbit.runner.shared.features.language.domain.model.LanguageOption

/**
 * MVI contract for the Language screen: [LanguageUiState] (render state) +
 * [LanguageUiIntent] (user actions), in one file per the feature convention.
 *
 * There is no `UiEffect` — navigation (dismiss / back) goes through the injected
 * `NavigationController` (D2), and the success toast is plain [LanguageUiState].
 */

/**
 * Render state for the Language screen.
 *
 * - load failure  → [languages] empty + [errorMessage] set (screen-level error)
 * - save failure  → [languages] present + [errorMessage] set (transient snackbar)
 */
data class LanguageUiState(
    val isLoading: Boolean = true,
    val languages: List<LanguageOption> = emptyList(),
    val selectedCode: String? = null,
    val isSaving: Boolean = false,
    val errorMessage: String? = null,
    /** Set once the save succeeds — the screen shows a success toast, then closes. */
    val saveSucceeded: Boolean = false,
) {
    /** Confirm is actionable only with a selection and no save in flight or done. */
    val canConfirm: Boolean get() = selectedCode != null && !isSaving && !saveSucceeded
}

/**
 * Every user action on the Language screen, as data. The screen sends these to
 * [LanguageViewModel.onIntent] — a single input channel, so all state
 * transitions live in one exhaustive `when` (child composables receive
 * `onIntent`, never the ViewModel).
 */
sealed interface LanguageUiIntent {
    /** Load / reload the list + current selection (initial + retry). */
    data object Load : LanguageUiIntent

    /** The runner picked a language. */
    data class Select(val code: String) : LanguageUiIntent

    /** Confirm the current selection (persist via KMP, then apply + toast). */
    data object Confirm : LanguageUiIntent

    /** The success toast finished showing — close the screen (pops the nav stack). */
    data object SaveAcknowledged : LanguageUiIntent

    /** Top-nav back / cancel — close the screen without saving (pops the nav stack). */
    data object NavigateUp : LanguageUiIntent

    /** A transient (save-failure) error has been shown — clear it. */
    data object ErrorShown : LanguageUiIntent
}
