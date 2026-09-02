package com.snabbit.runner.shared.features.shift.presentation.login

import com.snabbit.runner.shared.core.navigation.Destination
import kotlinx.serialization.Serializable

/**
 * Full-screen shift-login flow (intro → camera → upload → success). Pushed onto
 * the [com.snabbit.runner.shared.core.navigation.NavigationController] when the
 * runner taps Login on Home; pops back on the flow's Finish. Internal-only — not
 * opened by Flutter or a deep link, so no `nativeDestination` binding, only the
 * androidMain `nativeScreen<ShiftLogin>` that renders it.
 */
@Serializable
data object ShiftLogin : Destination
