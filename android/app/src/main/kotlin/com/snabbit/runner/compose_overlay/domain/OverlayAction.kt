package com.snabbit.runner.compose_overlay.domain

sealed class OverlayAction {
    data class ShowDialog(val config: OverlayConfig) : OverlayAction()
    data class ShowBanner(val message: String, val type: String) : OverlayAction()
    data class ShowMiniOverlay(val config: OverlayConfig) : OverlayAction()
    data class CTAClicked(val actionId: String, val data: Map<String, Any?>) : OverlayAction()
    data class Dismiss(val reason: String) : OverlayAction()
    data class UpdateBanner(val message: String, val type: String) : OverlayAction()
    data class ServiceKilled(val reason: String) : OverlayAction()
}
