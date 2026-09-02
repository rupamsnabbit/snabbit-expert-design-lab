package com.snabbit.runner.shared.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitDivider
import com.snabbit.design.atoms.SnabbitDividerType
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.ui.icons.AppIcons

/**
 * SnabbitNavigationCard — the job "navigation" card (Expert App – Design System 2.0,
 * Figma node `1491:7884`): a bordered white card with the customer's name + address,
 * an optional "Listen" (read-aloud) pill, a divider, and a row of round-icon
 * quick-actions (e.g. Map / Call / Chat), each with a label and an optional count badge.
 *
 * The Figma also has a "Street view" thumbnail on the right of the actions row — omitted
 * here by design (not needed).
 *
 * Actions are data ([SnabbitNavigationAction], wrapped in the stable [SnabbitNavigationActions])
 * so the card stays reusable and the caller owns the icons + handlers. Icons are [ImageVector]s —
 * callers pass the exact design
 * glyphs (see `AppIcons`), since the DS `SnabbitIconName` set lacks / mis-renders some of
 * them (Map, Chat, the customer & listen marks).
 *
 * Tokens only: card [SnabbitTheme.colors.borderSubtle] / [bgPrimary], name
 * [textPrimary], address `gray600`, labels [textSecondary], action fill [bgBrandSubtle],
 * icon [iconBrand], badge [bgBrand] + [textInverse], Listen pill `gray100`.
 */
@Composable
fun SnabbitNavigationCard(
    customerName: String,
    address: String,
    actions: SnabbitNavigationActions = SnabbitNavigationActions(emptyList()),
    modifier: Modifier = Modifier,
    listenLabel: String = "Listen",
    onListen: (() -> Unit)? = null,
) {
    val cardShape = RoundedCornerShape(16.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(SnabbitTheme.colors.bgPrimary)
            .border(1.5.dp, SnabbitTheme.colors.borderSubtle, cardShape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // Header: customer name (+ optional Listen pill) over the address.
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f, fill = false),
                ) {
                    SnabbitIcon(
                        imageVector = AppIcons.Customer,
                        size = 16.dp,
                        color = SnabbitTheme.colors.textPrimary,
                    )
                    SnabbitText(
                        text = customerName,
                        color = SnabbitTheme.colors.textPrimary,
                        fontSize = 16.sp,
                        lineHeight = 24.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
                if (onListen != null) {
                    ListenPill(label = listenLabel, onClick = onListen)
                }
            }
            // Full address, however many lines — no maxLines/ellipsis clamp. Omitted entirely when
            // blank so it leaves no stray gap under the name.
            if (address.isNotBlank()) {
                SnabbitText(
                    text = address,
                    color = SnabbitColorsLight.gray600,
                    fontSize = 14.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Normal,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }

        // The divider + quick-actions row only render when the card carries actions. Name-only
        // callers (e.g. the "unblock to block" customer card, Figma 13:12133) get just the header.
        if (actions.items.isNotEmpty()) {
            SnabbitDivider(type = SnabbitDividerType.Line, modifier = Modifier.fillMaxWidth())

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                actions.items.forEach { action -> NavigationActionButton(action) }
            }
        }
    }
}

/** One quick-action in a [SnabbitNavigationCard] — a round icon button with a label. */
data class SnabbitNavigationAction(
    val icon: ImageVector,
    val label: String,
    val onClick: () -> Unit,
    /** Optional count badge on the button's top-right corner (e.g. the Map "1"). */
    val badgeCount: Int? = null,
)

/**
 * Stable, [Immutable] wrapper around the [SnabbitNavigationAction] list. A bare
 * `List<SnabbitNavigationAction>` is an *unstable* Compose parameter, so passing one straight into
 * [SnabbitNavigationCard] stops it from skipping and forces a recompose on every parent tick;
 * wrapping the list in this `@Immutable` type marks it stable and restores skipping.
 */
@Immutable
data class SnabbitNavigationActions(val items: List<SnabbitNavigationAction>)

@Composable
private fun NavigationActionButton(action: SnabbitNavigationAction) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(SnabbitTheme.colors.bgBrandSubtle)
                    .clickable(onClick = action.onClick)
                    .padding(16.dp),
            ) {
                SnabbitIcon(
                    imageVector = action.icon,
                    size = 20.dp,
                    color = SnabbitTheme.colors.iconBrand,
                )
            }
            if (action.badgeCount != null) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .offset(x = 6.dp, y = (-6).dp)
                        .clip(CircleShape)
                        .background(SnabbitTheme.colors.bgBrand)
                        .defaultMinSize(minWidth = 16.dp, minHeight = 16.dp)
                        .padding(horizontal = 5.dp, vertical = 1.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    SnabbitText(
                        text = action.badgeCount.toString(),
                        color = SnabbitTheme.colors.textInverse,
                        fontSize = 12.sp,
                        lineHeight = 16.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
        SnabbitText(
            text = action.label,
            color = SnabbitTheme.colors.textSecondary,
            fontSize = 12.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.Normal,
        )
    }
}

@Composable
private fun ListenPill(label: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50.dp))
            .background(SnabbitColorsLight.gray100)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SnabbitText(
            text = label,
            color = SnabbitTheme.colors.textSecondary,
            fontSize = 12.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.Normal,
        )
        SnabbitIcon(
            imageVector = AppIcons.Listen,
            size = 16.dp,
            color = SnabbitTheme.colors.textSecondary,
        )
    }
}

/* ── Previews ────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewSnabbitNavigationCard() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitNavigationCard(
                customerName = "Radhika S",
                address = "HAL Old Airport rd, near railway over bridge, LN Pura, Marathahalli, Bengaluru",
                onListen = {},
                actions = SnabbitNavigationActions(
                    listOf(
                        SnabbitNavigationAction(AppIcons.Map, "Map", onClick = {}, badgeCount = 1),
                        SnabbitNavigationAction(AppIcons.Call, "Call", onClick = {}),
                        SnabbitNavigationAction(AppIcons.Chat, "Chat", onClick = {}),
                    ),
                ),
            )
        }
    }
}
