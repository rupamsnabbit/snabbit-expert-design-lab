package com.snabbit.runner.compose_overlay.domain

sealed class OverlayState {
    data object Idle : OverlayState()
    data class ShowingDialog(val config: OverlayConfig) : OverlayState()
    data class ShowingBanner(val message: String, val type: String) : OverlayState()
    data class ShowingMiniOverlay(val config: OverlayConfig) : OverlayState()
    data class Transitioning(val from: OverlayState, val to: OverlayState) : OverlayState()
    data class Error(val code: String, val message: String) : OverlayState()

    val name: String
        get() = when (this) {
            is Idle -> "Idle"
            is ShowingDialog -> "ShowingDialog"
            is ShowingBanner -> "ShowingBanner"
            is ShowingMiniOverlay -> "ShowingMiniOverlay"
            is Transitioning -> "Transitioning"
            is Error -> "Error"
        }
}
