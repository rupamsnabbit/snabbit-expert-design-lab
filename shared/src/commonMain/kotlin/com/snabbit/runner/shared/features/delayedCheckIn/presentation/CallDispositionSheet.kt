package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitCard
import com.snabbit.design.atoms.SnabbitCardVariant
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import coil3.compose.SubcomposeAsyncImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.image.isNetworkImageUrl
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.SupportOption
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet
import org.jetbrains.compose.ui.tooling.preview.Preview

/** Reason cards per grid row (Figma / `job_support_bottom_sheet.dart`: `crossAxisCount: 2`). */
private const val GRID_COLUMNS = 2

/** Reason-card width : height (Dart `childAspectRatio: 1.6`). */
private const val CARD_ASPECT_RATIO = 1.6f

/**
 * The **"Call Support Partner"** disposition sheet (FR-12/13) — before the runner is
 * connected to support, they pick *why* they're calling from a [GRID_COLUMNS]-wide grid
 * of reason cards, then Submit sends the chosen option as the `disposition_tag`.
 *
 * Behavioural parity source (Dart, read-only): `JobSupportBottomSheet` in
 * `lib/widgets/delayed_checkin/job_support_bottom_sheet.dart` — single-select grid,
 * Submit disabled until a reason is chosen, spinner while the submission is in flight.
 * What happens *after* submit (Ameyo callback toast vs dialling the helpline) is the
 * ViewModel's job — this sheet only reports the chosen option via [onSubmit].
 *
 * Selection is transient local input (the same pattern as `CheckInSheet`'s OTP text):
 * only the submitted option reaches the ViewModel, and the selection re-seeds when
 * [options] change.
 *
 * @param options the reason grid, from `readJobSupportOptions` (FR-11). Callers gate on
 *   non-empty — Dart maps a missing config to a "Support details not found" snackbar
 *   instead of opening the sheet.
 * @param isSubmitting a disposition call is in flight — Submit spins, taps are blocked.
 * @param onSubmit the runner submitted [SupportOption] (the whole option, so the caller
 *   can send both `disposition_tag` = id and `disposition_message` = label, as Dart does).
 * @param onDismiss scrim tap / back press closed the sheet. The caller owns visibility.
 * @param optionIcon slot for the reason card icon. Defaults to [DispositionIcon]: the
 *   server-driven [SupportOption.iconUrl] loaded via Coil (Dart parity:
 *   `CachedNetworkImage`), falling back to the generic support glyph while loading or
 *   on error — the Compose analogue of Dart's `errorWidget`.
 */
@Composable
fun CallDispositionSheet(
    options: List<SupportOption>,
    isSubmitting: Boolean,
    strings: DelayedCheckinStrings,
    onSubmit: (SupportOption) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    optionIcon: @Composable (SupportOption) -> Unit = { DispositionIcon(it) },
) {
    var selectedId by remember(options) { mutableStateOf<String?>(null) }

    SnabbitBottomSheet(
        onDismissRequest = onDismiss,
        modifier = modifier,
        title = strings.callSupportTitle,
        // No close button or drag handle (per the mock) — scrim tap / back dismisses.
        showCloseButton = false,
        draggable = false,
        // Lock the sheet while a disposition is in flight: M3 would otherwise hide itself on a
        // scrim tap / back press while the ViewModel keeps SupportSheetState.Shown (it drops
        // DismissSheet during submit), stranding an invisible modal window over the job screen.
        // Non-dismissible blocks the scrim (confirmValueChange) and back (PlatformBackHandler);
        // once submitting clears — success closes the sheet, failure keeps it up for retry — it
        // becomes dismissible again so the runner can close it normally.
        dismissible = !isSubmitting,
    ) {
        CallDispositionSheetContent(
            options = options,
            selectedId = selectedId,
            isSubmitting = isSubmitting,
            strings = strings,
            onSelect = { selectedId = it },
            onSubmitClick = {
                options.firstOrNull { it.id == selectedId }?.let(onSubmit)
            },
            optionIcon = optionIcon,
        )
    }
}

/**
 * The sheet body (subtitle → reason grid → Submit), stateless over [selectedId] so it can
 * be exercised directly in UI tests without Material3's modal window (the same split as
 * `SnabbitBottomSheetContent`).
 */
