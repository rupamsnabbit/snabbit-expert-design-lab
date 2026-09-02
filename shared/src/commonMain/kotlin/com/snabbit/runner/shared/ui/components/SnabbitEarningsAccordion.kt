package com.snabbit.runner.shared.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.invalidateDraw
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitDivider
import com.snabbit.design.atoms.SnabbitDividerType
import com.snabbit.design.atoms.SnabbitListDensity
import com.snabbit.design.atoms.SnabbitListItem
import com.snabbit.design.atoms.SnabbitListValue
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitValueState
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.image.RemoteImage
import com.snabbit.runner.shared.ui.icons.AppIcons
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * SnabbitEarningsAccordion — earnings / payout-breakdown card (Expert App component).
 *
 * App-specific composition. Figma: "Earnings Card" component set (Expert App DS,
 * node 1491:14507). One configurable component that takes the shape of every state
 * in that set:
 *
 * | Figma state       | How to produce it                                              |
 * |-------------------|----------------------------------------------------------------|
 * | Expanded          | default (`collapsible=false` or expanded)                      |
 * | Long distance     | one extra [SnabbitEarningsItem] in [items]                     |
 * | Earnings change   | [originalAmount] (struck total) + a [SnabbitEarningsItem.valueLost] row |
 * | Collapsed         | `collapsible=true`, collapsed, with a [collapsedSummary]        |
 * | State4 (discount) | `collapsible=true`, collapsed, [originalAmount], no summary     |
 *
 * The **single-row** "YOU EARN" bar (Figma "Frame 2147242617") is [SnabbitEarningsSummaryBar]
 * — a structurally distinct minimal layout (no breakdown / chevron), so it's a sibling
 * rather than a branch here.
 *
 * **Expanded** is a white card with a centered headline ([SnabbitMetricCard], with an
 * optional struck [originalAmount]) over a notched DS [SnabbitDivider], then breakdown
 * rows ([SnabbitListItem] + [SnabbitListValue]) separated by dotted dividers. One row can
 * be [SnabbitEarningsItem.highlighted] (full-bleed `bg.info` band + shimmer), a label can
 * carry an inline [SnabbitEarningsItem.accent], and a value can be
 * [SnabbitEarningsItem.valueLost] (greyed `text.disabled` — a forfeited line).
 *
 * **Collapsed** ([collapsible] + not expanded) is a compact row: title + amount (+ struck
 * [originalAmount]) on the left, and on the right a chevron over an optional
 * [collapsedSummary] (a base+bonus split and a check-in pill). Toggling morphs between the
 * two layouts via [AnimatedContent]; controlled ([expanded] + [onExpandedChange]) and
 * uncontrolled ([initialExpanded]) usage are both supported.
 */

data class SnabbitEarningsItem(
    val label: String,
    val value: String,
    /** Inline `text.info` accent after the label (e.g. a check-in time "7:45 PM"). */
    val accent: String? = null,
    /** Full-bleed `bg.info` band + shimmer (the highlighted check-in bonus row). */
    val highlighted: Boolean = false,
    /**
     * Renders the value greyed (`text.disabled`) — a forfeited/lost line (the "Earnings
     * change" state, where the check-in bonus was missed). Typically paired with
     * `highlighted = false` (the band is dropped when the bonus is lost).
     */
    val valueLost: Boolean = false,
    /**
     * Duration shown inline after the label as " (<durationText>)" in the label's own style
     * (backend `pill_text`, e.g. "1 hr" → "Work (1 hr)"). Matches the Figma earnings card, which
     * folds the duration into the label text rather than a pill. Shown when non-blank.
     */
    val durationText: String? = null,
    /** Server icon rendered inline between the label and the duration (backend `icon_url`, e.g. the monsoon-bonus glyph). Shown when non-blank. */
    val iconUrl: String? = null,
    /** Optional second line beneath the label (backend `subtitle`). Shown when non-blank. */
    val subtitle: String? = null,
)

