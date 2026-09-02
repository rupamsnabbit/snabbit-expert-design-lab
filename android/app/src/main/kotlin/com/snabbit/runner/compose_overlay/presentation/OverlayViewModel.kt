package com.snabbit.runner.compose_overlay.presentation

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import com.snabbit.runner.compose_overlay.domain.OverlayAction
import com.snabbit.runner.compose_overlay.domain.OverlayConfig
import com.snabbit.runner.compose_overlay.domain.OverlayState

/**
 * Pure state machine for the overlay UI. Receives [OverlayAction]s and
 * emits [OverlayState] via a [StateFlow]. Has no Android framework
 * dependencies — all side effects (showing/dismissing views, sending
 * messages to Flutter) are delegated through nullable callback properties
 * that [OverlayService] sets in `onCreate()` and clears in `onDestroy()`.
 *
 * State transitions:
 *   Idle → ShowingDialog / ShowingBanner / ShowingMiniOverlay
 *   ShowingDialog → ShowingMiniOverlay (on "understood" CTA)
 *   ShowingDialog → Idle (on "show_directions" CTA or Dismiss)
 *   ShowingMiniOverlay → Idle (on mini tap / Dismiss)
 *   ShowingBanner → Idle (on Dismiss)
 *   Any → Error (on ServiceKilled)
 */
class OverlayViewModel {

    private val _state = MutableStateFlow<OverlayState>(OverlayState.Idle)
    val state: StateFlow<OverlayState> = _state.asStateFlow()

    private var isProcessing = false
    private var dialogShownAtMs: Long = 0L

    // Always holds the most recent config received from Flutter so the
    // dialog→mini transition uses up-to-date fields (e.g. redCardReceivedLabel)
    // even when a poll delivers a new config while the dialog is open.
    private var _latestConfig: OverlayConfig? = null

    var onSendToFlutter: ((method: String, args: Map<String, Any?>) -> Unit)? = null
    var onEmitEvent: ((event: String, payload: Map<String, Any?>) -> Unit)? = null
    var onShowView: ((config: OverlayConfig, isDialog: Boolean) -> Unit)? = null
    var onDismissView: (() -> Unit)? = null
    var onLaunchMapsIntent: ((lat: Double, lng: Double) -> Unit)? = null
    var onStopService: (() -> Unit)? = null
    var onShowMiniView: ((config: OverlayConfig) -> Unit)? = null

