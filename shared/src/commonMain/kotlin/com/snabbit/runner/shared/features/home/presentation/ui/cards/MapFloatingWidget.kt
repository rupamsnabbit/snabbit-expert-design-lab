@file:Suppress("ForbiddenImport") // off-palette one-off inks (#303030, #FF99C8) — deliberately not tokenised (DS_GAPS.md §not-a-gap).

package com.snabbit.runner.shared.features.home.presentation.ui.cards

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitChip
import com.snabbit.design.atoms.SnabbitChipDisplay
import com.snabbit.design.atoms.SnabbitChipSize
import com.snabbit.design.atoms.SnabbitChipState
import com.snabbit.design.atoms.SnabbitChipVariant
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.home.domain.model.MapFloatingState
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheetCloseButton
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.hotspot_map_arrow
import com.snabbit.runner.shared.resources.logout_clock
import com.snabbit.runner.shared.resources.search_icon
import com.snabbit.runner.shared.resources.tiffin
import com.snabbit.runner.shared.resources.seva_marker
import androidx.compose.ui.layout.ContentScale
import org.jetbrains.compose.resources.painterResource

// TODO(PR #459 review, alkalox): this file is long — split the per-variant widgets
//  (Searching / Seva / LunchRequest / Lunch / Logout) into sibling files under
//  ui/cards/. Deferred to a follow-up so it doesn't churn line numbers under the
//  open review here.

/**
 * Floating widget that sits at the bottom of the map card — Figma DS
 * Expert-App-2.O 1582:7472 ("Map widget").
 *
 * Dispatcher composable: picks one of four private variant composables by
 * the [state] sealed type. New variants land here when the data layer ships
 * matching widget envelopes.
 *
 * Caller positions inside a `BoxScope` — e.g. inside
 * [com.snabbit.runner.shared.features.home.presentation.ui.cards.HotspotMapCard]:
 * `Modifier.align(Alignment.BottomCenter).padding(SnabbitTheme.spacing.`4`).fillMaxWidth()`.
 */
@Composable
fun MapFloatingWidget(
    state: MapFloatingState,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
    inFlight: HomeUiIntent? = null,
) {
    when (state) {
        MapFloatingState.SearchingForJobs ->
            SearchingForJobsWidget(strings = strings, modifier = modifier)
        is MapFloatingState.Seva ->
            SevaWidget(state = state, onIntent = onIntent, modifier = modifier)
        MapFloatingState.LunchRequest ->
            LunchRequestWidget(strings = strings, onIntent = onIntent, modifier = modifier)
        is MapFloatingState.Lunch ->
            LunchWidget(state = state, strings = strings, onIntent = onIntent, modifier = modifier)
        is MapFloatingState.Logout ->
            LogoutWidget(
                state = state,
                strings = strings,
                onIntent = onIntent,
                logoutLoading = inFlight == HomeUiIntent.TapLogout,
                modifier = modifier,
            )
    }
}

// ──────────────────────── Searching for jobs ────────────────────────

