package com.snabbit.runner.compose_overlay.presentation.model

import com.snabbit.runner.compose_overlay.domain.CTAConfig
import com.snabbit.runner.compose_overlay.domain.ConsequenceConfig
import com.snabbit.runner.compose_overlay.domain.OverlayConfig
import com.snabbit.runner.compose_overlay.domain.OverlayNudge
import com.snabbit.runner.compose_overlay.domain.OverlayNudgeTypes

interface HasOverlayNudges {
    val nudges: List<OverlayNudge>
}

val HasOverlayNudges.awolBreachNudge: OverlayNudge?
    get() = nudges.firstOrNull { it.lifecycleActionType == OverlayNudgeTypes.AWOL_BREACH_PENALTY }

data class BreachDisplayModel(
    val title: String?,
    val warningText: String?,
    val primaryButton: CTAConfig?,
    val secondaryButton: CTAConfig?,
    val totalSeconds: Int,
    val triggerAtMs: Long? = null,
    val imageUrl: String?,
    val badgeText: String,
    val timerColorMode: String = "red",
    val jobStartTimestampMs: Long? = null,
    override val nudges: List<OverlayNudge> = emptyList(),
    val redCardsTotal: Int? = null,
    val redCardReceivedLabel: String = "RED CARD(S) RECEIVED",
    val nudgeOutsideHotspot: String = "Outside Hotspot",
) : HasOverlayNudges {

    companion object {
        fun from(config: OverlayConfig): BreachDisplayModel {
            val primary = config.ctaList.firstOrNull { it.style == "primary" }
            val secondary = config.ctaList.firstOrNull { it.style == "secondary" }
            return BreachDisplayModel(
                title = config.title,
                warningText = config.message,
                primaryButton = primary,
                secondaryButton = secondary,
                totalSeconds = config.countdown?.totalSeconds ?: 300,
                triggerAtMs = config.countdown?.triggerAtMs,
                imageUrl = config.imageUrl,
                badgeText = config.badgeText ?: "HOTSPOT BREACH",
                timerColorMode = config.timerColorMode,
                jobStartTimestampMs = config.jobStartTimestampMs,
                nudges = config.nudges,
                redCardsTotal = config.redCardsTotal,
                redCardReceivedLabel = config.redCardReceivedLabel ?: "RED CARD(S) RECEIVED",
                nudgeOutsideHotspot = config.nudgeOutsideHotspot ?: "Outside Hotspot",
            )
        }
    }
}

data class ReEnteredDisplayModel(
    val title: String?,
    val warningText: String?,
    val button: CTAConfig?,
    val consequences: List<ConsequenceConfig>,
    val imageUrl: String?,
    val badgeText: String,
) {
    companion object {
        fun from(config: OverlayConfig): ReEnteredDisplayModel = ReEnteredDisplayModel(
            title = config.title,
            warningText = config.message,
            button = config.ctaList.firstOrNull(),
            consequences = config.consequences ?: emptyList(),
            imageUrl = config.imageUrl,
            badgeText = config.badgeText ?: "BACK IN HOTSPOT",
        )
    }
}

data class MiniBreachDisplayModel(
    val warningText: String?,
    val totalSeconds: Int,
    val triggerAtMs: Long? = null,
    val miniTitle: String,
    val timerColorMode: String = "red",
    val jobStartTimestampMs: Long? = null,
    override val nudges: List<OverlayNudge> = emptyList(),
    val redCardsTotal: Int? = null,
) : HasOverlayNudges {

    companion object {
        fun from(config: OverlayConfig): MiniBreachDisplayModel = MiniBreachDisplayModel(
            warningText = config.message,
            totalSeconds = config.countdown?.totalSeconds ?: 300,
            triggerAtMs = config.countdown?.triggerAtMs,
            miniTitle = config.miniTitle ?: "Snabbit Alert",
            timerColorMode = config.timerColorMode,
            jobStartTimestampMs = config.jobStartTimestampMs,
            nudges = config.nudges,
            redCardsTotal = config.redCardsTotal,
        )
    }
}
