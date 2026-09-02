package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme

@Composable
internal actual fun VideoPlayer(filePath: String, modifier: Modifier) {
    // TODO(iOS launch): play via AVPlayer / AVPlayerViewController when the iOS
    // camera path is built. iOS capture is stubbed, so show a placeholder.
    Box(modifier, contentAlignment = Alignment.Center) {
        SnabbitText(
            text = "Video preview (iOS pending)",
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textInverse,
        )
    }
}