@Composable
private fun SearchingForJobsWidget(strings: HomeStrings, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.lg)
    // Simple shake-and-rest on the magnifying glass — small left-right
    // rotation for 400ms, then a still beat for 1100ms, then shake again.
    // No orbit / translation; just the wiggle.
    val shakeAngle by rememberInfiniteTransition(label = "search-shake")
        .animateFloat(
            initialValue = 0f,
            targetValue = 0f,
            animationSpec = infiniteRepeatable(
                animation = keyframes {
                    durationMillis = 1500
                    0f at 0 using FastOutSlowInEasing
                    -8f at 80 using FastOutSlowInEasing
                    8f at 180 using FastOutSlowInEasing
                    -5f at 280 using FastOutSlowInEasing
                    0f at 400
                    // 400 → 1500 ms: held still
                    0f at 1500
                },
                repeatMode = RepeatMode.Restart,
            ),
            label = "search-shake-angle",
        )
    // Pink shadow "breathing" — alpha pulses 0.45 ↔ 1.0 on a slower 1.6s
    // reverse loop. Gives the glow a living, fluid feel instead of a flat
    // halo. Independent transition from the icon scan so they don't beat
    // in lockstep (visually busier when the rhythms cross).
    val pulseAlpha by rememberInfiniteTransition(label = "shadow-pulse")
        .animateFloat(
            initialValue = 0.45f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 1600, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse,
            ),
            label = "shadow-pulse-alpha",
        )
    Box(modifier = modifier) {
        Row(
            modifier = Modifier
                .clip(shape)
                .background(SnabbitTheme.colors.bgPrimary, shape)
                // Figma 1582:7470 — `px-[20px] py-[16px]`.
                .padding(horizontal = SnabbitTheme.spacing.`6`, vertical = SnabbitTheme.spacing.componentPaddingMd)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SnabbitText(
                text = strings.mapWidgetSearchingForJobs,
                variant = SnabbitTextVariant.BodyLg,
                // Figma 1582:7163 — Body-L/16-Semibold (16px size, 24px
                // line-height, weight 600, gray-900).
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textPrimary,
                modifier = Modifier.weight(1f, fill = false),
            )
            // Figma 1582:7164 — 40×40 asset ("Search_Dhruval"), drawn at 44dp
            // to visually match the Flutter side. `graphicsLayer`
            // rotates the magnifying glass in-place during the shake burst;
            // holds at 0° during the rest beat. Asset is already duotone
            // pink — no tint needed.
            SnabbitImage(
                painter = painterResource(Res.drawable.search_icon),
                contentDescription = null,
                modifier = Modifier
                    .size(44.dp)
                    .graphicsLayer { rotationZ = shakeAngle },
                contentScale = ContentScale.Fit,
            )
        }
        // Figma 1582:7165 — 2px pink-300 border with a 4px blur. The border
        // alpha pulses (0.45 ↔ 1.0) on a slow reverse loop, giving the glow
        // a fluid breathing motion. Rendered ON TOP of the white pill so
        // the inside half of the blurred line reads as a soft inset glow.
        // Clipped to `shape` (not Unbounded) so the blur stays WITHIN the
        // card — the outward halo read as a glow around the card, not on it.
        Box(
            modifier = Modifier
                .matchParentSize()
                .blur(radius = 4.dp, edgeTreatment = BlurredEdgeTreatment(shape))
                .border(width = 2.dp, color = PINK_300.copy(alpha = pulseAlpha), shape = shape),
        )
    }
}

// ──────────────────────── Seva (job assigned) ────────────────────────