/**
 * Stable, [Immutable] wrapper around the [SnabbitEarningsItem] breakdown list. A bare
 * `List<SnabbitEarningsItem>` is an *unstable* Compose parameter, so passing one straight into
 * [SnabbitEarningsAccordion] stops it from skipping and forces a recompose on every parent tick;
 * wrapping the list in this `@Immutable` type marks it stable and restores skipping. Built by the
 * `earningsItems(...)` mapper the four job screens share.
 */
@Immutable
data class SnabbitEarningsItems(val items: List<SnabbitEarningsItem>)

/**
 * Right-side content of the **collapsed** header (Figma "Collapsed", node 1491:14506):
 * a `base + bonus` split ([baseAmount] muted, [bonusAmount] in `text.info`) and a
 * check-in [pillText] pill. Omit (null) for the plain discounted-collapsed state.
 */
data class EarningsCollapsedSummary(
    val baseAmount: String,
    val bonusAmount: String,
    val pillText: String,
)

/**
 * Shimmer config for the highlighted earnings row (Figma node 1678-6891): a
 * translucent highlight that sweeps **left → right** across the blue band. Fully
 * tunable — [highlightColor], [durationMillis] (one sweep), [enabled].
 *
 * The DS has no shimmer primitive yet, so this is an app-level effect (this file is
 * already an app composition, not a DS atom). If a `SnabbitShimmer` lands in the
 * design system, delegate to it here.
 */
data class EarningsShimmerSpec(
    val highlightColor: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.5f),
    val durationMillis: Int = 2400,
    val enabled: Boolean = true,
)

private val CardShape = RoundedCornerShape(12.dp)
private val PillShape = RoundedCornerShape(20.dp)

/** Fraction of the row width spanned by the shimmer highlight band. */
private const val SHIMMER_BAND_FRACTION = 0.22f

@Composable
fun SnabbitEarningsAccordion(
    title: String,
    amount: String,
    items: SnabbitEarningsItems,
    modifier: Modifier = Modifier,
    originalAmount: String? = null,
    collapsible: Boolean = false,
    expanded: Boolean? = null,
    initialExpanded: Boolean = true,
    onExpandedChange: ((Boolean) -> Unit)? = null,
    collapsedSummary: EarningsCollapsedSummary? = null,
    shimmer: EarningsShimmerSpec = EarningsShimmerSpec(),
    /** Headline amount color; [Color.Unspecified] → `text.primary` (default). Completed passes green-600. */
    amountColor: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Unspecified,
    /** Highlighted (check-in bonus) row band color; [Color.Unspecified] → `bg.info` (default). Completed passes green-50. */
    highlightColor: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Unspecified,
) {
    val isControlled = expanded != null
    var uncontrolled by remember { mutableStateOf(initialExpanded) }
    val isExpanded = when {
        !collapsible -> true
        isControlled -> expanded == true
        else -> uncontrolled
    }
    val latestOnChange by rememberUpdatedState(onExpandedChange)
    val toggle: () -> Unit = {
        val next = !isExpanded
        if (!isControlled) uncontrolled = next
        latestOnChange?.invoke(next)
    }

    // Non-collapsible: always the full expanded card, no chevron (e.g. the overlay).
    if (!collapsible) {
        ExpandedEarningsCard(title, amount, originalAmount, items.items, shimmer, amountColor = amountColor, highlightColor = highlightColor, onToggle = null, modifier = modifier)
        return
    }

    // Collapsible: morph between the compact and full layouts. AnimatedContent animates
    // the (large) height difference and cross-fades the content.
    AnimatedContent(
        targetState = isExpanded,
        transitionSpec = { fadeIn(tween(180)) togetherWith fadeOut(tween(120)) },
        modifier = modifier,
        label = "SnabbitEarningsAccordion",
    ) { expandedNow ->
        if (expandedNow) {
            ExpandedEarningsCard(title, amount, originalAmount, items.items, shimmer, amountColor = amountColor, highlightColor = highlightColor, onToggle = toggle)
        } else {
            CollapsedEarningsCard(title, amount, originalAmount, collapsedSummary, onToggle = toggle)
        }
    }
}

/**
 * The single-row **"YOU EARN ₹145"** summary bar (Figma "Frame 2147242617", node
 * 1572:8182) — a caption on the left, a bold value on the right, no breakdown/chevron.
 * A `border.default` (vs the card's `border.subtle`) rounded bar.
 */
