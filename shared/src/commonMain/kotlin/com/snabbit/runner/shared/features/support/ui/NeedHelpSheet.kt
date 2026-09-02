package com.snabbit.runner.shared.features.support.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.support.data.HelplineRepository
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet
import org.koin.mp.KoinPlatform.getKoin

/**
 * Copy for [NeedHelpSheet] — English fallbacks mirroring the Flutter `SupportPopup`
 * language keys (`need_help` / `connect_to_representative` / `call_us`).
 */
data class SupportStrings(
    val needHelpTitle: String = "Need help?",
    val needHelpSubtitle: String =
        "We will connect you with one of our representatives to resolve your concern promptly",
    val callUs: String = "Call us",
)

/**
 * Overlays the server-driven i18n map onto these [SupportStrings]; absent keys fall back
 * to the English defaults. All three keys are Snabbit-invented (no PM CSV row) — pending
 * backend, so this is inert (English) until then.
 */
fun SupportStrings.localized(store: LocalizationStore): SupportStrings = copy(
    needHelpTitle = store.getMessage("support.need_help_title", needHelpTitle),
    needHelpSubtitle = store.getMessage("support.need_help_subtitle", needHelpSubtitle),
    callUs = store.getMessage("support.call_us", callUs),
)

/**
 * "Need help?" support sheet — the KMP-native replica of the Flutter `SupportPopup`
 * ([lib/widgets/support_popup.dart]): a title + subtitle and a full-width **"Call us"**
 * action. On show it resolves the helpline number via [helplineRepo]; the button loads
 * until the number is ready, then hands it to [onCall] (the host's masked-call → dialer
 * fallback = `CallUtils.handleCallInitiation` parity) and dismisses.
 *
 * DS chrome: no drag handle (the close button is the affordance), and the footer clears
 * the system navigation bar via [navigationBarsPadding] so the CTA is never obscured.
 * Reusable across screens; today it's shown from the Job header's Help pill (via
 * `ActiveJobOverlay`). [helplineType] mirrors the Flutter query param — `PRIMARY` for
 * general support.
 */
@Composable
fun NeedHelpSheet(
    helplineRepo: HelplineRepository,
    onCall: (String) -> Unit,
    onDismiss: () -> Unit,
    strings: SupportStrings = SupportStrings().localized(getKoin().get()),
    helplineType: String = HelplineRepository.DEFAULT_TYPE,
) {
    // null = still resolving (the button shows a spinner + stays disabled so it can't be
    // tapped empty). The repo always resolves to a dialable number (SOS fallback on failure).
    var number by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(helplineType) { number = helplineRepo.helplineNumber(helplineType) }

    SnabbitBottomSheet(
        onDismissRequest = onDismiss,
        showCloseButton = true,
        draggable = false,
        footer = {
            val resolved = number
            // navigationBarsPadding keeps the CTA above the system nav bar (3-button + gesture).
            Column(Modifier.fillMaxWidth().navigationBarsPadding()) {
                SnabbitButton(
                    text = strings.callUs,
                    onClick = {
                        resolved?.let(onCall)
                        onDismiss()
                    },
                    style = SnabbitButtonStyle.Success,
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                    enabled = resolved != null,
                    loading = resolved == null,
                )
            }
        },
    ) {
        // The card already supplies its padding + close button; just the copy here (left-aligned,
        // matching SupportPopup). Card spacing separates this from the footer CTA.
        Column(Modifier.fillMaxWidth()) {
            SnabbitText(
                text = strings.needHelpTitle,
                variant = SnabbitTextVariant.Heading2,
                color = SnabbitTheme.colors.textPrimary,
            )
            Spacer(Modifier.height(SnabbitTheme.spacing.componentGapSm))
            SnabbitText(
                text = strings.needHelpSubtitle,
                variant = SnabbitTextVariant.BodyMd,
                color = SnabbitTheme.colors.textBody,
            )
        }
    }
}
