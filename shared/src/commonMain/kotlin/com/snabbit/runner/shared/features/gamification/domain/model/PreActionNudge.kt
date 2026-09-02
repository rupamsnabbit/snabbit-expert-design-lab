package com.snabbit.runner.shared.features.gamification.domain.model

/**
 * A pre-action nudge banner — the KMP port of Dart
 * `lib/models/gamification/pre_action_nudge.dart`. Rendered as a themed strip
 * (risk / bonus / opportunity) with an optional coin / red-card pill and a
 * countdown to [expiresAtMs].
 *
 * [lifecycleActionType] is a raw string ([LifecycleActionTypes]) so unknown /
 * out-of-scope values survive. [nudgeKind] is mapped to the [NudgeKind] enum at
 * parse time. [expiresAtMs] is absolute epoch-millis (resolved in the parser,
 * matching `LunchPhase`) so the countdown ticker is pure `now()` arithmetic.
 */
data class PreActionNudge(
    val lifecycleActionType: String,
    val nudgeKind: NudgeKind,
    val iconUrl: String,
    val label: NudgeLabel,
    val goldCoins: Int? = null,
    val redCards: Int? = null,
    val expiresAtMs: Long? = null,
    val ctaOverrides: List<CtaOverride>? = null,
) {
    val isOpportunity: Boolean get() = nudgeKind == NudgeKind.Opportunity
    val isRisk: Boolean get() = nudgeKind == NudgeKind.Risk
    val isBonus: Boolean get() = nudgeKind == NudgeKind.Bonus
    val hasCountdown: Boolean get() = expiresAtMs != null
    val hasCtaOverrides: Boolean get() = !ctaOverrides.isNullOrEmpty()
}

/** Mirrors Dart `PreActionNudgeListX.firstOfType`. */
fun List<PreActionNudge>.firstOfType(type: String): PreActionNudge? =
    firstOrNull { it.lifecycleActionType == type }
