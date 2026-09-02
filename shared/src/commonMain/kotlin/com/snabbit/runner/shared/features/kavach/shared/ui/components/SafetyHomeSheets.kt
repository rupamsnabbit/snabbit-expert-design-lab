package com.snabbit.runner.shared.features.kavach.shared.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitImage
import com.snabbit.design.atoms.SnabbitRichSpan
import com.snabbit.design.atoms.SnabbitRichText
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.kavach.shared.designgaps.KavachDesignGaps
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionResult
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.kavach_battery_low_body
import com.snabbit.runner.shared.resources.kavach_battery_low_cta
import com.snabbit.runner.shared.resources.kavach_battery_low_title
import com.snabbit.runner.shared.resources.kavach_consent_agree
import com.snabbit.runner.shared.resources.kavach_consent_intro
import com.snabbit.runner.shared.resources.kavach_consent_monitoring_body
import com.snabbit.runner.shared.resources.kavach_consent_monitoring_title
import com.snabbit.runner.shared.resources.kavach_consent_sos_body
import com.snabbit.runner.shared.resources.kavach_consent_sos_title
import com.snabbit.runner.shared.resources.kavach_consent_stay_protected_body
import com.snabbit.runner.shared.resources.kavach_consent_stay_protected_title
import com.snabbit.runner.shared.resources.kavach_consent_terms
import com.snabbit.runner.shared.resources.kavach_guide_bg
import com.snabbit.runner.shared.resources.kavach_intro_hero
import com.snabbit.runner.shared.resources.kavach_intro_monitoring_icon
import com.snabbit.runner.shared.resources.kavach_intro_safety_shield
import com.snabbit.runner.shared.resources.kavach_intro_sos_icon
import com.snabbit.runner.shared.resources.kavach_keep_phone_body
import com.snabbit.runner.shared.resources.kavach_keep_phone_cta
import com.snabbit.runner.shared.resources.kavach_keep_phone_title
import com.snabbit.runner.shared.resources.kavach_permission_denied_body
import com.snabbit.runner.shared.resources.kavach_permission_not_now
import com.snabbit.runner.shared.resources.kavach_permission_retry
import com.snabbit.runner.shared.resources.kavach_permission_settings
import com.snabbit.runner.shared.resources.kavach_permission_settings_body
import com.snabbit.runner.shared.resources.kavach_permission_title
import com.snabbit.runner.shared.resources.low_battery_bg
import com.snabbit.runner.shared.resources.low_battery_tiltted_icon
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.StringResource
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * "Always keep your phone with you" sheet (Figma 19-15020) — consent-style hero + blue "Snabbit Kavach"
 * wordmark + title/body + blue-500 CTA. Bespoke body (not the shared [InfoSheet]) since it carries the
 * hero + wordmark that BatteryLow must not; reuses the consent hero assets.
 */
@Composable
fun KeepPhoneSheetContent(onConfirm: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(color = SnabbitColorsLight.whiteDefault),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`7`),
    ) {
        Box(modifier = Modifier.fillMaxWidth()) {
            SnabbitImage(
                painter = painterResource(Res.drawable.kavach_guide_bg),
                contentDescription = null,
                contentScale = ContentScale.Fit,
            )

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // Hero: connector-wave backing + shield (reuse the consent hero assets), Figma ~150dp band.
                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    // Hero: baked rings + connector-wave + shield + sparkles (Figma 2417-19996).
                    SnabbitImage(
                        painter = painterResource(Res.drawable.kavach_intro_hero),
                        contentDescription = null,
                        contentScale = ContentScale.FillWidth,
                        modifier = Modifier.fillMaxWidth(),
                    )

                    // Blue "Snabbit Kavach" wordmark — Figma 20px blue-500, Medium + Bold, tracking -0.5.
                    Row(
                        horizontalArrangement = Arrangement.Center,
                        modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 30.dp)
                    ) {
                        SnabbitText(
                            text = "Snabbit ",
                            variant = SnabbitTextVariant.Heading3,
                            fontWeight = FontWeight.Medium,
                            color = KavachDesignGaps.Colors.kavachBlue500,
                            letterSpacing = KavachDesignGaps.KeepPhoneSheet.wordmarkTracking,
                        )
                        SnabbitText(
                            text = "Kavach",
                            variant = SnabbitTextVariant.Heading3,
                            fontWeight = FontWeight.Bold,
                            color = KavachDesignGaps.Colors.kavachBlue500,
                            letterSpacing = KavachDesignGaps.KeepPhoneSheet.wordmarkTracking,
                        )
                    }
                }
                // Title + body cluster (Figma 12px gap).
                Column(
                    modifier = Modifier.fillMaxWidth().padding(SnabbitTheme.spacing.`7`),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`4`),
                ) {
                    SnabbitText(
                        text = stringResource(Res.string.kavach_keep_phone_title),
                        variant = SnabbitTextVariant.Heading2,
                        textAlign = TextAlign.Center,
                    )
                    SnabbitText(
                        text = stringResource(Res.string.kavach_keep_phone_body),
                        variant = SnabbitTextVariant.BodyLg,
                        fontWeight = FontWeight.Medium,
                        color = SnabbitTheme.colors.textSecondary,
                        textAlign = TextAlign.Center,
                    )
                }
                SnabbitButton(
                    modifier = Modifier.padding(start = 20.dp, end = 20.dp, bottom = 14.dp),
                    text = stringResource(Res.string.kavach_keep_phone_cta),
                    onClick = onConfirm,
                    style = SnabbitButtonStyle.Primary,
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                    containerColor = KavachDesignGaps.Colors.kavachBlue500,   // Figma blue-500 #3B82F6
                    contentColor = Color.White,
                )
            }
        }
    }
}

