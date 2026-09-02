package com.snabbit.runner.shared.features.home.domain.model

import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftPhase

/**
 * Background archetype the Home screen paints behind the card list. A projection
 * of [ShiftPhase] — derived, not stored — so the same phase can never disagree
 * with itself across renders.
 */
enum class HomeBg { Pink, Grey, Map }

fun ShiftPhase.bg(): HomeBg = when (this) {
    ShiftPhase.PreShift -> HomeBg.Pink
    ShiftPhase.SearchingForJobs -> HomeBg.Map
    ShiftPhase.Logout -> HomeBg.Map
}
