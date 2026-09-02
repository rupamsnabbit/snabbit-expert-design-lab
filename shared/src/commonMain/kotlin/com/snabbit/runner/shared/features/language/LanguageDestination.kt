package com.snabbit.runner.shared.features.language

import com.snabbit.runner.shared.core.navigation.Destination
import kotlinx.serialization.Serializable

/**
 * Native (Compose) navigation target for the Language screen — pushed onto the
 * [NavigationController][com.snabbit.runner.shared.core.navigation.NavigationController]
 * back stack, so the screen renders inside the single nav host and back returns
 * to the caller. Pure data (no platform types) → iOS-safe.
 *
 * Opened from the Flutter drawer via
 * `KmpNavigationBridge.openNativeDestination("language", …)` and from the Profile
 * tab via `nav.navigate(LanguageDestination(...))`. Carries the launch-time
 * values as (nullable) args — the runner's [currentLanguage] and the two
 * server-driven i18n labels ([title], [confirmLabel]); the `:app` `nativeScreen`
 * registration falls back to `LanguageStrings` defaults.
 */
@Serializable
data class LanguageDestination(
    val currentLanguage: String? = null,
    val title: String? = null,
    val confirmLabel: String? = null,
) : Destination