@Composable
fun SnabbitEarningsSummaryBar(
    caption: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(SnabbitTheme.colors.bgPrimary, CardShape)
            .border(1.dp, SnabbitTheme.colors.borderDefault, CardShape)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SnabbitText(
            text = caption,
            color = SnabbitTheme.colors.textSecondary,
            fontSize = 12.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.Medium,
        )
        SnabbitText(
            text = value,
            color = SnabbitTheme.colors.textBody,
            fontSize = 20.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
private fun ExpandedEarningsCard(
    title: String,
    amount: String,
    originalAmount: String?,
    items: List<SnabbitEarningsItem>,
    shimmer: EarningsShimmerSpec,
    amountColor: androidx.compose.ui.graphics.Color,
    highlightColor: androidx.compose.ui.graphics.Color,
    onToggle: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    // Custom container (not DS SnabbitCard): the highlighted row needs a
    // full-bleed bg band, which a padded SnabbitCard would inset.
    // A highlighted last row carries that band; let it bleed to the card's bottom edge
    // (clipped to the rounded corners) rather than leaving an awkward white gap beneath
    // it. Plain last rows keep the normal bottom padding.
    val lastRowHighlighted = items.lastOrNull()?.highlighted == true
    Column(
        // Top padding lives on the headline Box below (so the tap tile reaches the card's top
        // edge); the Column keeps only the bottom safe-area.
        modifier = modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(SnabbitTheme.colors.bgPrimary, CardShape)
            .border(1.dp, SnabbitTheme.colors.borderSubtle, CardShape)
            .padding(bottom = if (lastRowHighlighted) 0.dp else 16.dp),
    ) {
        // Headline (title + amount, optional struck original) with the chevron indicator. When the
        // card is toggleable the WHOLE header block is the tap-to-collapse tile: clickable spans the
        // full width from the card's top edge (the 16dp top padding moved here off the Column) down
        // to just above the notched divider — the breakdown rows below stay non-tappable. Placing
        // clickable before the padding makes the hit area + ripple fill the block (ripple clipped to
        // the card's rounded corners by the Column's clip above).
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (onToggle != null) {
                        Modifier.clickable(role = Role.Button, onClickLabel = "Collapse", onClick = onToggle)
                    } else {
                        Modifier
                    },
                )
                .padding(top = 16.dp, start = 16.dp, end = 16.dp),
        ) {
            SnabbitMetricCard(
                caption = title,
                value = amount,
                struckValue = originalAmount,
                size = SnabbitMetricCardSize.Lg,
                valueColor = amountColor,
                modifier = Modifier.fillMaxWidth(),
            )
            if (onToggle != null) {
                EarningsChevron(
                    expanded = true,
                    modifier = Modifier.align(Alignment.TopEnd),
                )
            }
        }

        // Notched DS divider beneath the amount.
        SnabbitDivider(
            type = SnabbitDividerType.Notched,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
        )

        // Breakdown list — DS SnabbitListItem rows + dotted DS dividers.
        Column(modifier = Modifier.fillMaxWidth()) {
            items.forEachIndexed { index, item ->
                if (index > 0) {
                    // Dotted separator between two plain rows; a highlighted row's band
                    // provides its own separation, so skip there.
                    val adjacentHighlight = item.highlighted || items[index - 1].highlighted
                    if (adjacentHighlight) {
                        Spacer(Modifier.height(10.dp))
                    } else {
                        SnabbitDivider(
                            type = SnabbitDividerType.Dotted,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                        )
                    }
                }
                EarningsListItem(
                    item,
                    shimmer,
                    highlightColor,
                    bleedsToBottom = index == items.lastIndex && item.highlighted,
                )
            }
        }
    }
}

