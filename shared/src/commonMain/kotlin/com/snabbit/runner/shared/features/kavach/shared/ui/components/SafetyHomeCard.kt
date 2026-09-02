package com.snabbit.runner.shared.features.kavach.shared.ui.components

import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldAssetReader
import org.koin.mp.KoinPlatform
import com.snabbit.runner.shared.resources.active_job_kavach_pill
import com.snabbit.runner.shared.resources.active_job_kavach_wave
import com.snabbit.runner.shared.resources.kavach_activate
import com.snabbit.runner.shared.resources.kavach_no_storage
import com.snabbit.runner.shared.resources.shield_play_icon
import com.snabbit.runner.shared.resources.storage_warning
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitImage
import com.snabbit.design.atoms.SnabbitLottie
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.kavach.shared.designgaps.KavachDesignGaps
import io.github.alexzhirkevich.compottie.LottieCompositionSpec
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * Safety-Kavach card — Figma "With Kavach" (19-14862) / monitoring (19-15747):
 *  - not recording, storage ok → gradient card + "Snabbit Kavach" lockup + blue **Activate**
 *  - not recording, low storage → Activate disabled + a red **storage banner** ([onStorageClick])
 *  - recording               → two-tone **pulse dot** + full-bleed waveform
 *
 * Container: #EBFDFF→white vertical gradient + 1px border, radius `xl`. The shield + "Snabbit Kavach"
 * lockup and the waveform are the shipped baked webps (brand lockup kept whole — pixel-exact, no type
 * gaps). Brand blue + the dot core come from [KavachDesignGaps.Colors] (not on the SnabbitColors interface).
 */
@Composable
fun SafetyHomeCard(
    recording: Boolean,
    noStorage: Boolean,
    onActivate: () -> Unit,
    onStorageClick: () -> Unit,
    activationLottiePlaying: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val showBanner = !recording && noStorage
    val cardShape = RoundedCornerShape(
        bottomStart = SnabbitTheme.borderRadius.xl,
        bottomEnd = SnabbitTheme.borderRadius.xl,)  // 16 (Figma activate; monitoring frame drafts 10)
    Box(modifier = modifier) {
    Column(
        modifier = Modifier
            .clip(cardShape)
            .background(
                Brush.verticalGradient(
                    KavachDesignGaps.KavachCard.gradientStopTop to SnabbitTheme.colors.bgInfoTint,    // #EBFDFF @21.9%
                    KavachDesignGaps.KavachCard.gradientStopBottom to SnabbitTheme.colors.bgPrimary,  // #FFFFFF @56.5%
                ),
            )
            .border(1.dp, SnabbitTheme.colors.borderDefault, cardShape),   // #E5E7EB
    ) {
        Column(modifier = Modifier
            .fillMaxWidth()
            .padding(top = 35.dp)
            .padding(SnabbitTheme.spacing.`5`)) {   // 16
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`2`),
            ) {
                // Shield + "Snabbit Kavach" wordmark (shipped baked lockup — kept whole).
                SnabbitImage(
                    painter = painterResource(Res.drawable.active_job_kavach_pill),
                    contentDescription = "Snabbit Kavach",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.height(36.dp),
                )
                Spacer(modifier = Modifier.weight(1f))
                if (recording) {
                    PulseDot()
                } else {
                    SnabbitButton(
                        text = stringResource(Res.string.kavach_activate),
                        onClick = onActivate,
                        style = SnabbitButtonStyle.Primary,
                        size = SnabbitButtonSize.XS,   // Figma 32h / r6 / icon16
                        enabled = !noStorage,
                        containerColor = KavachDesignGaps.Colors.kavachBlue500,  // #3B82F6
                        contentColor = Color.White,
                        leadingIcon = {
                            SnabbitImage(
                                painter = painterResource(Res.drawable.shield_play_icon),
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),   // Pass-2: swap to the phosphor play-fill
                            )
                        },
                    )
                }
            }
        }
        if (recording) {
            // Full-bleed recording waveform (edge-to-edge, clipped by the card radius).
            SnabbitImage(
                painter = painterResource(Res.drawable.active_job_kavach_wave),
                contentDescription = null,
                contentScale = ContentScale.FillWidth,
                modifier = Modifier.fillMaxWidth().padding(bottom = SnabbitTheme.spacing.`4`),
            )
        }
        if (showBanner) StorageBanner(onClick = onStorageClick)
    }
        // One-shot activation Lottie over the card (Flutter partner_home parity: cover-scaled + clipped to
        // the card so it never overflows into the screen, non-blocking); auto-clears via the VM.
        if (activationLottiePlaying) ActivationLottie(modifier = Modifier.matchParentSize().clip(cardShape))
    }
}

