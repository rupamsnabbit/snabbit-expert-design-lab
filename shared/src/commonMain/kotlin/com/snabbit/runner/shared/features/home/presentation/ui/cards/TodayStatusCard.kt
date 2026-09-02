package com.snabbit.runner.shared.features.home.presentation.ui.cards

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitCard
import com.snabbit.design.atoms.SnabbitCardPadding
import com.snabbit.design.atoms.SnabbitCardVariant
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.absent_filled
import com.snabbit.runner.shared.resources.absent_today_illustration
import com.snabbit.runner.shared.resources.change_refresh
import com.snabbit.runner.shared.resources.header_coin
import com.snabbit.runner.shared.resources.no_show_illustration
import com.snabbit.runner.shared.resources.present_filled
import com.snabbit.runner.shared.resources.snabbit_red_card_icon
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.shift.core.domain.model.AttendanceStatus
import com.snabbit.runner.shared.features.gamification.domain.model.NudgePillKind
import com.snabbit.runner.shared.features.gamification.domain.model.PreActionNudge
import com.snabbit.runner.shared.features.gamification.domain.model.deriveNudgePill
import com.snabbit.runner.shared.features.gamification.presentation.ResolveNudgeLabel
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent

/**
 * AttendanceCard → TodayStatus state. Two visual layouts:
 *
 *  - **Small (Figma DS 1597:6792 "Absent" / 1580:6420 "Present + Login")** —
 *    canChange == true. White SnabbitCard `Elevated`, gray-100 header strip
 *    with date + shift window, body row = status icon + label + Change CTA.
 *
 *  - **Big pink (Figma DS 1597:6858 "Absent Today")** — canChange == false
 *    AND status == Absent. Pink (red-50) card with red-200 border, centered
 *    80dp illustration placeholder, "Absent Today" red-600 heading, date in
 *    parens below. No shift time, no Change CTA — terminal state.
 *
 * ponytail: big variant is hand-rolled (red-50 bg / red-200 border doesn't
 * exist as a SnabbitCard variant). Illustration is a placeholder per
 * "icons & images stay placeholders until DS ships them" rule. Other
 * statuses (Present/NoShow/FA) with canChange == false fall back to the
 * small variant; the DS doesn't define big variants for those.
 */
@Composable
fun TodayStatusCard(
    card: HomeCard.Attendance.TodayStatus,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
    /** EARLY_LOGIN pre-action nudge, host-threaded from `gamState.nudges`. When
     *  present on a Present card it docks an amber "Login by …" strip under the
     *  card (Figma DS 87-25340). Null → no strip. */
    loginNudge: PreActionNudge? = null,
) {
    // Terminal pink-card variants — Figma DS 1597:6858 (Absent),
    // 87-39946 (NoShow). FalseAttendance has no DS terminal variant yet;
    // falls back to the small variant.
    val terminalConfig: Pair<String, DrawableResource?>? = when {
        card.canChange -> null
        card.status == AttendanceStatus.Absent ->
            strings.todayStatusAbsentTerminal to Res.drawable.absent_today_illustration
        card.status == AttendanceStatus.NoShow ->
            // Figma DS 76-38737 — "No Show Today" terminal card with money-jar illustration.
            strings.todayStatusNoShowTerminal to Res.drawable.no_show_illustration
        else -> null
    }
    if (terminalConfig != null) {
        BigTerminalCard(
            dateLabel = card.day.dateLabel,
            title = terminalConfig.first,
            illustration = terminalConfig.second,
            modifier = modifier,
        )
    } else if (card.status == AttendanceStatus.Present && loginNudge != null) {
        // Present + Login with a login nudge. The nudge is the CONTAINER background
        // (rounded-16 on all corners) with the elevated white card drawn on top; the
        // card's bottom rounded corners reveal the gradient behind them, and the strip
        // row peeks ~46dp below — so card + strip read as one rounded-16 unit with no
        // gap in the corners.
        //
        // Two variants, keyed off the nudge kind: the EARLY_LOGIN opportunity/coin
        // strip is amber (Figma DS 76-36033); the LATE_LOGIN risk/red-card strip is
        // red (Figma DS 3042-57143, red-100 → red-300).
        val gradient = if (loginNudge.isRisk) {
            listOf(SnabbitColorsLight.red100, SnabbitColorsLight.red300)
        } else {
            listOf(SnabbitColorsLight.yellow50, SnabbitColorsLight.yellow100)
        }
        Column(
            modifier = modifier
                .fillMaxWidth()
                .background(
                    Brush.horizontalGradient(gradient),
                    RoundedCornerShape(SnabbitTheme.borderRadius.xl),
                ),
        ) {
            SmallTodayStatusCard(card, strings, onIntent, Modifier)
            LoginNudgeRow(nudge = loginNudge)
        }
    } else {
        SmallTodayStatusCard(card, strings, onIntent, modifier)
    }
}

