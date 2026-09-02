package com.snabbit.runner.shared.features.profile

import com.snabbit.runner.shared.core.navigation.Destination
import kotlinx.serialization.Serializable

/**
 * The Profile tab's content destination within the home shell — the native
 * (Compose) target rendered when the runner selects the Profile tab. Pure data
 * (no platform types) so `commonMain` stays iOS-compilable.
 *
 * Seeded into the shell's Profile tab back stack by `homeTabsSeed` (replacing the
 * `ComingSoon("Profile")` placeholder) and rendered by the `nativeScreen<ProfileRoot>`
 * registration in `:app`.
 */
@Serializable
data object ProfileRoot : Destination
