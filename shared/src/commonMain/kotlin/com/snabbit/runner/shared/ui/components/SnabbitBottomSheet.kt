package com.snabbit.runner.shared.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetValue
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * SnabbitBottomSheet — a modal bottom sheet with a configurable header (image/icon + title),
 * a fully configurable content slot, and a configurable bottom action (footer) slot. A dark
 * circular close button can sit at the top of the sheet; it can be hidden.
 *
 * **Built on Material 3's [ModalBottomSheet].** M3 owns the modal window, the scrim, the
 * swipe/scrim/back dismissal, and — importantly — the keyboard (IME) handling, so the sheet
 * lifts itself above the on-screen keyboard without any manual `imePadding` math. This replaces
 * the previous hand-rolled `Dialog`-based implementation vendored from the design system (the DS
 * no longer ships this component). It lives here in `ui/components` alongside the other vendored
 * pieces (SnabbitEarningsAccordion, SnabbitNavigationCard, …).
 *
 * The dark close button *floats* in the scrim above the sheet body (per Figma): the M3 window is
 * made transparent + un-clipped (RectangleShape) and the visible gray-50 rounded-top card is drawn
 * inside the content, so the close button sits above the card against the scrim.
 *
 * Detekt: `containerColor` / `scrimColor` take design tokens (`SnabbitTheme.colors.*`), and the
 * scrim fallback references `Color` fully-qualified (see [SnabbitBottomSheetDefaults]), so nothing
 * here trips the `:shared` `ForbiddenImport` ban on `androidx.compose.ui.graphics.Color`.
 *
 * Figma: Shift — Job Lifecycle DS, nodes 4:9907 / 4:9159 / 10:8968.
 *
 * ```
 * var open by remember { mutableStateOf(false) }
 * if (open) {
 *     SnabbitBottomSheet(
 *         onDismissRequest = { open = false },
 *         title = "Enter OTP to start job",
 *         footer = { SnabbitButton(text = "Start Job", onClick = { /* … */ }, fullWidth = true) },
 *     ) {
 *         // any content
 *     }
 * }
 * ```
 *
 * @param onDismissRequest called when the sheet requests dismissal (close button, scrim tap,
 *   back press, or a swipe-down). The caller owns visibility.
 * @param title optional heading (H2/24) centered under the header image.
 * @param header optional slot above the title — an illustration / icon (e.g. `SnabbitIcon` or `Image`).
 * @param showCloseButton whether the dark close button is shown at the top of the sheet. Default `true`.
 * @param draggable when `true`, shows the M3 drag handle at the top of the sheet. Drag gestures on the
 *   sheet body are enabled when `draggable` **or** `dismissible` is true; a forced step (both false) is
 *   fully non-draggable — the body can't even be rubber-banded.
 * @param dismissible when `true`, swipe / scrim tap / device-back all dismiss the sheet; when `false`
 *   all three are blocked (a forced step) — including the device back button.
 * @param footer optional bottom action section (e.g. a button or button group).
 * @param content the main, fully configurable content area.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SnabbitBottomSheet(
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    title: String? = null,
    header: (@Composable () -> Unit)? = null,
    showCloseButton: Boolean = true,
    draggable: Boolean = true,
    dismissible: Boolean = true,
    footer: (@Composable () -> Unit)? = null,
    // Background of the visible sheet card. Defaults to the DS gray-50; pass e.g.
    // `SnabbitTheme.colors.bgPrimary` (white) for sheets whose content has its own white
    // backdrop (e.g. the loan illustrations). Color fully-qualified per the file's Color-import ban.
    containerColor: androidx.compose.ui.graphics.Color = SnabbitTheme.colors.bgSecondary,
    content: @Composable () -> Unit,
) {
    // `dismissible` may flip across recompositions (e.g. a sheet that locks itself while a submit
    // is in flight). rememberModalBottomSheetState captures its confirmValueChange lambda ONCE at
    // construction, so read the latest value through a State — otherwise the veto freezes at the
    // first-composition value and a later `dismissible = false` never engages the scrim block.
    val currentDismissible by rememberUpdatedState(dismissible)
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        // Block swipe-/scrim-to-hide when the caller marks the sheet non-dismissible; still allow
        // it to settle expanded. Scrim taps consult this (M3 gates animateToDismiss on it); the
        // device back button is handled by PlatformBackHandler below.
        confirmValueChange = { target -> currentDismissible || target != SheetValue.Hidden },
    )

    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        modifier = modifier,
        sheetState = sheetState,
        // Drag gestures are enabled only when the sheet is meant to move — draggable (has a handle) or
        // dismissible (swipe-to-dismiss). A forced step (both false, e.g. the post-checkout tasks sheet)
        // is fully non-draggable: without this, `confirmValueChange` blocks the sheet *settling* hidden
        // but the body still rubber-bands under a drag. Default (true) keeps normal sheets draggable.
        sheetGesturesEnabled = draggable || dismissible,
        // Transparent + un-clipped so the close button can FLOAT in the scrim above the sheet body
        // (per Figma). The visible gray-50 rounded-top card is drawn inside the content
        // (SnabbitBottomSheetContent), not by the M3 surface. Color/shape are fully-qualified to
        // avoid importing the `:shared`-banned androidx.compose.ui.graphics.Color.
        shape = androidx.compose.ui.graphics.RectangleShape,
        containerColor = androidx.compose.ui.graphics.Color.Transparent,
        scrimColor = SnabbitBottomSheetDefaults.ScrimColor,
        // No M3 grab handle in the window slot — the floating close button is the affordance
        // (Figma has no handle). A draggable sheet renders its handle inside the gray card instead.
        dragHandle = null,
    ) {
        // A non-dismissible (forced) sheet also swallows the device back button. M3's ModalBottomSheet
        // dismisses on back regardless of `confirmValueChange` (a programmatic hide bypasses it), so we
        // consume back here. Composed inside the sheet body, this handler outranks M3's internal one;
        // dismissible sheets keep enabled = false and fall through to M3's normal back-dismiss.
        PlatformBackHandler(enabled = !dismissible) { /* forced step — swallow back */ }
        SnabbitBottomSheetContent(
            title = title,
            header = header,
            showCloseButton = showCloseButton,
            draggable = draggable,
            onCloseClick = onDismissRequest,
            footer = footer,
            containerColor = containerColor,
            content = content,
        )
    }
}

