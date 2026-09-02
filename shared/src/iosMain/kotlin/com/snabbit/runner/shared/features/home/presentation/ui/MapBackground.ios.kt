package com.snabbit.runner.shared.features.home.presentation.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

// Runner app is Android-only in prod (see snabbit-runner-app/CLAUDE.md).
// This actual exists so `:shared` still compiles for iOS targets — verified
// via `:shared:compileTestKotlinIosArm64`. Wire Apple Maps when iOS ships.
@Composable
actual fun MapBackground(
    modifier: Modifier,
    coordinates: MapCoords,
    sevaMarkers: List<SevaMarker>,
    onSevaClick: (String) -> Unit,
    profilePhotoUrl: String?,
) {
    Box(modifier = modifier)
}
