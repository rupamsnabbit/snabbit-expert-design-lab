package com.snabbit.runner.shared.features.gamification.domain.model

/**
 * Per-CTA override for gamified buttons — the KMP port of Dart
 * `lib/models/gamification/cta_override.dart`. Carries an optional replacement
 * [label] plus coin / red-card badge counts for a given [ctaId] (see [CtaIds]).
 */
data class CtaOverride(
    val ctaId: String,
    val label: NudgeLabel? = null,
    val goldCoins: Int? = null,
    val redCards: Int? = null,
) {
    val hasCoinBadge: Boolean get() = (goldCoins ?: 0) > 0
    val hasRedCardBadge: Boolean get() = (redCards ?: 0) > 0
}