// ──────────────────────── EARLY_LOGIN docked nudge ────────────────────────

/**
 * The "Login by …" content row that peeks below the card in the Present + nudge
 * layout — Figma DS 76-36033 (`Nudge` container 38:26100). Transparent: the amber
 * gradient + rounded corners are owned by the parent container so it can fill the
 * card's bottom corners. Leading server-driven glyph + resolved nudge label;
 * trailing white coin chip (yellow-200 border, yellow-600 count) when the nudge
 * carries gold coins.
 *
 * ponytail: the label copy carries `**bold**` emphasis on the deadline, but
 * `SnabbitText` is plain-string only (same DS gap flagged in `NudgeBanner`) —
 * markers are stripped and the whole label rendered at medium weight.
 */
@Composable
private fun LoginNudgeRow(nudge: PreActionNudge) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 46.dp)
            .padding(horizontal = SnabbitTheme.spacing.componentPaddingMd, vertical = SnabbitTheme.spacing.componentPaddingSm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
        ) {
            // Server-driven leading glyph (Dart `_LeadingIcon(url: iconUrl)`): the
            // BE ships the right icon per variant — gold coin for the reward
            // nudge, a No-Show/clock glyph for the risk one. The parser guarantees
            // a non-empty iconUrl on every valid nudge.
            SnabbitRemoteImage(
                model = nudge.iconUrl,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                contentScale = ContentScale.Fit,
            )
            SnabbitText(
                text = ResolveNudgeLabel.resolve(nudge.label).replace("**", ""),
                variant = SnabbitTextVariant.BodyMd,
                // Risk copy is Body-S/14-Semibold in Figma 3042-57143; the amber
                // opportunity strip stays Medium.
                fontWeight = if (nudge.isRisk) FontWeight.SemiBold else FontWeight.Medium,
                color = SnabbitTheme.colors.textBody,
            )
        }
        // Trailing pill mirrors `deriveNudgePill`: coins win over red cards, and a
        // nudge carrying neither renders bare.
        val pill = deriveNudgePill(nudge.goldCoins, nudge.redCards)
        when (pill.kind) {
            NudgePillKind.Coin -> LoginNudgeCoinChip(count = pill.count)
            NudgePillKind.RedCard -> LoginNudgeRedCardChip(count = pill.count)
            NudgePillKind.None -> Unit
        }
    }
}

/** Aspect ratio (w / h) of the red-card glyph in the chip — Figma 1:2270 (8.883 × 13). */
private const val RedCardGlyphAspectRatio = 8.883f / 13f

/** Red-card chip — the trailing badge on the LATE_LOGIN risk strip (Figma
 *  3042-57169 / chip 30:18396): red-100 fill, red-200 hairline, red-600 count.
 *  The red sibling of [LoginNudgeCoinChip]; kept separate rather than
 *  parameterised because fill, border, glyph and count colour all differ. */
