package com.snabbit.runner.shared.features.job.presentation.inprogress

import androidx.compose.ui.graphics.vector.ImageVector

/**
 * One customer / cooking-preference entry — the KMP analogue of a `cooking_preference` map value
 * (`{ title, value }`) in Flutter's `CookingPreferenceDetails`.
 *
 * @param label the preference name (e.g. "Spice level"), server-driven copy.
 * @param value the chosen level (e.g. "Low"), server-driven copy.
 * @param icon optional leading glyph (16dp, gray-600); null renders the row icon-less. Build it
 *   from the preference key via [customerPreferenceIcon].
 */
data class CustomerPreferenceItem(
    val label: String,
    val value: String,
    val icon: ImageVector? = null,
)