@Composable
private fun CollapsedEarningsCard(
    title: String,
    amount: String,
    originalAmount: String?,
    summary: EarningsCollapsedSummary?,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        // The whole collapsed tile is the tap target (the ripple fills the card, clipped to its
        // rounded shape) — clickable sits after the clip so the ripple is bounded, and before the
        // padding so the hit area covers the full card, not just the padded interior.
        modifier = modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(SnabbitTheme.colors.bgPrimary, CardShape)
            .border(1.dp, SnabbitTheme.colors.borderSubtle, CardShape)
            .clickable(role = Role.Button, onClickLabel = "Expand", onClick = onToggle)
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        // Top-aligned so the chevron sits at the top-right (matching the design, where the
        // summary — visible or not — reserves the space beneath it).
        verticalAlignment = Alignment.Top,
    ) {
        // Left — title over amount (+ optional struck original).
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(1.dp),
        ) {
            SnabbitText(
                text = title,
                color = SnabbitTheme.colors.textSecondary,
                fontSize = 14.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Medium,
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                SnabbitText(
                    text = amount,
                    color = SnabbitTheme.colors.textPrimary,
                    fontSize = 20.sp,
                    lineHeight = 26.sp,
                    fontWeight = FontWeight.Bold,
                )
                if (originalAmount != null) {
                    SnabbitText(
                        text = originalAmount,
                        color = SnabbitTheme.colors.textTertiary,
                        fontSize = 14.sp,
                        lineHeight = 20.sp,
                        fontWeight = FontWeight.Medium,
                        textDecoration = TextDecoration.LineThrough,
                    )
                }
            }
        }

        // Right — chevron over the optional base+bonus summary + check-in pill.
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            EarningsChevron(expanded = false)
            if (summary != null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        SnabbitText(
                            text = "${summary.baseAmount} + ",
                            color = SnabbitTheme.colors.textTertiary,
                            fontSize = 14.sp,
                            lineHeight = 20.sp,
                            fontWeight = FontWeight.Medium,
                        )
                        SnabbitText(
                            text = summary.bonusAmount,
                            color = SnabbitTheme.colors.textInfo,
                            fontSize = 14.sp,
                            lineHeight = 20.sp,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                    EarningsCheckInPill(summary.pillText)
                }
            }
        }
    }
}

/**
 * The chevron glyph ([AppIcons.ChevronUp] when expanded, down when collapsed) — a **decorative
 * indicator only**. The tap-to-toggle now lives on the whole tile (the collapsed [Row] /
 * expanded header [Box] own the `clickable` + `Role.Button`), so this glyph carries no click of
 * its own and no `contentDescription` (the container announces the expand/collapse action).
 * Rendered via [Image] at its natural 14×8 (the DS `SnabbitIcon` forces a square box, which would
 * stretch this wide-and-flat chevron); the gray-400 fill is baked into the vector. The 6dp padding
 * keeps its visual size/position unchanged from when it owned the hit area.
 */
@Composable
private fun EarningsChevron(
    expanded: Boolean,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier.padding(6.dp),
        contentAlignment = Alignment.Center,
    ) {
        Image(
            imageVector = if (expanded) AppIcons.ChevronUp else AppIcons.ChevronDown,
            contentDescription = null,
            modifier = Modifier.width(14.dp).height(8.dp),
        )
    }
}