/** Pulsing status dot — two-tone (Figma #DBEAFE ring / #3B82F6 core); ring scales 0.8→1.2 fading 0.5→0. */
@Composable
private fun PulseDot(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "pulse")
    val scale by transition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(tween(1500), RepeatMode.Restart),
        label = "scale",
    )
    val ringAlpha by transition.animateFloat(
        initialValue = 0.5f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(tween(1500), RepeatMode.Restart),
        label = "alpha",
    )
    Box(modifier = modifier.size(KavachDesignGaps.KavachCard.dotOuter), contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .size(KavachDesignGaps.KavachCard.dotOuter)
                .scale(scale)
                .alpha(ringAlpha)
                .clip(CircleShape)
                .background(KavachDesignGaps.Colors.recordingDotRing),
        )
        Box(
            modifier = Modifier
                .size(KavachDesignGaps.KavachCard.dotInner)
                .clip(CircleShape)
                .background(KavachDesignGaps.Colors.kavachBlue500),
        )
    }
}

/** Low-storage warning banner attached to the card bottom — tap opens app settings (via [onClick]). */
@Composable
private fun StorageBanner(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(bottomStart = SnabbitTheme.borderRadius.xl, bottomEnd = SnabbitTheme.borderRadius.xl))
            .background(SnabbitTheme.colors.bgErrorTint) // ≈ Figma red-100 #FEE2E2
            .clickable(onClick = onClick)
            .padding(horizontal = SnabbitTheme.spacing.`4`, vertical = SnabbitTheme.spacing.`3`),  // 12 / 8
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`3`),   // 8
    ) {
        SnabbitImage(
            painter = painterResource(Res.drawable.storage_warning),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = Modifier.width(24.dp).height(20.dp),   // Figma 24×20
        )
        SnabbitText(
            text = stringResource(Res.string.kavach_no_storage),
            variant = SnabbitTextVariant.Caption,   // Figma 12 / lh16
            fontWeight = FontWeight.Medium,          // Figma weight 500
            color = SnabbitTheme.colors.textError,   // #DC2626
            modifier = Modifier.weight(1f),
        )
    }
}

/** One-shot Kavach activation Lottie (kavach_opt.json) via the DS SnabbitLottie — non-blocking overlay. */
@Composable
private fun ActivationLottie(modifier: Modifier = Modifier) {
    val json by produceState<String?>(null) {
        value = runCatching {
            // A miss returns empty bytes — keep it null (not "") so the json?.let below skips rendering
            // rather than handing empty JSON to the Lottie player.
            KoinPlatform.getKoin().get<ShieldAssetReader>().read(ShieldAssetReader.ACTIVATION_LOTTIE)
                .takeIf { it.isNotEmpty() }?.decodeToString()
        }.getOrNull()
    }
    json?.let {
        SnabbitLottie(
            spec = LottieCompositionSpec.JsonString(it),
            contentDescription = null,
            iterations = 1,                     // one-shot (Flutter repeat:false)
            contentScale = ContentScale.Crop,   // BoxFit.cover parity
            modifier = modifier,
        )
    }
}

@Preview
@Composable
private fun SafetyHomeCardPreview() {
    SnabbitTheme {
        SafetyHomeCard(
            recording = false,
            noStorage = false,
            onActivate = {},
            onStorageClick = {},
        )
    }
}
