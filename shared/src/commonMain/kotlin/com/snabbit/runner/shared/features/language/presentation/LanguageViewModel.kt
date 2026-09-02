package com.snabbit.runner.shared.features.language.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.features.language.LanguageAnalytics
import com.snabbit.runner.shared.features.language.domain.LanguageDataSource
import com.snabbit.runner.shared.features.language.domain.usecase.SetLanguageUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/**
 * Drives the Language screen.
 *
 * D1: `androidx.lifecycle.ViewModel` + `viewModelScope` only — never an injected
 * scope. Constructed per nav-entry in the `nativeScreen<LanguageDestination>`
 * registration (`viewModel { LanguageViewModel(...) }`); the two launch-time
 * values ([currentLanguage], [strings]) come from the destination, the rest are
 * Koin-resolved.
 *
 * Navigation (dismiss / back) goes through the injected [nav]
 * `NavigationController` (D2) — the screen is a single native destination, so
 * there is no one-shot effect channel. [uiState] is the only exposed state.
 */
class LanguageViewModel(
    private val dataSource: LanguageDataSource,
    private val setLanguage: SetLanguageUseCase,
    private val analytics: LanguageAnalytics,
    private val nav: NavigationController,
    private val strings: LanguageStrings,
    private val currentLanguage: String?,
) : ViewModel() {

    private val _uiState = MutableStateFlow(LanguageUiState())
    val uiState: StateFlow<LanguageUiState> = _uiState.asStateFlow()

    /** One-shot guard: pop the screen at most once. A fast double back-tap (or
     *  toast-ack racing a back-tap) would otherwise call `nav.back()` twice — the
     *  first pops this screen, the second hits the stack root and exits the whole
     *  shell. The VM is nav-entry-scoped, so this resets when the screen reopens. */
    private var dismissing = false

    init {
        analytics.screenViewed()
        load()
    }

    /** The single input channel — every screen action flows through here. */
    fun onIntent(intent: LanguageUiIntent) {
        when (intent) {
            LanguageUiIntent.Load -> load()
            is LanguageUiIntent.Select -> select(intent.code)
            LanguageUiIntent.Confirm -> confirm()
            LanguageUiIntent.SaveAcknowledged -> dismiss()
            LanguageUiIntent.NavigateUp -> dismiss()
            LanguageUiIntent.ErrorShown -> dismissError()
        }
    }

    /** Loads the language list; the current selection is the launch-time value. */
    private fun load() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val languages = dataSource.getLanguages()
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        languages = languages,
                        selectedCode = currentLanguage,
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                _uiState.update {
                    it.copy(isLoading = false, errorMessage = strings.loadError)
                }
            }
        }
    }

    /** Records the runner's pick. Local only — not persisted until Confirm. */
    private fun select(code: String) {
        if (_uiState.value.selectedCode == code) return
        _uiState.update { it.copy(selectedCode = code) }
        analytics.languageSelected(code)
    }

    /**
     * Confirms the selection via [SetLanguageUseCase] (persist server-side, then
     * best-effort apply). On persist success surfaces a toast (then
     * SaveAcknowledged pops); a persist failure surfaces a transient error.
     */
    private fun confirm() {
        val state = _uiState.value
        val code = state.selectedCode ?: return
        if (state.isSaving || state.saveSucceeded) return
        // Flip isSaving synchronously (before the launch) so a second Confirm on
        // the same dispatcher is rejected by the guard above — independent of
        // whether viewModelScope happens to be Main.immediate.
        _uiState.update { it.copy(isSaving = true, errorMessage = null) }
        viewModelScope.launch {
            try {
                setLanguage(code)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                _uiState.update { it.copy(isSaving = false, errorMessage = strings.saveError) }
                return@launch
            }
            // Persist succeeded (a best-effort apply failure was swallowed by the
            // use-case). Analytics is fire-and-forget, so it can't strand isSaving.
            analytics.languageConfirmed(code)
            _uiState.update { it.copy(isSaving = false, saveSucceeded = true) }
        }
    }

    /** Closes the screen (pop the nav stack) — at most once (see [dismissing]). */
    private fun dismiss() {
        if (dismissing) return
        dismissing = true
        nav.back()
    }

    /** Clears a transient (save-failure) error after it has been shown. */
    private fun dismissError() {
        _uiState.update { it.copy(errorMessage = null) }
    }
}