/** The "Check In by …" pill on the collapsed header — `bg.info` fill, blue-100 border. */
@Composable
private fun EarningsCheckInPill(text: String) {
    Box(
        modifier = Modifier
            .clip(PillShape)
            .background(SnabbitTheme.colors.bgInfo, PillShape)
            // No semantic blue-100 border token exists; use the DS palette (light-only,
            // as is this app) rather than a raw Color literal.
            .border(1.dp, SnabbitColorsLight.blue100, PillShape)
            .padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
        SnabbitText(
            text = text,
            color = SnabbitTheme.colors.textInfo,
            fontSize = 10.sp,
            lineHeight = 14.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun EarningsListItem(
    item: SnabbitEarningsItem,
    shimmer: EarningsShimmerSpec,
    highlightColor: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Unspecified,
    /**
     * True when this highlighted band is the last row, so it bleeds to the card's bottom
     * edge (the card drops its own bottom padding there). The band then carries the card's
     * 16.dp bottom safe-area itself — balancing the 16.dp above the headline — instead of
     * its mid-band 10.dp. Only meaningful for a highlighted row.
     */
    bleedsToBottom: Boolean = false,
) {
    // Highlighted-row band: caller override (Completed → green-50) else the default blue bg.info.
    val band = if (highlightColor != androidx.compose.ui.graphics.Color.Unspecified) highlightColor else SnabbitTheme.colors.bgInfo
    val rowModifier = if (item.highlighted) {
        Modifier
            .fillMaxWidth()
            .background(band)
            .earningsShimmer(shimmer)
            .padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = if (bleedsToBottom) 16.dp else 10.dp)
    } else {
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    }

    // Slot mode: the secondary-gray label + inline info accent are app-specific
    // styling, so they go in SnabbitListItem's `content` slot (no DS change needed).
    SnabbitListItem(
        titleContent = {
            // Label (+ optional server icon / duration pill trailing it) over an optional
            // subtitle line — Flutter `_PayoutRow` parity (`[label] [icon_url] [pill_text]`,
            // subtitle beneath), styled with DS tokens.
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    SnabbitText(
                        text = item.label,
                        // Weighted + ellipsised (Flutter uses maxLines 2) so a long label
                        // shrinks rather than pushing the icon/pill off the row.
                        modifier = Modifier.weight(1f, fill = false),
                        color = SnabbitTheme.colors.textSecondary,
                        fontSize = 14.sp,
                        lineHeight = 20.sp,
                        fontWeight = FontWeight.Normal,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (item.accent != null) {
                        SnabbitText(
                            text = item.accent,
                            color = SnabbitTheme.colors.textInfo,
                            fontSize = 14.sp,
                            lineHeight = 20.sp,
                            fontWeight = FontWeight.Normal,
                        )
                    }
                    // Server icon (backend `icon_url`, e.g. the monsoon-bonus glyph) inline between
                    // the label and the duration — the Figma "<name> ☀️ (<duration>)" layout, where
                    // the mockup's emoji is our server image. RemoteImage draws nothing on blank URL /
                    // load failure, so an absent or broken icon collapses cleanly.
                    if (!item.iconUrl.isNullOrBlank()) {
                        RemoteImage(
                            url = item.iconUrl,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                            contentScale = ContentScale.Fit,
                        )
                    }
                    // Duration as parenthetical text in the label's own style (NOT a pill) — the
                    // Figma earnings card folds it into the label, e.g. "Work (1 hr)".
                    item.durationText?.takeIf { it.isNotBlank() }?.let { duration ->
                        SnabbitText(
                            text = "($duration)",
                            color = SnabbitTheme.colors.textSecondary,
                            fontSize = 14.sp,
                            lineHeight = 20.sp,
                            fontWeight = FontWeight.Normal,
                        )
                    }
                }
                if (!item.subtitle.isNullOrBlank()) {
                    SnabbitText(
                        text = item.subtitle,
                        modifier = Modifier.fillMaxWidth(),
                        color = SnabbitTheme.colors.textSecondary,
                        fontSize = 12.sp,
                        lineHeight = 16.sp,
                        fontWeight = FontWeight.Normal,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        },
        modifier = rowModifier,
        density = SnabbitListDensity.Compact,
        trailingContent = {
            SnabbitListValue(
                value = item.value,
                density = SnabbitListDensity.Compact,
                // A forfeited line renders greyed (text.disabled) — the "Earnings change" state.
                state = if (item.valueLost) SnabbitValueState.Disabled else SnabbitValueState.Visible,
            )
        },
    )
}

/**
 * Animated diagonal shimmer — a wide + thin translucent bar (per the Figma skew)
 * sweeping **left → right** over the row, drawn over the band background but beneath
 * the content (stack: band → shimmer → text). Loops every [EarningsShimmerSpec.durationMillis];
 * no-op when disabled.
 *
 * Backed by a [DrawModifierNode] (not the soft-deprecated `composed { }`): the constant gradient
 * colour stops are hoisted onto the node and reused, so only the animated sweep [Offset]s — and the
 * [Brush] built from them — are rebuilt per frame. The sweep is self-driven by an [Animatable] on
 * the node's own coroutine scope, so no composition-scoped state is needed and the modifier stays
 * skippable/poolable.
 */
private fun Modifier.earningsShimmer(spec: EarningsShimmerSpec): Modifier =
    if (!spec.enabled) this else this then EarningsShimmerElement(spec)

private data class EarningsShimmerElement(
    val spec: EarningsShimmerSpec,
) : ModifierNodeElement<EarningsShimmerNode>() {
    override fun create(): EarningsShimmerNode = EarningsShimmerNode(spec)

    override fun update(node: EarningsShimmerNode) {
        node.update(spec)
    }
}

private class EarningsShimmerNode(
    private var spec: EarningsShimmerSpec,
) : Modifier.Node(), DrawModifierNode {

    // Sweep 0f→1f, read in draw() so each animation step invalidates the draw phase.
    private val progress = Animatable(0f)

    // Constant colour stops, hoisted off the per-frame draw path; rebuilt only when the spec changes.
    private var colorStops = spec.toColorStops()

    private var sweepJob: Job? = null

    override fun onAttach() {
        startSweep()
    }

    fun update(newSpec: EarningsShimmerSpec) {
        val durationChanged = newSpec.durationMillis != spec.durationMillis
        spec = newSpec
        colorStops = newSpec.toColorStops()
        // A colour-only change keeps the sweep running; only a new duration restarts it.
        if (durationChanged) startSweep()
        invalidateDraw()
    }

    private fun startSweep() {
        sweepJob?.cancel()
        sweepJob = coroutineScope.launch {
            progress.snapTo(0f)
            progress.animateTo(
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(spec.durationMillis, easing = LinearEasing),
                    repeatMode = RepeatMode.Restart,
                ),
            )
        }
    }

    override fun ContentDrawScope.draw() {
        val band = size.width * SHIMMER_BAND_FRACTION
        val slant = size.height // the top edge leads the bottom → diagonal sweep
        val travel = size.width + band + slant
        val x = -band - slant + travel * progress.value
        drawRect(
            brush = Brush.linearGradient(
                colorStops = colorStops,
                start = Offset(x, 0f),
                end = Offset(x + band + slant, size.height),
            ),
            size = size,
        )
        drawContent()
    }
}

/**
 * The constant shimmer colour stops — two **solid** diagonal bars matching Figma node 2877:53283:
 * a WIDE bar leading a much thinner TRAILING one (~4.2:1, per the spec's 12.17px vs 2.87px), both
 * flat white at the spec's [EarningsShimmerSpec.highlightColor] 0.5 opacity (Figma gives both bars
 * the same opacity). Near-crisp edges (tiny 0.005 AA ramps) so they read as solid rectangles, not
 * the soft transparent→white→transparent tent-glints the old stops produced. Ordered wide-then-thin
 * so the pair sweeps left→right like the Figma layout. Built once off the draw path.
 */
private fun EarningsShimmerSpec.toColorStops(): Array<Pair<Float, androidx.compose.ui.graphics.Color>> {
    val bar = highlightColor
    val clear = androidx.compose.ui.graphics.Color.Transparent
    return arrayOf(
        0f to clear,
        0.400f to clear,
        0.405f to bar,   // wide bar (leading) — ~0.085 of the sweep line, ≈4.2× the trailing bar
        0.490f to bar,
        0.495f to clear,
        0.520f to clear, // small gap between the two bars
        0.525f to bar,   // thin trailing bar — ~0.020 of the sweep line
        0.545f to bar,
        0.550f to clear,
        1f to clear,
    )
}

/* ── Previews ────────────────────────────────────────────────────────── */

private val sampleItems = SnabbitEarningsItems(
    listOf(
        SnabbitEarningsItem("Work (1 hour)", "₹120"),
        SnabbitEarningsItem("Check In by", "₹5", accent = "7:45 PM", highlighted = true),
        SnabbitEarningsItem("Summer Bonus ☀️ (1 hour)", "₹20"),
        SnabbitEarningsItem("OT (15 min)", "₹40"),
    ),
)

private val longDistanceItems = SnabbitEarningsItems(
    listOf(
        SnabbitEarningsItem("Work (1 hour)", "₹120"),
        SnabbitEarningsItem("Check In by", "₹5", accent = "7:45 PM", highlighted = true),
        SnabbitEarningsItem("Long Distance (1.2 Kms)", "₹20"),
        SnabbitEarningsItem("Summer Bonus ☀️ (1 hour)", "₹20"),
        SnabbitEarningsItem("OT (15 min)", "₹40"),
    ),
)

private val earningsChangeItems = SnabbitEarningsItems(
    listOf(
        SnabbitEarningsItem("Work (1 hour)", "₹120"),
        SnabbitEarningsItem("Check In by", "₹5", accent = "7:45 PM", valueLost = true),
        SnabbitEarningsItem("Summer Bonus ☀️ (1 hour)", "₹20"),
        SnabbitEarningsItem("OT (15 min)", "₹40"),
    ),
)

// Highlighted band as the *last* row (the "New Job" layout): the card must not leave
// white space beneath the full-bleed band.
private val highlightedLastItems = SnabbitEarningsItems(
    listOf(
        SnabbitEarningsItem("Work", "₹60"),
        SnabbitEarningsItem("Check In by", "₹3", accent = "7:03 AM", highlighted = true),
    ),
)

// Server-driven per-line extras (Figma earnings card): an inline duration (`durationText`, shown
// as "(1 hr)"), a subtitle (`subtitle`) and a server icon (`iconUrl`). RemoteImage no-ops in
// @Preview (no network), so the icon shows on device only; the duration + subtitle render here.
private val serverExtrasItems = SnabbitEarningsItems(
    listOf(
        SnabbitEarningsItem("Work", "₹120", durationText = "1 hr"),
        SnabbitEarningsItem("Check In by", "₹15", accent = "4:41 PM", highlighted = true),
        SnabbitEarningsItem(
            label = "Monsoon Bonus",
            value = "₹10",
            durationText = "1 hr",
            iconUrl = "https://cdn.snabbit.com/rate-card-v2/rain.png",
            subtitle = "₹10 + ₹25 Extra",
        ),
    ),
)

@Preview
@Composable
private fun PreviewSnabbitEarningsAccordionExpanded() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitEarningsAccordion(title = "You Will Earn", amount = "₹150", items = sampleItems)
        }
    }
}