@Composable
private fun LoginNudgeRedCardChip(count: Int) {
    Row(
        modifier = Modifier
            .background(SnabbitColorsLight.red100, RoundedCornerShape(999.dp))
            .border(1.dp, SnabbitColorsLight.red200, RoundedCornerShape(999.dp))
            .padding(horizontal = SnabbitTheme.spacing.componentPaddingSm, vertical = SnabbitTheme.spacing.componentGapXs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs),
    ) {
        // Figma nests the card glyph in a 20dp box at its natural 8.883 × 13
        // aspect — sizing the image to the full 20dp square instead stretches it.
        Box(modifier = Modifier.size(20.dp), contentAlignment = Alignment.Center) {
            SnabbitImage(
                painter = painterResource(Res.drawable.snabbit_red_card_icon),
                contentDescription = null,
                modifier = Modifier.height(13.dp).aspectRatio(RedCardGlyphAspectRatio),
                contentScale = ContentScale.Fit,
            )
        }
        SnabbitText(
            text = count.toString(),
            color = SnabbitColorsLight.red600,
            fontSize = 16.sp,
            lineHeight = 24.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

/** White coin chip with a yellow-200 border — the trailing badge on the login
 *  nudge strip (Figma 1581:6770). Distinct from `NudgePillBadge` (filled) and
 *  `CtaBadgeChip` (on-button translucent): white bg + border for the amber strip. */
@Composable
private fun LoginNudgeCoinChip(count: Int) {
    Row(
        modifier = Modifier
            .background(SnabbitColorsLight.whiteDefault, RoundedCornerShape(999.dp))
            .border(1.dp, SnabbitColorsLight.yellow200, RoundedCornerShape(999.dp))
            .padding(horizontal = SnabbitTheme.spacing.componentPaddingSm, vertical = SnabbitTheme.spacing.componentGapXs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs),
    ) {
        SnabbitImage(
            painter = painterResource(Res.drawable.header_coin),
            contentDescription = null,
            modifier = Modifier.size(20.dp),
        )
        SnabbitText(
            text = count.toString(),
            color = SnabbitColorsLight.yellow600,
            fontSize = 16.sp,
            lineHeight = 24.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

// ──────────────────────── Small variant ────────────────────────

@Composable
private fun SmallTodayStatusCard(
    card: HomeCard.Attendance.TodayStatus,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier,
) {
    SnabbitCard(
        modifier = modifier.fillMaxWidth(),
        variant = SnabbitCardVariant.Elevated,
        padding = SnabbitCardPadding.Lg,
        headerHeight = 76.dp,  // matches TomorrowProvisionalCard — see ponytail note there
        header = { CardHeader(card.day.dateLabel, card.day.shiftWindowLabel) },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapLg)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
                ) {
                    StatusIcon(card.status)
                    // Figma 47:30249 wants Body-L/18-Semibold (18sp / 24sp lh).
                    // DS `Title` is 18sp/24 (Medium) — use it and bump weight to
                    // SemiBold to match Figma.
                    SnabbitText(
                        text = card.status.label(strings),
                        variant = SnabbitTextVariant.Title,
                        fontWeight = FontWeight.SemiBold,
                        color = card.status.tint(),
                    )
                }
                if (card.canChange) {
                    ChangeButton(
                        label = strings.todayChangeCta,
                        onClick = { onIntent(HomeUiIntent.TapChangeAttendance) },
                    )
                }
            }
            // Login CTA — Figma DS 1580:6420 "Present + Login". Disabled
            // until the server flips `enable_login` (rides on the
            // RUNNER_LOGIN_HOTSPOT widget → `card.canLoginNow`). Hidden entirely
            // on a provisional/tomorrow shift — there's nothing to log in to yet.
            if (card.status == AttendanceStatus.Present && !card.isProvisional) {
                SnabbitButton(
                    text = strings.todayLoginCta,
                    onClick = { onIntent(HomeUiIntent.TapLogin) },
                    style = SnabbitButtonStyle.Primary,
                    size = SnabbitButtonSize.L,
                    enabled = card.canLoginNow,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

// ──────────────────────── Big terminal variant ────────────────────────

/**
 * Pink-bg terminal card used when [HomeCard.Attendance.TodayStatus.canChange]
 * is false — covers both "Absent Today" (Figma DS 1597:6858) and
 * "No Show Today" (Figma 87-39946). Layout is identical; only [title]
 * differs.
 */
@Composable
private fun BigTerminalCard(
    dateLabel: String,
    title: String,
    illustration: DrawableResource?,
    modifier: Modifier,
) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(SnabbitTheme.colors.bgErrorSubtle, shape)
            .border(1.5.dp, SnabbitTheme.colors.borderError, shape)
            .padding(SnabbitTheme.spacing.componentPaddingMd),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs),
        ) {
            if (illustration != null) {
                SnabbitImage(
                    painter = painterResource(illustration),
                    contentDescription = title,
                    modifier = Modifier.size(96.dp),
                    contentScale = ContentScale.Fit,
                )
            } else {
                // Placeholder until the matching illustration ships.
                Box(
                    modifier = Modifier
                        .size(96.dp)
                        .clip(CircleShape)
                        .background(SnabbitColorsLight.red200),
                )
            }
            SnabbitText(
                text = title,
                variant = SnabbitTextVariant.BodyLg,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textError,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            SnabbitText(
                text = "($dateLabel)",
                variant = SnabbitTextVariant.BodyMd,
                color = SnabbitTheme.colors.textSecondary,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
            )
        }
    }
}

// ──────────────────────── shared helpers ────────────────────────

private fun AttendanceStatus.label(s: HomeStrings) = when (this) {
    AttendanceStatus.Pending -> ""
    AttendanceStatus.Present -> s.todayStatusPresent
    AttendanceStatus.Absent -> s.todayStatusAbsent
    AttendanceStatus.NoShow -> s.todayStatusNoShow
    AttendanceStatus.FalseAttendance -> s.todayStatusFalseAttendance
}

@Composable
private fun AttendanceStatus.tint() = when (this) {
    AttendanceStatus.Present -> SnabbitTheme.colors.textSuccess
    AttendanceStatus.Absent, AttendanceStatus.NoShow, AttendanceStatus.FalseAttendance -> SnabbitTheme.colors.textError
    AttendanceStatus.Pending -> SnabbitTheme.colors.textSecondary
}

@Composable
private fun StatusIcon(status: AttendanceStatus) {
    when (status) {
        AttendanceStatus.Pending -> SnabbitIcon(
            name = SnabbitIconName.Clock, size = 24.dp, color = status.tint(),
        )
        AttendanceStatus.Present -> SnabbitImage(
            painter = painterResource(Res.drawable.present_filled),
            contentDescription = null,
            modifier = Modifier.size(24.dp),
        )
        AttendanceStatus.Absent, AttendanceStatus.NoShow, AttendanceStatus.FalseAttendance -> SnabbitImage(
            painter = painterResource(Res.drawable.absent_filled),
            contentDescription = null,
            modifier = Modifier.size(24.dp),
        )
    }
}

// ──────────────────────── Change CTA ────────────────────────

/**
 * "Change" CTA on the small TodayStatus card — Figma DS node 47:30250.
 *
 * Spec: white background, 6.4dp rounded corners, no border, 8dp vertical
 * padding (no horizontal), 6.4dp gap between the 16dp refresh icon and the
 * "Change" label (Outfit Medium 14sp / 20sp line height, gray-700 #374151).
 *
 * ponytail: hand-rolled — none of the `SnabbitButtonStyle` variants in DS
 * 0.11.0 match this borderless white-bg shape (NeutralStroke has a border,
 * Tertiary has a pink border, TextLink/LinkButton are text-only).
 */
@Composable
private fun ChangeButton(
    label: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(SnabbitTheme.borderRadius.sm))
            .background(SnabbitTheme.colors.bgPrimary)
            .clickable(onClick = onClick)
            .padding(vertical = SnabbitTheme.spacing.componentPaddingSm),
        horizontalArrangement = Arrangement.spacedBy(
            SnabbitTheme.spacing.componentGapSm,
            Alignment.CenterHorizontally,
        ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SnabbitImage(
            painter = painterResource(Res.drawable.change_refresh),
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            contentScale = ContentScale.Fit,
        )
        SnabbitText(
            text = label,
            variant = SnabbitTextVariant.BodyMd,
            fontWeight = FontWeight.Medium,
            color = SnabbitTheme.colors.textBody,
        )
    }
}
