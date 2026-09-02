package com.snabbit.runner.compose_overlay.domain

data class OverlayConfig(
    val title: String? = null,
    val message: String? = null,
    val ctaList: List<CTAConfig> = emptyList(),
    val dismissOnOutsideTouch: Boolean = false,
    val autoDismissSec: Int? = null,
    val position: String = "center",
    // Overlay-specific fields
    val countdown: CountdownConfig? = null,
    val hotspot: HotspotConfig? = null,
    val consequences: List<ConsequenceConfig>? = null,
    val imageUrl: String? = null,
    val badgeText: String? = null,
    val miniTitle: String? = null,
    val timerColorMode: String = "red",
    val jobStartTimestampMs: Long? = null,
    val nudges: List<OverlayNudge> = emptyList(),
    val redCardsTotal: Int? = null,
    val redCardReceivedLabel: String? = null,
    val nudgeOutsideHotspot: String? = null,
) {
    companion object {
        fun fromMap(map: Map<String, Any?>): OverlayConfig {
            @Suppress("UNCHECKED_CAST")
            val ctaListRaw = map["ctaList"] as? List<Map<String, Any?>> ?: emptyList()

            @Suppress("UNCHECKED_CAST")
            val countdownMap = map["countdown"] as? Map<String, Any?>

            @Suppress("UNCHECKED_CAST")
            val hotspotMap = map["hotspot"] as? Map<String, Any?>

            @Suppress("UNCHECKED_CAST")
            val consequencesRaw = map["consequences"] as? List<Map<String, Any?>>

            val nudgesRaw = map["preActionNudges"] as? List<*> ?: emptyList<Any>()

            return OverlayConfig(
                title = map["title"] as? String,
                message = map["message"] as? String,
                ctaList = ctaListRaw.map { CTAConfig.fromMap(it) },
                dismissOnOutsideTouch = map["dismissOnOutsideTouch"] as? Boolean ?: false,
                autoDismissSec = (map["autoDismissSec"] as? Number)?.toInt(),
                position = map["position"] as? String ?: "center",
                countdown = countdownMap?.let { CountdownConfig.fromMap(it) },
                hotspot = hotspotMap?.let { HotspotConfig.fromMap(it) },
                consequences = consequencesRaw?.map { ConsequenceConfig.fromMap(it) },
                imageUrl = map["imageUrl"] as? String,
                badgeText = map["badgeText"] as? String,
                miniTitle = map["miniTitle"] as? String,
                timerColorMode = map["timerColorMode"] as? String ?: "red",
                jobStartTimestampMs = (map["jobStartTimestampMs"] as? Number)?.toLong(),
                nudges = nudgesRaw.mapNotNull { item ->
                    @Suppress("UNCHECKED_CAST")
                    OverlayNudge.tryFromMap(item as? Map<String, Any?> ?: return@mapNotNull null)
                },
                redCardsTotal = (map["redCardsTotal"] as? Number)?.toInt(),
                redCardReceivedLabel = map["redCardReceivedLabel"] as? String,
                nudgeOutsideHotspot = map["nudgeOutsideHotspot"] as? String,
            )
        }
    }
}

data class OverlayNudge(
    val lifecycleActionType: String,
    val nudgeKind: String,
    val iconUrl: String,
    val labelText: String?,
    val redCards: Int?,
    val goldCoins: Int?,
) {
    companion object {
        /**
         * Parses an [OverlayNudge] from the MethodChannel map sent by Flutter.
         *
         * Wire contract (enforced by Flutter before serialisation):
         *  - [lifecycleActionType] and [nudgeKind] must be non-blank — checked here.
         *  - [iconUrl] must be non-empty — falls back to the CDN default rather than
         *    dropping, so the strip still renders if the API omits it.
         *  - [labelText] is a pre-resolved string (Flutter calls LanguageProvider before
         *    sending). It can legitimately be null/blank (compact mini strip renders
         *    icon-only in that case). Flutter's `PreActionNudge.tryFromMap` already
         *    requires `label.key.isNotEmpty` before a nudge reaches this channel, so
         *    no equivalent key check is needed here.
         */
        fun tryFromMap(map: Map<String, Any?>): OverlayNudge? {
            val type = map["lifecycleActionType"] as? String
            if (type.isNullOrBlank()) return null
            val nudgeKind = map["nudgeKind"] as? String
            if (nudgeKind.isNullOrBlank()) return null
            val iconUrl = (map["iconUrl"] as? String)?.takeIf { it.isNotBlank() }
                ?: "https://assets-expert.snabbit.com/payouts/nudges/red_card_straight.png"
            return OverlayNudge(
                lifecycleActionType = type,
                nudgeKind = nudgeKind,
                iconUrl = iconUrl,
                labelText = map["labelText"] as? String,
                redCards = (map["redCards"] as? Number)?.toInt(),
                goldCoins = (map["goldCoins"] as? Number)?.toInt(),
            )
        }
    }
}

data class CTAConfig(
    val actionId: String,
    val label: String,
    val style: String = "secondary",
    val data: Map<String, Any?> = emptyMap(),
) {
    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any?>): CTAConfig = CTAConfig(
            actionId = map["actionId"] as? String ?: "",
            label = map["label"] as? String ?: "",
            style = map["style"] as? String ?: "secondary",
            data = map["data"] as? Map<String, Any?> ?: emptyMap(),
        )
    }
}

data class CountdownConfig(
    val remainingSeconds: Int,
    val totalSeconds: Int,
    val triggerAtMs: Long? = null,
) {
    companion object {
        fun fromMap(map: Map<String, Any?>): CountdownConfig = CountdownConfig(
            remainingSeconds = (map["remaining_seconds"] as? Number)?.toInt() ?: 0,
            totalSeconds = (map["total_seconds"] as? Number)?.toInt() ?: 300,
            triggerAtMs = (map["trigger_at"] as? Number)?.toLong(),
        )
    }
}

data class HotspotConfig(
    val name: String?,
    val latitude: Double?,
    val longitude: Double?,
) {
    companion object {
        fun fromMap(map: Map<String, Any?>): HotspotConfig = HotspotConfig(
            name = map["name"] as? String,
            latitude = (map["latitude"] as? Number)?.toDouble(),
            longitude = (map["longitude"] as? Number)?.toDouble(),
        )
    }
}

data class ConsequenceConfig(
    val iconUrl: String?,
    val text: String?,
) {
    companion object {
        fun fromMap(map: Map<String, Any?>): ConsequenceConfig = ConsequenceConfig(
            iconUrl = map["icon_url"] as? String,
            text = map["text"] as? String,
        )
    }
}