@Preview
@Composable
private fun PreviewSnabbitEarningsAccordionLongDistance() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitEarningsAccordion(title = "You Will Earn", amount = "₹150", items = longDistanceItems)
        }
    }
}

@Preview
@Composable
private fun PreviewSnabbitEarningsAccordionEarningsChange() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitEarningsAccordion(
                title = "You Will Earn",
                amount = "₹140",
                originalAmount = "₹150",
                items = earningsChangeItems,
            )
        }
    }
}

@Preview
@Composable
private fun PreviewSnabbitEarningsAccordionHighlightedLastRow() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitEarningsAccordion(title = "You Will Earn", amount = "₹63", items = highlightedLastItems)
        }
    }
}

@Preview
@Composable
private fun PreviewSnabbitEarningsAccordionServerExtras() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitEarningsAccordion(title = "You Will Earn", amount = "₹145", items = serverExtrasItems)
        }
    }
}

@Preview
@Composable
private fun PreviewSnabbitEarningsAccordionCollapsedWithSummary() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitEarningsAccordion(
                title = "You Will Earn",
                amount = "₹150",
                items = sampleItems,
                collapsible = true,
                initialExpanded = false,
                collapsedSummary = EarningsCollapsedSummary(
                    baseAmount = "₹145",
                    bonusAmount = "₹5",
                    pillText = "Check In by 7:45 PM",
                ),
            )
        }
    }
}

@Preview
@Composable
private fun PreviewSnabbitEarningsAccordionCollapsedDiscounted() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitEarningsAccordion(
                title = "You Will Earn",
                amount = "₹145",
                originalAmount = "₹150",
                items = sampleItems,
                collapsible = true,
                initialExpanded = false,
            )
        }
    }
}

@Preview
@Composable
private fun PreviewSnabbitEarningsSummaryBar() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitEarningsSummaryBar(caption = "YOU EARN", value = "₹145")
        }
    }
}