@Composable
private fun SevaWidget(
    state: MapFloatingState.Seva,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
) {
    // Figma 969:56728 — 16dp corner, 1dp gray-200 border, 12dp padding.
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    Row(
        modifier = modifier
            .clip(shape)
            .background(SnabbitTheme.colors.bgPrimary, shape)
            .border(width = 1.dp, color = SnabbitTheme.colors.borderDefault, shape = shape)
            .clickable { onIntent(HomeUiIntent.NavigateSeva(state.lat, state.lng)) }
            .padding(SnabbitTheme.spacing.`4`),
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Figma 969:56730 — 40dp white circle with a 1dp gray-200 border and
        // the pink seva marker asset centred inside.
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(SnabbitTheme.colors.bgPrimary)
                .border(width = 1.dp, color = SnabbitTheme.colors.borderDefault, shape = CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitImage(
                painter = painterResource(Res.drawable.seva_marker),
                contentDescription = null,
                modifier = Modifier.size(24.dp),
            )
        }
        // Middle column takes the remaining width so the pink navigation
        // button on the right stays anchored. `weight(1f)` also caps the
        // name row so a long name truncates instead of pushing the chip
        // off-screen.
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`1`),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Name hugs its content (`weight(1f, fill = false)`) but
                // yields first if space is tight so the "Seva" chip stays
                // fully visible.
                SnabbitText(
                    // UAT: names arrive lowercased from the API — title-case each word.
                    text = state.customerName.split(' ')
                        .joinToString(" ") { it.replaceFirstChar(Char::uppercase) },
                    variant = SnabbitTextVariant.BodyLg,
                    fontWeight = FontWeight.SemiBold,
                    color = BLACK_PRIMARY,
                    maxLines = 1,
                    modifier = Modifier.weight(1f, fill = false),
                )
                // Figma 969:56749 — dark gray-700 pill, 12sp Medium white
                // text, 8×2 padding, 40dp corner.
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(SnabbitTheme.borderRadius.full))
                        .background(SnabbitColorsLight.gray700)
                        .padding(horizontal = SnabbitTheme.spacing.componentPaddingSm, vertical = SnabbitTheme.spacing.`1`),
                ) {
                    SnabbitText(
                        text = state.tagLabel,
                        variant = SnabbitTextVariant.Caption,
                        fontWeight = FontWeight.Medium,
                        color = SnabbitTheme.colors.textInverse,
                    )
                }
            }
            if (state.distanceLabel.isNotEmpty()) {
                SnabbitText(
                    text = state.distanceLabel,
                    variant = SnabbitTextVariant.Caption,
                    fontWeight = FontWeight.Medium,
                    color = SnabbitTheme.colors.textBrand,
                )
            }
        }
        // Figma 969:56754 — pink-50 rounded 9.75dp button holding the
        // directions arrow (Res.drawable.hotspot_map_arrow). Own tap
        // target for the maps hand-off. `SnabbitIconName.Navigation`
        // renders blank in the current DS so we fall back to the DS asset.
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(SnabbitTheme.borderRadius.md))
                .background(SnabbitTheme.colors.bgBrandSubtle)
                .clickable { onIntent(HomeUiIntent.NavigateSeva(state.lat, state.lng)) }
                .padding(14.dp),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitImage(
                painter = painterResource(Res.drawable.hotspot_map_arrow),
                contentDescription = null,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

// ──────────────────────── Lunch request ────────────────────────

@Composable
private fun LunchRequestWidget(
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    Row(
        modifier = modifier
            .clip(shape)
            .background(SnabbitTheme.colors.bgPrimary, shape)
            .padding(start = SnabbitTheme.spacing.componentPaddingMd, end = SnabbitTheme.spacing.componentPaddingSm, top = SnabbitTheme.spacing.componentPaddingSm, bottom = SnabbitTheme.spacing.componentPaddingSm),
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Tiffin illustration — same asset as LunchActiveCard header.
        SnabbitImage(
            painter = painterResource(Res.drawable.tiffin),
            contentDescription = null,
            modifier = Modifier.size(36.dp),
            contentScale = ContentScale.Fit,
        )
        SnabbitText(
            text = strings.mapWidgetLunchTime,
            variant = SnabbitTextVariant.BodyMd,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textPrimary,
            modifier = Modifier.weight(1f),
        )
        TakeBreakChip(onIntent = onIntent)
    }
}

/** Pink chip on the lunch map pill — taps re-open the LunchRequest confirm
 *  sheet (the auto-open via `observeLunchRequestSheet` only fires once per
 *  phase entry; this gives the runner a way back in plus an explicit
 *  affordance during LUNCH_COOLDOWN). */
@Composable
private fun TakeBreakChip(onIntent: (HomeUiIntent) -> Unit) {
    // ponytail: kept hand-rolled rather than swapped to SnabbitButton — its
    // custom 12×8 padding / 10dp radius / 13sp label don't match any DS
    // button size cleanly. Colors + radius are tokenized; 13sp has no DS
    // variant so it stays a raw override (between Caption 12 and BodyMd 14).
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.md)
    Box(
        modifier = Modifier
            .clip(shape)
            .background(SnabbitTheme.colors.bgBrand, shape)
            .clickable { onIntent(HomeUiIntent.OpenLunchRequestSheet) }
            .padding(horizontal = SnabbitTheme.spacing.`4`, vertical = SnabbitTheme.spacing.componentPaddingSm),
    ) {
        SnabbitText(
            text = "Take break",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textInverse,
        )
    }
}

/**
 * Seva marker "helper" card (Figma 969:56727). Same card body as [SevaWidget]
 * with a small dark X pill above it that fires [HomeUiIntent.DismissSevaHelper].
 * Auto-dismiss (5s) is owned by [com.snabbit.runner.shared.features.home.presentation.HomeViewModel];
 * this composable is purely presentation.
 */
