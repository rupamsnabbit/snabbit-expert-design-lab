package com.snabbit.runner.shared.features.kavach.sos.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkExceptionMapper
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.kavach.sos.domain.SosPhase
import com.snabbit.runner.shared.features.kavach.sos.ui.contracts.SosActiveIntent
import com.snabbit.runner.shared.features.kavach.sos.ui.contracts.SosActiveUiState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Drives the SOS-active ("Help is on the way") screen via the shared [SosCoordinator].
 * "Call SoS Team" dials (E4, repeatable). "I am safe" deescalates; the screen pops when the
 * SOS resolves (ACTIVE → IDLE) — state-driven, so a notification "End SoS" pops it too.
 */
class SosActiveViewModel(
    private val nav: NavigationController,
    private val sosCoordinator: SosCoordinator,
    private val analytics: AnalyticsTracker,
) : ViewModel() {

    private val _uiState = MutableStateFlow(SosActiveUiState())
    val uiState: StateFlow<SosActiveUiState> = _uiState.asStateFlow()

    init {
        val sos = sosCoordinator.state.value
        analytics.track(
            "expert_shield_sos_active_load",
            mapOf("sos_id" to sos.sosId, "source" to (sos.source ?: "unknown"), "is_on_job" to (sos.jobId != null)),
        )
        observeResolve()
    }

    fun onIntent(intent: SosActiveIntent) {
        when (intent) {
            SosActiveIntent.CallSosTeam -> callSosTeam()
            SosActiveIntent.MarkSafe -> markSafe()
            SosActiveIntent.ErrorShown -> _uiState.update { it.copy(error = null) }
        }
    }

    private fun callSosTeam() = viewModelScope.launch {
        val sos = sosCoordinator.state.value
        analytics.track(
            "expert_shield_sos_active_call_team_cta",
            mapOf("sos_id" to sos.sosId, "source" to (sos.source ?: "unknown"), "phone_number_available" to (sos.phoneNumber != null)),
        )
        try {
            // callSosTeam returns false (no throw) when the phone is blank / the API rejects — surface it
            // as a visible error instead of a silent no-op (dead-button fix).
            if (!sosCoordinator.callSosTeam()) {
                _uiState.update { it.copy(error = AppErrorType.OTHER_ERROR) }
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            _uiState.update { it.copy(error = NetworkExceptionMapper.map(e)) }
        }
    }

    private fun markSafe() = viewModelScope.launch {
        val sos = sosCoordinator.state.value
        analytics.track(
            "expert_shield_sos_active_end_sos_cta",
            mapOf("sos_id" to sos.sosId, "source" to (sos.source ?: "unknown"), "is_on_job" to (sos.jobId != null)),
        )
        _uiState.update { it.copy(ending = true) }
        try {
            sosCoordinator.deescalate()   // resolves → ACTIVE→IDLE → observeResolve pops
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            _uiState.update { it.copy(ending = false, error = NetworkExceptionMapper.map(e)) }
        }
    }

    /** Pop whenever the SOS resolves. Not edge-gated on ACTIVE→IDLE: this screen is only navigated to for
     *  an active SOS (AppSosHost), so any IDLE means resolved — and a resolve that conflates the StateFlow
     *  to IDLE before this cold collector subscribes would otherwise never observe the edge and strand it. */
    private fun observeResolve() = viewModelScope.launch {
        sosCoordinator.state.collect { sos ->
            if (sos.phase == SosPhase.IDLE) nav.back()
        }
    }
}