    fun onAction(action: OverlayAction) {
        val currentState = _state.value

        when (action) {
            is OverlayAction.ShowDialog -> {
                // If the user already acknowledged the breach (mini overlay showing),
                // refresh the mini overlay instead of reverting to dialog.
                // This guards against a race where the Flutter-side "understood"
                // callback hasn't arrived yet but a poll already sent ShowDialog.
                if (currentState is OverlayState.ShowingMiniOverlay) {
                    val previousState = currentState
                    onDismissView?.invoke()
                    onShowMiniView?.invoke(action.config)
                    _state.value = OverlayState.ShowingMiniOverlay(action.config)
                    emitStateChanged(previousState, _state.value)
                    emitEvent("overlay_shown", mapOf("type" to "mini", "timestamp" to System.currentTimeMillis()))
                    return
                }
                if (currentState !is OverlayState.Transitioning) {
                    _latestConfig = action.config
                    val previousState = currentState
                    _state.value = OverlayState.Transitioning(previousState, OverlayState.ShowingDialog(action.config))
                    onDismissView?.invoke()
                    onShowView?.invoke(action.config, true)
                    _state.value = OverlayState.ShowingDialog(action.config)
                    dialogShownAtMs = System.currentTimeMillis()
                    emitStateChanged(previousState, _state.value)
                    emitEvent("overlay_shown", mapOf("type" to "dialog", "timestamp" to System.currentTimeMillis()))
                }
            }

            is OverlayAction.ShowBanner -> {
                if (currentState !is OverlayState.Transitioning) {
                    val previousState = currentState
                    _state.value = OverlayState.Transitioning(previousState, OverlayState.ShowingBanner(action.message, action.type))
                    onDismissView?.invoke()
                    // For banner, we create a config with consequences support
                    // The actual view creation is handled by the service
                    _state.value = OverlayState.ShowingBanner(action.message, action.type)
                    emitStateChanged(previousState, _state.value)
                    emitEvent("overlay_shown", mapOf("type" to "banner", "timestamp" to System.currentTimeMillis()))
                }
            }

            is OverlayAction.CTAClicked -> {
                if (isProcessing) return
                isProcessing = true

                // 1. Handle natively FIRST — this always works
                when (action.actionId) {
                    "show_directions" -> {
                        val lat = (action.data["lat"] as? Number)?.toDouble()
                        val lng = (action.data["lng"] as? Number)?.toDouble()
                        if (lat != null && lng != null) {
                            onLaunchMapsIntent?.invoke(lat, lng)
                        }
                        onDismissView?.invoke()
                        _state.value = OverlayState.Idle
                        onStopService?.invoke()
                    }
                    "understood" -> {
                        // If showing breach dialog, transition to mini overlay instead of full dismiss
                        val currentState = _state.value
                        if (currentState is OverlayState.ShowingDialog) {
                            val previousState = currentState
                            val elapsedSec = ((System.currentTimeMillis() - dialogShownAtMs) / 1000).toInt()
                            // Use the freshest config Flutter has sent (_latestConfig) so fields like
                            // redCardReceivedLabel are not stale if a poll arrived while dialog was open.
                            val baseConfig = _latestConfig ?: currentState.config
                            val originalRemaining = baseConfig.countdown?.remainingSeconds ?: 0
                            val updatedRemaining = maxOf(0, originalRemaining - elapsedSec)
                            val updatedConfig = baseConfig.copy(
                                countdown = baseConfig.countdown?.copy(
                                    remainingSeconds = updatedRemaining,
                                ),
                            )
                            onDismissView?.invoke()
                            onShowMiniView?.invoke(updatedConfig)
                            _state.value = OverlayState.ShowingMiniOverlay(updatedConfig)
                            emitStateChanged(previousState, _state.value)
                            emitEvent("overlay_shown", mapOf("type" to "mini", "timestamp" to System.currentTimeMillis()))
                        } else {
                            // For re-entered or other states, dismiss fully
                            onDismissView?.invoke()
                            _state.value = OverlayState.Idle
                            onStopService?.invoke()
                        }
                    }
                    "timeout" -> {
                        // No-op on native side — Flutter is still notified below.
                    }
                }

                // 2. Notify Flutter (best-effort — may be dead)
                try {
                    onSendToFlutter?.invoke("onCTAClicked", mapOf(
                        "actionId" to action.actionId,
                        "data" to action.data,
                    ))
                } catch (e: Exception) {
                    android.util.Log.w("OverlayViewModel", "Flutter notification failed (engine may be dead): ${e.message}")
                }

                isProcessing = false
            }

            is OverlayAction.Dismiss -> {
                if (currentState is OverlayState.Idle) return
                val previousState = currentState
                onDismissView?.invoke()
                _state.value = OverlayState.Idle
                emitStateChanged(previousState, _state.value)
                emitEvent("overlay_hidden", mapOf("type" to previousState.name.lowercase(), "timestamp" to System.currentTimeMillis()))
                onSendToFlutter?.invoke("onOverlayDismissed", mapOf("reason" to action.reason))
            }

            is OverlayAction.UpdateBanner -> {
                if (currentState is OverlayState.ShowingBanner) {
                    _state.value = OverlayState.ShowingBanner(action.message, action.type)
                }
            }

            is OverlayAction.ShowMiniOverlay -> {
                _latestConfig = action.config
                val previousState = _state.value
                onDismissView?.invoke()
                onShowMiniView?.invoke(action.config)
                _state.value = OverlayState.ShowingMiniOverlay(action.config)
                emitStateChanged(previousState, _state.value)
                emitEvent("overlay_shown", mapOf("type" to "mini", "timestamp" to System.currentTimeMillis()))
            }

            is OverlayAction.ServiceKilled -> {
                _state.value = OverlayState.Error("SERVICE_KILLED", "Service was killed: ${action.reason}")
                onSendToFlutter?.invoke("onOverlayError", mapOf(
                    "code" to "SERVICE_KILLED",
                    "message" to "Service was killed: ${action.reason}",
                ))
            }
        }
    }

    fun isActive(): Boolean = _state.value !is OverlayState.Idle && _state.value !is OverlayState.Error

    private fun emitStateChanged(from: OverlayState, to: OverlayState) {
        emitEvent("state_changed", mapOf("from" to from.name, "to" to to.name))
    }

    private fun emitEvent(event: String, payload: Map<String, Any?>) {
        onEmitEvent?.invoke(event, payload)
    }
}