@Composable
internal fun CallDispositionSheetContent(
    options: List<SupportOption>,
    selectedId: String?,
    isSubmitting: Boolean,
    strings: DelayedCheckinStrings,
    onSelect: (id: String) -> Unit,
    onSubmitClick: () -> Unit,
    optionIcon: @Composable (SupportOption) -> Unit = { DispositionIcon(it) },
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SnabbitText(
            text = strings.callSupportSubtitle,
            modifier = Modifier.fillMaxWidth(),
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
        )

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            options.chunked(GRID_COLUMNS).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    row.forEach { option ->
                        DispositionCard(
                            option = option,
                            isSelected = option.id == selectedId,
                            enabled = !isSubmitting,
                            onSelect = { onSelect(option.id) },
                            icon = optionIcon,
                            modifier = Modifier.weight(1f),
                        )
                    }
                    // Odd trailing option keeps a half-width cell, like GridView.count.
                    repeat(GRID_COLUMNS - row.size) {
                        Spacer(Modifier.weight(1f))
                    }
                }
            }
        }

        SnabbitButton(
            text = strings.submit,
            onClick = onSubmitClick,
            style = SnabbitButtonStyle.NeutralFilled,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            enabled = selectedId != null && !isSubmitting,
            loading = isSubmitting,
        )
    }
}

@Composable
private fun DispositionCard(
    option: SupportOption,
    isSelected: Boolean,
    enabled: Boolean,
    onSelect: () -> Unit,
    icon: @Composable (SupportOption) -> Unit,
    modifier: Modifier = Modifier,
) {
    SnabbitCard(
        modifier = modifier
            .aspectRatio(CARD_ASPECT_RATIO)
            .semantics { selected = isSelected },
        variant = if (isSelected) SnabbitCardVariant.Selected else SnabbitCardVariant.Base,
        onClick = if (enabled) onSelect else null,
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically),
        ) {
            icon(option)
            // Figma spec: 14px labels in #6B7280 — BodyMd (14sp) + the DS
            // text.secondary token, no raw sizes.
            SnabbitText(
                text = option.label,
                variant = SnabbitTextVariant.BodyMd,
                color = SnabbitTheme.colors.textSecondary,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * The reason card's icon: [SupportOption.iconUrl] loaded via Coil's Ktor fetcher —
 * Dart parity `CachedNetworkImage(imageUrl: option.iconUrl)` in
 * `job_support_bottom_sheet.dart`. A blank/absent url, the loading phase, and a
 * fetch error all render [DispositionIconFallback], mirroring Dart's `errorWidget`.
 */
@Composable
private fun DispositionIcon(option: SupportOption) {
    // http(s) only. `iconUrl` is server-supplied, and the loader registers our Ktor
    // fetcher with `.components { add(…) }`, which AUGMENTS Coil's defaults — so
    // FileUriFetcher/ContentUriFetcher stay live and a `file://` / `content://` payload
    // would render local content in this sheet. Same gate as core/image RemoteImage;
    // anything else falls through to the existing fallback icon.
    val url = option.iconUrl?.takeIf { it.isNotBlank() && isNetworkImageUrl(it) }
    if (url == null) {
        DispositionIconFallback()
        return
    }
    // The Ktor-backed SingletonImageLoader is registered once at app bootstrap
    // (KmpBootstrap) — this composable only renders.
    SubcomposeAsyncImage(
        model = url,
        contentDescription = null,
        modifier = Modifier.size(40.dp),
        loading = { DispositionIconFallback() },
        error = { DispositionIconFallback() },
    )
}

/**
 * Icon shown while [SupportOption.iconUrl] is absent, still loading, or failed —
 * the Compose analogue of Dart's `Icons.support_agent` error fallback.
 */
@Composable
private fun DispositionIconFallback() {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(SnabbitTheme.colors.bgBrandSubtle),
        contentAlignment = Alignment.Center,
    ) {
        SnabbitIcon(
            name = SnabbitIconName.Phone,
            size = 20.dp,
            color = SnabbitTheme.colors.iconBrand,
        )
    }
}

/* ── Previews ────────────────────────────────────────────────────────── */

private val PREVIEW_OPTIONS = listOf(
    SupportOption(id = "location_access", label = "Location & Access"),
    SupportOption(id = "customer_availability", label = "Customer Availability"),
    SupportOption(id = "safety_emergency", label = "Safety & Emergency"),
    SupportOption(id = "service_scope", label = "Service Scope"),
)

@Preview
@Composable
private fun PreviewCallDispositionSheetContent() {
    SnabbitTheme {
        CallDispositionSheetContent(
            options = PREVIEW_OPTIONS,
            selectedId = "safety_emergency",
            isSubmitting = false,
            strings = DelayedCheckinStrings(),
            onSelect = {},
            onSubmitClick = {},
        )
    }
}

@Preview
@Composable
private fun PreviewCallDispositionSheetContentUnselected() {
    SnabbitTheme {
        CallDispositionSheetContent(
            options = PREVIEW_OPTIONS,
            selectedId = null,
            isSubmitting = false,
            strings = DelayedCheckinStrings(),
            onSelect = {},
            onSubmitClick = {},
        )
    }
}
