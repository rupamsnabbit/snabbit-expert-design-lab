package com.snabbit.runner.shared.features.comingsoon

import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource

/**
 * Placeholder content for home-shell tabs that aren't built yet — reuses the
 * tab's own bottom-nav icon inside a light-pink circle, plus a title/body.
 */
@Composable
fun ComingSoonScreen(
    tabLabel: String,
    icon: DrawableResource,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(SnabbitTheme.colors.bgPrimary)
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size(96.dp)
                .background(SnabbitTheme.colors.bgBrandSubtle, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitImage(
                painter = painterResource(icon),
                contentDescription = null,
                modifier = Modifier.size(40.dp),
            )
        }
        SnabbitText(
            text = "$tabLabel is coming soon",
            variant = SnabbitTextVariant.Heading3,
            color = SnabbitTheme.colors.textPrimary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 24.dp),
        )
        SnabbitText(
            text = "We're putting the finishing touches on it. Check back shortly.",
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}