@Composable
fun SevaHelperCard(
    state: MapFloatingState.Seva,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
    ) {
        // UAT: same circular ✕ as the bottom sheets, at 24dp on the map.
        SnabbitBottomSheetCloseButton(
            onClickLabel = strings.mapWidgetDismissHelper,
            size = 24.dp,
        ) {
            onIntent(HomeUiIntent.DismissSevaHelper)
        }
        SevaWidget(
            state = state,
            onIntent = onIntent,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

// ──────────────────────── Lunch ────────────────────────

@Composable
private fun LunchWidget(
    state: MapFloatingState.Lunch,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    Row(
        modifier = modifier
            .clip(shape)
            .background(SnabbitTheme.colors.bgPrimary, shape)
            .padding(start = SnabbitTheme.spacing.componentPaddingMd, end = SnabbitTheme.spacing.componentPaddingSm, top = SnabbitTheme.spacing.componentPaddingSm, bottom = SnabbitTheme.spacing.componentPaddingSm),
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Tiffin illustration — same asset as the LunchActiveCard header and
        // the LunchRequest sheet. Used to read at 36dp.
        SnabbitImage(
            painter = painterResource(Res.drawable.tiffin),
            contentDescription = null,
            modifier = Modifier.size(36.dp),
            contentScale = ContentScale.Fit,
        )
        SnabbitText(
            text = strings.mapWidgetLunchInTemplate.replace("{time}", formatMmSs(state.remainingSeconds)),
            variant = SnabbitTextVariant.BodyMd,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textPrimary,
            modifier = Modifier.weight(1f),
        )
        TakeBreakChip(onIntent = onIntent)
    }
}

// ──────────────────────── Logout ────────────────────────

/**
 * Logout pill — Figma 1582:9128. White bg, 1.5dp gray-200 border, 16dp
 * radius, 12dp padding all, soft drop shadow. Left: 40dp gray-300 circle
 * avatar (placeholder) + 8dp gap + "Shift ends at {time}" text. Right:
 * pink Logout button with loading spinner when the intent is in flight.
 */
@Composable
private fun LogoutWidget(
    state: MapFloatingState.Logout,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    logoutLoading: Boolean,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    Row(
        modifier = modifier
            // Figma `drop-shadow-[0px_2px_4px_rgba(0,0,0,0.2)]`. Compose's
            // `shadow` paints a soft elevation behind the shape.
            .shadow(elevation = 4.dp, shape = shape)
            .clip(shape)
            .background(SnabbitTheme.colors.bgPrimary, shape)
            .border(1.5.dp, SnabbitTheme.colors.borderDefault, shape)
            .padding(SnabbitTheme.spacing.`4`),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier = Modifier.weight(1f),
            horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Figma 1157:51993 — pink shift clock with check badge on a
            // pale-pink disc (replaces the gray placeholder circle).
            SnabbitImage(
                painter = painterResource(Res.drawable.logout_clock),
                contentDescription = null,
                modifier = Modifier.size(40.dp),
                contentScale = ContentScale.Fit,
            )
            // Figma 1582:9124 — Outfit Medium 16sp gray-700 line-height 24sp.
            SnabbitText(
                text = strings.mapWidgetLogoutShiftEndsTemplate
                    .replace("{time}", state.shiftEndLabel),
                variant = SnabbitTextVariant.BodyLg,
                fontWeight = FontWeight.Medium,
                color = SnabbitTheme.colors.textBody,
            )
        }
        // Figma 1582:9125 — pink-600 button, 10dp radius, 20×12 padding,
        // "Logout" Outfit Semibold 16sp white line-height 24sp. Hand-rolled
        // because SnabbitButton's S size doesn't match these exact dims;
        // SnabbitButton.loading spinner replaces the text when in flight.
        // Dimmed + inert while `ctaEnabled` is false — the pre-logout
        // reminder window (shift end − 30 min, ECPO-819).
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(SnabbitTheme.borderRadius.md))
                .background(
                    if (state.ctaEnabled) SnabbitTheme.colors.bgBrand
                    else SnabbitTheme.colors.bgBrand.copy(alpha = 0.4f),
                )
                .clickable(enabled = state.ctaEnabled && !logoutLoading) { onIntent(HomeUiIntent.TapLogout) }
                .padding(horizontal = SnabbitTheme.spacing.`6`, vertical = SnabbitTheme.spacing.`4`),
            contentAlignment = Alignment.Center,
        ) {
            if (logoutLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = SnabbitTheme.colors.textInverse,
                    strokeWidth = 2.dp,
                )
            } else {
                SnabbitText(
                    text = strings.mapWidgetLogoutCta,
                    variant = SnabbitTextVariant.BodyLg,
                    fontWeight = FontWeight.SemiBold,
                    color = SnabbitTheme.colors.textInverse,
                )
            }
        }
    }
}

// ──────────────────────── shared shells ────────────────────────

/**
 * White rounded pill with the shared inner padding, gap, and shadow shape
 * the Searching / Seva / Logout variants all use. Lunch uses its own gradient
 * shell so it sits outside this helper.
 */
@Composable
private fun WhitePill(modifier: Modifier = Modifier, content: @Composable RowScope.() -> Unit) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    Row(
        modifier = modifier
            .clip(shape)
            .background(SnabbitTheme.colors.bgPrimary, shape)
            .padding(horizontal = SnabbitTheme.spacing.componentPaddingMd, vertical = SnabbitTheme.spacing.`4`),
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

// ponytail: two off-palette Figma hexes with no DS scale-shade equivalent —
// #303030 (customer-name ink, between DS gray800/gray900) and #FF99C8 (the
// glow border, brighter than DS pink300). Kept literal so the visual is
// exact; promote if the DS ever ships matching shades.
private val BLACK_PRIMARY = Color(0xFF303030)
private val PINK_300 = Color(0xFFFF99C8)