/** "Battery is running low" sheet body. */
@Composable
fun BatteryLowSheetContent(onDismiss: () -> Unit) {
    InfoSheet(
        illustration = Res.drawable.low_battery_tiltted_icon,
        headerBg = Res.drawable.low_battery_bg,
        title = Res.string.kavach_battery_low_title,
        body = Res.string.kavach_battery_low_body,
        cta = Res.string.kavach_battery_low_cta,
        ctaStyle = SnabbitButtonStyle.Primary,   // pink-600 #F70F79 (Figma)
        ctaContainerColor = null,
        onCta = onDismiss,
    )
}

/** Shared illustration + title + body + single-CTA sheet layout. */
@Composable
private fun InfoSheet(
    illustration: DrawableResource?,
    title: StringResource,
    body: StringResource,
    cta: StringResource,
    ctaStyle: SnabbitButtonStyle,
    ctaContainerColor: Color?,
    onCta: () -> Unit,
    headerBg: DrawableResource? = null,
) {
    Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        // Full-bleed header band (e.g. the battery sheet's pink gradient) with the illustration on it.
        // Height derives from the bg's natural aspect (no fixed dp, no FillBounds stretch); the
        // illustration scales as a fraction of screen width so nothing crops on any device.
        if (headerBg != null) {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                SnabbitImage(
                    painter = painterResource(headerBg),
                    contentDescription = null,
                    contentScale = ContentScale.FillWidth,
                    modifier = Modifier.fillMaxWidth(),
                )
                if (illustration != null) {
                    SnabbitImage(
                        painter = painterResource(illustration),
                        contentDescription = null,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxWidth(KavachDesignGaps.BatterySheet.iconWidthFraction),
                    )
                }
            }
        }
        Column(
            modifier = Modifier.fillMaxWidth().padding(SnabbitTheme.spacing.`7`),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`7`),
        ) {
            if (headerBg == null && illustration != null) {
                SnabbitImage(
                    painter = painterResource(illustration),
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.size(96.dp),
                )
            }
            // Title + body cluster — Figma 12px gap between the two (spacing.4).
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`4`),
            ) {
                SnabbitText(
                    text = stringResource(title),
                    variant = SnabbitTextVariant.Heading2,
                    textAlign = TextAlign.Center
                )
                SnabbitText(
                    text = stringResource(body),
                    variant = SnabbitTextVariant.BodyLg,
                    fontWeight = FontWeight.Medium,   // Figma Body-M/16-Medium (DS bodyLg is 16-Regular)
                    color = SnabbitTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }
            SnabbitButton(
                text = stringResource(cta),
                onClick = onCta,
                style = ctaStyle,
                size = SnabbitButtonSize.L,
                fullWidth = true,
                containerColor = ctaContainerColor,
                contentColor = ctaContainerColor?.let { Color.White },
            )
        }
    }
}

