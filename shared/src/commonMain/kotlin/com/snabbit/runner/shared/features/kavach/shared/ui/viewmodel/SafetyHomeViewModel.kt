package com.snabbit.runner.shared.features.kavach.shared.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.safetykavach.shield.core.model.MonitoringState
import com.safetykavach.shield.core.model.RecordingState
import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.lifecycle.AppLifecycle
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkExceptionMapper
import com.snabbit.runner.shared.features.kavach.sos.SosActive
import com.snabbit.runner.shared.features.kavach.shared.data.SafetyCondition
import com.snabbit.runner.shared.features.kavach.shared.data.SafetyDataSource
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionContext
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionGate
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionResult
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.kavach.sos.domain.SosPhase
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetyHomeIntent
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetyHomeUiState
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetySheet
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.ProtectionState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Drives the Kavach home screen: the card's activation flow, the overlay sheets, the
 * status pill, and the SOS raise → alert flow. SOS logic lives in the shared
 * [SosCoordinator]; this VM renders its state (alert visibility) + routes its nav effect.
 * Transient feedback lives in [SafetyHomeUiState] (D2).
 */
class SafetyHomeViewModel(
    private val nav: NavigationController,
    private val dataSource: SafetyDataSource,
    private val sosCoordinator: SosCoordinator,
    private val permissionGate: KavachPermissionGate,
    private val lifecycle: AppLifecycle,
    private val analytics: AnalyticsTracker,
) : ViewModel() {

    private val _uiState = MutableStateFlow(SafetyHomeUiState())
    val uiState: StateFlow<SafetyHomeUiState> = _uiState.asStateFlow()

    private var activating = false   // guards the Activate handler against re-entrant double-taps
    // Guards the actual activate() work (permission + engine start) across ALL callers — the Activate CTA,
    // ConfirmKeepPhone, ConfirmConsent, RetryPermission. Without it a rapid double-tap fires two
    // permissionGate.ensure() → duplicate OS permission dialogs + a doubled engine-start ladder.
    private var activateInFlight = false
    private var sosRaiseInFlight = false   // debounce the SOS button across the async raiseManual

    init {
        observeConditions()
        observeSos()
        observeShieldState()
        observePermissionRecheck()
    }

    fun onIntent(intent: SafetyHomeIntent) {
        when (intent) {
            SafetyHomeIntent.Activate -> viewModelScope.launch {
                if (activating) return@launch   // ignore rapid double-taps — no double count/analytics
                activating = true
                try {
                    // Card "Activate" tap (Flutter onStartMonitoringTapped); `activating` dedupes double-taps.
                    analytics.track("expert_shield_banner_cta")
                    // Keep-phone info sheet shows for the first N activations (RC cap), then Activate goes
                    // straight through. Runner consent is handled separately on the home page.
                    if (dataSource.shouldShowActivationSheet()) {
                        analytics.track("expert_shield_info_bs", mapOf("source" to "manual"))
                        dataSource.markActivationSheetShown()
                        _uiState.update { it.copy(sheet = SafetySheet.KEEP_PHONE) }
                    } else {
                        activate()
                    }
                } finally {
                    activating = false
                }
            }
            SafetyHomeIntent.ConfirmKeepPhone -> {
                analytics.track("expert_shield_info_cta")
                activate()
            }
            // Legacy card-consent path: no production UI dispatches it (consent moved to Home). Retained
            // as the direct-activate() entry the permission tests drive.
            SafetyHomeIntent.ConfirmConsent -> activate()
            SafetyHomeIntent.DismissSheet -> {
                // info_dismiss only for the activation info sheet. KEEP_PHONE is now that sheet's only
                // source (SafetyCondition.KEEP_PHONE was removed), so its type alone identifies it.
                if (_uiState.value.sheet == SafetySheet.KEEP_PHONE) {
                    analytics.track("expert_shield_info_dismiss")
                }
                _uiState.update { it.copy(sheet = null) }
            }
            SafetyHomeIntent.OpenSos -> raiseSos()
            SafetyHomeIntent.ConfirmSos -> confirmSos()
            SafetyHomeIntent.DenySos -> denySos()
            // Open app settings (per the banner kdoc) so the runner can free space — do NOT
            // optimistically clear noStorage, which would re-enable Activate while the disk is still
            // full and conditions() (distinct) wouldn't re-emit NO_STORAGE to correct it (#8).
            SafetyHomeIntent.RetryStorage -> permissionGate.openSettings()
            SafetyHomeIntent.ErrorShown -> _uiState.update { it.copy(error = null) }
            SafetyHomeIntent.PermissionBlockShown -> _uiState.update { it.copy(permissionResult = null) }
            SafetyHomeIntent.SosInProgressShown -> _uiState.update { it.copy(sosInProgress = false) }
            SafetyHomeIntent.RetryPermission -> {
                _uiState.update { it.copy(permissionResult = null) }
                activate() // re-runs the gate → re-requests; re-blocks the dialog if still denied.
            }
            SafetyHomeIntent.OpenAppSettings -> {
                permissionGate.openSettings()
                _uiState.update { it.copy(permissionResult = null) }
            }
        }
    }

    private fun activate() = viewModelScope.launch {
        if (activateInFlight) return@launch   // dedupe concurrent activate() from any caller (#missing-debounce)
        activateInFlight = true
        try {
            // 2f gate: mic + location must be granted before the engine starts. Blocked → surface the
            // permission dialog (state-driven) instead of activating.
            val permission = permissionGate.ensure(KavachPermissionContext.MicAndLocation)
            if (permission != KavachPermissionResult.Granted) {
                _uiState.update { it.copy(sheet = null, permissionResult = permission) }
                return@launch
            }
            // Dismiss the sheet and play the activation Lottie once over the card (auto-clears after the clip).
            _uiState.update { it.copy(sheet = null, activationLottiePlaying = true) }
            scheduleActivationLottieClear()
            try {
                // false = jobId lag armed nothing and threw nothing. Without this the Lottie would
                // play its full ~10s "activated" run over a shield that never started.
                if (!dataSource.activate()) {
                    _uiState.update { it.copy(activationLottiePlaying = false, error = AppErrorType.OTHER_ERROR) }
                }
                // `protectionState` is not set optimistically — it derives from the plugin state
                // (observeShieldState) once the engine transitions.
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                _uiState.update { it.copy(activationLottiePlaying = false, error = NetworkExceptionMapper.map(e)) }
            }
        } finally {
            activateInFlight = false
        }
    }

    // kavach_opt.json is ~10.2s (op 256 @ 25fps); clear the flag after it so the one-shot overlay leaves.
    private fun scheduleActivationLottieClear() = viewModelScope.launch {
        delay(ACTIVATION_LOTTIE_MS)
        _uiState.update { it.copy(activationLottiePlaying = false) }
    }

    // Shared launch shell for the SOS actions: rethrow cancellation, map any other throwable to the
    // transient error field (D2). Keeps each handler down to its one differing call.
    private fun launchSafely(block: suspend () -> Unit) = viewModelScope.launch {
        try {
            block()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            _uiState.update { it.copy(error = NetworkExceptionMapper.map(e)) }
        }
    }

    private fun raiseSos() {
        // R4: already in an SOS → flag it, don't stack another. The coordinator would reject the raise
        // anyway (phase guard), but silently — the runner needs to know it's already live.
        if (sosCoordinator.state.value.phase != SosPhase.IDLE) {
            _uiState.update { it.copy(sosInProgress = true) }
            return
        }
        // R2: debounce rapid taps at the VM so we don't spawn N raiseManual coroutines racing the guard.
        if (sosRaiseInFlight) return
        sosRaiseInFlight = true
        viewModelScope.launch {
            try {
                sosCoordinator.raiseManual()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                _uiState.update { it.copy(error = NetworkExceptionMapper.map(e)) }
            } finally {
                sosRaiseInFlight = false
            }
        }
    }

    private fun confirmSos() = launchSafely {
        val sos = sosCoordinator.state.value
        analytics.track("expert_shield_sos_alert_confirm_click", mapOf("sos_id" to sos.sosId, "source" to (sos.source ?: "unknown")))
        sosCoordinator.confirm()
    }

    private fun denySos() = launchSafely {
        val sos = sosCoordinator.state.value
        analytics.track("expert_shield_sos_alert_deny_click", mapOf("sos_id" to sos.sosId, "source" to (sos.source ?: "unknown")))
        sosCoordinator.deny()
    }

    /** Reflect the SOS alert phase; navigate to the active screen on confirm (ALERT → ACTIVE). */
    private fun observeSos() = viewModelScope.launch {
        var last: SosPhase? = null
        sosCoordinator.state.collect { sos ->
            if (sos.phase == SosPhase.ALERT && last != SosPhase.ALERT) {
                analytics.track("expert_shield_sos_alert_bs", mapOf("sos_id" to sos.sosId, "source" to (sos.source ?: "unknown")))
            }
            _uiState.update { it.copy(sosAlertVisible = sos.phase == SosPhase.ALERT) }
            // Nav to SosActive is owned by the app-scoped AppSosHost (SOS works on any screen), so
            // this VM no longer navigates — avoids a double-push when embedded on the job screen.
            last = sos.phase
        }
    }

    /** Plugin state is the source of truth (6c): mirror it into the card's UI state. */
    private fun observeShieldState() = viewModelScope.launch {
        // Nullable seed: combine emits its current value immediately on collection, so a VM created while
        // the shield is ALREADY monitoring must not read that first emission as a false→true edge and
        // over-count banner_visible. Fire edges only from the second emission on.
        var wasMonitoring: Boolean? = null
        combine(
            dataSource.shieldState,
            dataSource.recordingState,
            dataSource.monitoringState,
        ) { shield, rec, mon -> Triple(shield, rec, mon) }.collect { (shield, rec, mon) ->
            val recording = rec == RecordingState.RECORDING
            val monitoring = mon == MonitoringState.ACTIVE ||
                shield == SafetyState.MONITORING || shield == SafetyState.MONITORING_ONLY
            // Job-screen card presence is gated by `monitoring` (ActiveJobOverlay) — mirror Flutter's
            // isCardVisible transition: fire visible/hidden on the monitoring edge (skip the seed emission).
            if (monitoring && wasMonitoring == false) analytics.track("expert_shield_banner_visible")
            else if (!monitoring && wasMonitoring == true) analytics.track("expert_shield_banner_hidden")
            wasMonitoring = monitoring
            val sos = shield == SafetyState.SOS_PENDING || shield == SafetyState.SOS_CONFIRMED
            _uiState.update {
                it.copy(
                    recording = recording,
                    monitoring = monitoring,
                    sosMode = sos,
                )
            }
        }
    }

    /** Device signals map to a sheet (keep-phone / battery-low) or the pill (no-storage). */
    private fun observeConditions() = viewModelScope.launch {
        var wasNoStorage = false
        dataSource.conditions().collect { condition ->
            // expert_shield_storage_warning on the low-storage banner becoming visible (false→true),
            // 1:1 Flutter (isStorageWarning transition). storage_full (activation-blocked) has no KMP
            // trigger — the card disables Activate rather than attempting + blocking.
            val noStorage = condition == SafetyCondition.NO_STORAGE
            if (noStorage && !wasNoStorage) analytics.track("expert_shield_storage_warning")
            wasNoStorage = noStorage
            _uiState.update { state ->
                when (condition) {
                    SafetyCondition.BATTERY_LOW -> state.copy(sheet = SafetySheet.BATTERY_LOW)
                    SafetyCondition.NO_STORAGE -> state.copy(noStorage = true)
                    // NONE = conditions recovered: clear noStorage AND dismiss a stale condition sheet
                    // (e.g. BATTERY_LOW after the battery recovers).
                    SafetyCondition.NONE -> state.copy(noStorage = false, sheet = null)
                }
            }
        }
    }

    /**
     * ON_RESUME re-check: when the app returns to the foreground (e.g. back from Settings) while the
     * permission dialog is up, silently re-check (no re-prompt) and dismiss the dialog if the grant
     * landed. Still-denied leaves the dialog untouched. Does not auto-activate — the runner re-taps.
     */
    private fun observePermissionRecheck() = viewModelScope.launch {
        lifecycle.foreground.filter { it }.collect {
            if (_uiState.value.permissionResult != null &&
                permissionGate.isGranted(KavachPermissionContext.MicAndLocation)
            ) {
                _uiState.update { it.copy(permissionResult = null) }
            }
        }
    }

    private companion object {
        const val ACTIVATION_LOTTIE_MS = 10_240L   // op 256 @ 25fps
    }
}
