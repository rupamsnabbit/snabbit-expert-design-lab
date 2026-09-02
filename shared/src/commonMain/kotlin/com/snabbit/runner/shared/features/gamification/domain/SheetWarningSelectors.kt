package com.snabbit.runner.shared.features.gamification.domain

import com.snabbit.runner.shared.features.gamification.domain.model.CtaOverride
import com.snabbit.runner.shared.features.gamification.domain.model.SheetWarning

/**
 * Pure selectors over the parsed sheet-warning list — the KMP port of the
 * helpers in Dart `lib/widgets/gamification/sheet_warning_attendance.dart`.
 * These let a feature (attendance, emergency logout) pick the warnings that
 * apply to a given sheet and flatten their CTA overrides.
 */

/** All warnings whose lifecycle matches [lifecycleActionType]. */
fun List<SheetWarning>.filterForLifecycle(lifecycleActionType: String): List<SheetWarning> =
    filter { it.lifecycleActionType == lifecycleActionType }

/**
 * Flatten the CTA overrides across the given warnings into a lowercase-keyed
 * map (last-wins), mirroring Dart `GamificationManager.resolveCtaOverrides`.
 */
fun List<SheetWarning>.ctaOverridesForSheet(): Map<String, CtaOverride> {
    val map = LinkedHashMap<String, CtaOverride>()
    for (warning in this) {
        val overrides = warning.ctaOverrides ?: continue
        for (override in overrides) {
            map[override.ctaId.lowercase()] = override
        }
    }
    return map
}
