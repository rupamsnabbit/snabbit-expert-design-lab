package com.snabbit.runner.shared.features.gamification.domain.model

/**
 * The typed gamification read model, folded from the `current_state` envelope by
 * `GamificationProjector`. The KMP equivalent of the gamification fields the
 * Flutter `RunnerRtDataProvider` holds (`preActionNudges`, `sheetWarnings`,
 * `ctaOverrideMap`, `gamificationCoins`, `gamificationRedCards`).
 *
 * [ctaOverrides] is keyed by **lowercase** cta id (last-wins across nudges),
 * matching Dart `resolveCtaOverridesFromNudges`.
 */
data class GamificationState(
    val nudges: List<PreActionNudge> = emptyList(),
    val sheetWarnings: List<SheetWarning> = emptyList(),
    val ctaOverrides: Map<String, CtaOverride> = emptyMap(),
    val coinsTotal: Int = 0,
    val redCardsTotal: Int = 0,
) {
    /** Lowercase-keyed lookup, mirroring the Dart `ctaOverrideMap` access pattern. */
    fun ctaOverride(ctaId: String): CtaOverride? = ctaOverrides[ctaId.lowercase()]

    companion object {
        val EMPTY = GamificationState()
    }
}
