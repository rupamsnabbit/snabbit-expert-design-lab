package com.snabbit.runner.shared.features.kavach.shared

import com.snabbit.runner.shared.core.navigation.Destination
import kotlinx.serialization.Serializable

/**
 * Home destination for the Safety (Kavach) feature. Pure data (no UI/platform types)
 * so `commonMain` stays iOS-compilable and the back stack is unit-testable.
 * Carries the Kavach card, SOS entry and status pill; screen mapping lives in the `:app` host.
 */
@Serializable
data object SafetyHome : Destination