/**
 * The padded sheet body: [close button?] → [header/title?] → [content] → [footer?]. Shared by the
 * real [ModalBottomSheet] content slot and the previews. Draws its own gray-50 rounded-top card
 * (the M3 window is transparent); the close button floats above it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SnabbitBottomSheetContent(
    title: String?,
    header: (@Composable () -> Unit)?,
    showCloseButton: Boolean,
    draggable: Boolean,
    onCloseClick: () -> Unit,
    footer: (@Composable () -> Unit)?,
    containerColor: androidx.compose.ui.graphics.Color = SnabbitTheme.colors.bgSecondary,
    content: @Composable () -> Unit,
) {
    // Outer stack: the floating close button, a 20dp gap (Figma), then the gray body card. No
    // background here — the M3 sheet surface is transparent, so the close button reads against the
    // scrim, exactly like the design.
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        if (showCloseButton) {
            SnabbitBottomSheetCloseButton(onClick = onCloseClick)
        }

        // The visible sheet: a gray-50 card with rounded top corners (its bottom sits at the screen
        // edge). It supplies its own background + shape now that the M3 surface is transparent.
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
                .background(containerColor)
                // 32dp top matches the Figma no-handle spec; less when a drag handle takes the top.
                .padding(
                    start = 16.dp,
                    end = 16.dp,
                    top = if (draggable) 12.dp else 32.dp,
                    bottom = 40.dp,
                ),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            if (draggable) {
                BottomSheetDefaults.DragHandle()
            }

            if (header != null || title != null) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    header?.invoke()
                    if (title != null) {
                        SnabbitText(
                            text = title,
                            variant = SnabbitTextVariant.Heading2,
                            color = SnabbitTheme.colors.textPrimary,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
            }

            Box(Modifier.fillMaxWidth()) { content() }

            if (footer != null) {
                Box(Modifier.fillMaxWidth()) { footer() }
            }
        }
    }
}

/** The circular ✕ used by [SnabbitBottomSheet]; also reused by floating overlays that need the same glyph. */
@Composable
internal fun SnabbitBottomSheetCloseButton(
    onClickLabel: String? = null,
    size: Dp = 40.dp,
    /**
     * Minimum hit area, kept independent of the visual [size] so the control can shrink
     * below the 48dp Android touch-target minimum without becoming hard to hit — the map
     * widget renders this at 24dp over a map, where a mis-tap pans the map instead.
     * Matches `SEVA_TOUCH_TARGET_DP` on the same screen.
     */
    touchTargetSize: Dp = 48.dp,
    onClick: () -> Unit,
) {
    // Outer box owns the hit area + semantics; the inner one is the visual circle. The
    // click deliberately sits out here so the target can exceed what's drawn.
    Box(
        modifier = Modifier
            .sizeIn(minWidth = touchTargetSize, minHeight = touchTargetSize)
            .clip(CircleShape)
            .clickable(onClickLabel = onClickLabel, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            // Fixed square box: the glyph's intrinsic size isn't square, so wrap-content
            // + CircleShape renders as an ellipse. Sizing first keeps it a true circle.
            modifier = Modifier
                .size(size)
                .clip(CircleShape)
                .background(SnabbitTheme.colors.bgInverse),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitIcon(
                name = SnabbitIconName.Close,
                // Half the box, matching the sheet's original 40dp/20dp ratio.
                size = size / 2,
                color = SnabbitTheme.colors.iconInverse,
                contentDescription = "Close",
            )
        }
    }
}