/** "Introducing Snabbit Kavach" consent sheet body. */
@Composable
fun ConsentSheetContent(onAgree: () -> Unit, loading: Boolean = false) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            // Sheet blue wash → white (Figma 421:17747), concentrated in the top ~40% behind the hero.
            // Pass-2: pair with the richer hero (rings+sparkles) + bg raster.
            .background(
                Brush.verticalGradient(
                    0.0f to KavachDesignGaps.ConsentSheet.bgGradientTop,
                    0.4f to SnabbitTheme.colors.bgPrimary,
                ),
            )
            .padding(vertical = SnabbitTheme.spacing.`7`),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`5`),
    ) {

        Box(
            modifier = Modifier.fillMaxWidth()
        ) {
            // Hero: baked rings + connector-wave + shield + sparkles (Figma 2417-19996).
            SnabbitImage(
                painter = painterResource(Res.drawable.kavach_intro_hero),
                contentDescription = null,
                contentScale = ContentScale.FillWidth,
                modifier = Modifier.fillMaxWidth(),
            )
            Column(
                modifier = Modifier.fillMaxWidth().align(Alignment.BottomCenter)
                    .padding(top = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                SnabbitText(
                    text = stringResource(Res.string.kavach_consent_intro),
                    variant = SnabbitTextVariant.Caption,
                    fontWeight = FontWeight.Bold,                       // Figma "INTRODUCING" Bold
                    letterSpacing = 1.sp,
                    color = SnabbitTheme.colors.textNeutralInkDeep,     // exact #101840
                    textAlign = TextAlign.Center,
                )
                SnabbitRichText(
                    spans = listOf(
                        SnabbitRichSpan(
                            text = "Snabbit",
                            style = SpanStyle(
                                color = SnabbitTheme.colors.textInfoDeep,
                                fontSize = 32.sp
                            )
                        ),
                        SnabbitRichSpan(
                            text = " Kavach",
                            style = SpanStyle(
                                color = SnabbitTheme.colors.textInfoDeep,
                                fontWeight = FontWeight.Bold,
                                fontSize = 32.sp
                            )
                        )
                    )
                )
            }

        }
        // Feature rows — Figma inter-row gap 24 (vs the sheet's 16 rhythm).
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SnabbitTheme.spacing.`7`)
                .padding(bottom = 20.dp, top = 20.dp),
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`7`),
        ) {
            FeatureRow(
                Res.drawable.kavach_intro_safety_shield,
                Res.string.kavach_consent_stay_protected_title,
                Res.string.kavach_consent_stay_protected_body
            )
            FeatureRow(
                Res.drawable.kavach_intro_monitoring_icon,
                Res.string.kavach_consent_monitoring_title,
                Res.string.kavach_consent_monitoring_body
            )
            FeatureRow(
                Res.drawable.kavach_intro_sos_icon,
                Res.string.kavach_consent_sos_title,
                Res.string.kavach_consent_sos_body
            )
        }
        // TODO(link): the "Terms & Conditions" tail should be a SnabbitRichText underlined link once the target is known.

        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = SnabbitTheme.spacing.`7`),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            SnabbitText(
                text = stringResource(Res.string.kavach_consent_terms),
                variant = SnabbitTextVariant.Caption,               // Figma 12 (was Small/10)
                color = KavachDesignGaps.ConsentSheet.featureBodyColor,
                textAlign = TextAlign.Center,
            )
            SnabbitButton(
                modifier = Modifier.padding(top = 16.dp),
                text = stringResource(Res.string.kavach_consent_agree),
                onClick = onAgree,
                loading = loading,
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
                containerColor = SnabbitTheme.colors.textInfoStrong,   // exact #1B7DE9 (Figma)
                contentColor = Color.White,
            )
        }
    }
}

/*@Preview
@Composable
private fun ConsentSheetContentPreview() {
    SnabbitTheme {
        ConsentSheetContent(onAgree = {})
    }
}*/

/**
 * Permission-blocked dialog body. Shown when activation is blocked on mic/location.
 * State-specific primary action: soft [KavachPermissionResult.Denied] → "Try again" (re-request);
 * [KavachPermissionResult.NeedsSettings] (permanent) → "Open settings". "Not now" dismisses.
 */
@Composable
fun PermissionSheetContent(
    result: KavachPermissionResult,
    onRetry: () -> Unit,
    onOpenSettings: () -> Unit,
    onDismiss: () -> Unit,
    // false for a MANDATORY gate (e.g. the job-start mic block) — hides "Not now" so the only exit is
    // granting the permission (spec 1a).
    dismissible: Boolean = true,
) {
    val needsSettings = result is KavachPermissionResult.NeedsSettings
    Column(
        modifier = Modifier.fillMaxWidth().padding(SnabbitTheme.spacing.`7`),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`5`),
    ) {
        // No Figma asset supplied for the permission sheet — illustration omitted (flagged).
        SnabbitText(
            text = stringResource(Res.string.kavach_permission_title),
            variant = SnabbitTextVariant.Heading2,
            textAlign = TextAlign.Center,
        )
        SnabbitText(
            text = stringResource(if (needsSettings) Res.string.kavach_permission_settings_body else Res.string.kavach_permission_denied_body),
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
        )
        SnabbitButton(
            text = stringResource(if (needsSettings) Res.string.kavach_permission_settings else Res.string.kavach_permission_retry),
            onClick = if (needsSettings) onOpenSettings else onRetry,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            containerColor = SnabbitTheme.colors.textInfo,
            contentColor = Color.White,
        )
        if (dismissible) {
            SnabbitButton(
                text = stringResource(Res.string.kavach_permission_not_now),
                onClick = onDismiss,
                style = SnabbitButtonStyle.NeutralStroke,
                size = SnabbitButtonSize.L,
                fullWidth = true,
            )
        }
    }
}

/** Consent feature row: icon + title + subtitle. */
@Composable
private fun FeatureRow(icon: DrawableResource, title: StringResource, body: StringResource) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`4`),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SnabbitImage(
            painter = painterResource(icon),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = Modifier.size(48.dp),
        )
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`2`),  // Figma title↔body 4
        ) {
            // Figma: 16 Semibold title over 14 body.
            SnabbitText(
                text = stringResource(title),
                variant = SnabbitTextVariant.BodyLg,
                fontWeight = FontWeight.SemiBold,
            )
            SnabbitText(
                text = stringResource(body),
                variant = SnabbitTextVariant.BodyMd,
                color = KavachDesignGaps.ConsentSheet.featureBodyColor,  // gray-600 #4B5563
            )
        }
    }
}