/** Shared defaults for [SnabbitBottomSheet]. */
object SnabbitBottomSheetDefaults {
    /**
     * Scrim drawn behind the sheet. Standard 40%-black overlay (no semantic scrim token exists yet).
     * `Color` is fully-qualified rather than imported so the `:shared` detekt `ForbiddenImport`
     * rule (which bans `import androidx.compose.ui.graphics.Color`) does not fire.
     */
    val ScrimColor = androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.4f)
}

// ── Previews ──────────────────────────────────────────────────────────────
// The previews render the sheet body inside a plain gray-50 surface (the modal scaffold minus the
// ModalBottomSheet window/scrim) so they draw in the IDE. Real usage goes through SnabbitBottomSheet.

@Preview
@Composable
private fun PreviewSnabbitBottomSheetWithHeaderAndFooter() {
    SnabbitTheme {
        PreviewSheetSurface {
            SnabbitBottomSheetContent(
                title = "Job Started",
                header = {
                    Box(
                        Modifier.size(60.dp).clip(CircleShape).background(SnabbitTheme.colors.bgSuccess),
                        contentAlignment = Alignment.Center,
                    ) { SnabbitIcon(SnabbitIconName.Check, size = 32.dp, color = SnabbitTheme.colors.iconInverse) }
                },
                showCloseButton = true,
                draggable = false,
                onCloseClick = {},
                footer = {
                    Box(
                        Modifier.fillMaxWidth().height(56.dp).clip(RoundedCornerShape(12.dp))
                            .background(SnabbitTheme.colors.bgBrand),
                        contentAlignment = Alignment.Center,
                    ) { SnabbitText("Okay", color = SnabbitTheme.colors.textInverse, variant = SnabbitTextVariant.BodyMd) }
                },
                content = {
                    Box(
                        Modifier.fillMaxWidth().height(180.dp).clip(RoundedCornerShape(12.dp))
                            .background(SnabbitTheme.colors.bgTertiary),
                    )
                },
            )
        }
    }
}

@Preview
@Composable
private fun PreviewSnabbitBottomSheetTitleOnly() {
    SnabbitTheme {
        PreviewSheetSurface {
            SnabbitBottomSheetContent(
                title = "Enter OTP to start job",
                header = null,
                showCloseButton = true,
                draggable = false,
                onCloseClick = {},
                footer = null,
                content = {
                    SnabbitText(
                        "Please ask the customer to share the OTP with you",
                        variant = SnabbitTextVariant.BodyMd,
                        color = SnabbitTheme.colors.textSecondary,
                        textAlign = TextAlign.Center,
                    )
                },
            )
        }
    }
}

/**
 * Dark scrim backdrop that stands in for the M3 modal scrim in previews, so the floating close
 * button reads like production. The gray-50 card is now drawn by [SnabbitBottomSheetContent]
 * itself, so this only supplies the scrim plus a little headroom above the sheet.
 */
@Composable
private fun PreviewSheetSurface(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(SnabbitBottomSheetDefaults.ScrimColor)
            .padding(top = 40.dp),
        contentAlignment = Alignment.BottomCenter,
    ) {
        content()
    }
}
