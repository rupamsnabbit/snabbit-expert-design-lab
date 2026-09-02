package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Design tokens for [ProfileMenuRow] + [ProfileSectionCard], taken 1:1 from Figma
 * node `933:32278` (Shift · Job-Lifecycle DS).
 *
 * These two components are built in **pure Material 3** (product decision for the
 * Profile page) rather than the Snabbit DS atoms, so the brand values live here as
 * explicit tokens instead of `SnabbitTheme.*`. Kept in one object so they're easy
 * to tweak or later fold into a real M3 `ColorScheme`/`Typography`. Text itself is
 * rendered with the DS `SnabbitText` atom (Outfit font), so type styles no longer
 * live here — only colours and dimensions.
 */
object ProfileTileDefaults {
    // ── Colors (Figma variable → hex) ─────────────────────────────────────────
    val PageBackground = Color(0xFFF9FAFB) // Gray/color-gray-50 (white cards sit on it)
    val PageTitle = Color(0xFF111827)      // Gray/color-gray-900 ("Profile" heading)
    // Header card (Figma node 933:32258 — warm "star-expert" gradient card)
    val HeaderGradientStart = Color(0xFFFEFBF9) // near-white (top-left)
    val HeaderGradientEnd = Color(0xFFEAC8A3)   // tan/gold (bottom-right)
    val HeaderBorder = Color(0xFFEAC9A4)        // tan/gold 1dp border
    val HeaderName = Color(0xFF111827)          // Gray/color-gray-900 (runner name)
    val HeaderSubtitle = Color(0xFF4B5563)      // Gray/color-gray-600 (delivery method · #id)
    // Tiering card (per-tier gradient bg) — text goes light on the dark gradient (Figma
    // "Expert Tier" profile card: name #FFF, #id gray-200, tier row #FFF).
    val HeaderTierName = Color(0xFFFFFFFF)      // white runner name on the gradient
    val HeaderTierSubtitle = Color(0xFFE5E7EB)  // Gray/color-gray-200 (#id on the gradient)
    val HeaderTierRowText = Color(0xFFFFFFFF)   // "{Tier} Level" + "View level" (white)
    // "Improve Ratings" CTA (drawer parity — expert_info bottom bar; two colour variants)
    val ImproveRatingsBg = Color(0xFFD33F4C)             // red bar (rating < 4.3)
    val ImproveRatingsBgHigh = Color(0xFFF5F5F5)         // light-gray bar (rating ≥ 4.3)
    val ImproveRatingsStarCircle = Color(0xFFA73636)     // dark-red star circle (default) — r50
    val ImproveRatingsStarCircleHigh = Color(0xFFFBBC05) // yellow star circle (high)
    val ImproveRatingsText = Color(0xFFFCFCFC)           // near-white text (default) — n10
    val ImproveRatingsTextHigh = Color(0xFFA27900)       // dark-gold text (high)
    val ImproveRatingsStar = Color(0xFFFFFFFF)           // white star glyph
    val CardBackground = Color(0xFFFFFFFF) // Gray/White
    val Label = Color(0xFF374151)          // Gray/color-gray-700
    val LabelError = Color(0xFFDC2626)     // Red/color-red-600 (destructive, e.g. Emergency logout)
    val Value = Color(0xFF047857)          // Green/color-green-700
    val LeadingIcon = Color(0xFF374151)    // Gray/color-gray-700
    val Chevron = Color(0xFF6B7280)        // Gray/color-gray-500
    val Divider = Color(0xFFF3F4F6)        // Gray/color-gray-100
    val SectionTitle = Color(0xFF4B5563)   // Gray/color-gray-600 (section title, node 933:32277)
    val BadgeBackground = Color(0xFFFEF1F7) // Pink/color-primary-50
    val BadgeText = Color(0xFFF70F79)      // Pink/color-primary-600 P
    // Nudge card + carousel dots (Figma node 933:32268 / 933:32935)
    val NudgeBackground = Color(0xFFFEF1F7) // Pink/color-primary-50
    val NudgeBorder = Color(0xFFFDE4EF)    // Pink/color-primary-100
    val NudgeText = Color(0xFF374151)      // Gray/color-gray-700
    val NudgeIcon = Color(0xFF374151)      // Gray/color-gray-700
    val NudgeButton = Color(0xFFF70F79)    // Pink/color-primary-600 P
    val NudgeButtonText = Color(0xFFFFFFFF) // Gray/White
    val DotActive = Color(0xFFF70F79)      // Pink/color-primary-600 P
    val DotInactive = Color(0xFFD1D5DB)    // Gray/color-gray-300 (approx — inactive dot not a Figma token)

    // ── Dimensions ────────────────────────────────────────────────────────────
    val PageTitleTopGap = 24.dp   // "Profile" heading gap below the status-bar inset
    val PageTitleToContent = 16.dp // "Profile" heading → first content block
    val SectionGap = 24.dp         // between the header / nudge / each section card
    // Header card (Figma node 933:32258)
    val HeaderCornerRadius = 16.dp
    val HeaderBorderWidth = 1.dp
    val HeaderPadding = 12.dp       // inset: 12 + avatar 72 + 12 = 96 card height (Figma)
    val HeaderAvatarSize = 72.dp
    val HeaderAvatarGap = 12.dp     // avatar → text (Figma 95 − 11 − 72 ≈ 12)
    val HeaderNameToId = 2.dp       // name → sub-line
    val HeaderRowToChip = 8.dp      // avatar/name row → period-leave chip
    val FooterLineGap = 4.dp        // between footer lines (brand / version / endpoint)
    // Period-leave chip (drawer parity — expert_info)
    val PeriodLeaveChipText = Color(0xFF000000) // black (drawer _kPeriodLeaveChipTextColor)
    val PeriodLeaveChipIcon = 12.dp
    val PeriodLeaveChipGap = 4.dp   // drop icon → text
    // Tiering "view level" row (bottom of the per-tier card)
    val TierRowBadgeSize = 24.dp    // tier badge icon
    val TierRowGap = 8.dp           // badge → "{Tier} Level"
    val TierRowCtaGap = 2.dp        // "View level" → chevron
    val TierRowChevronSize = 16.dp
    // "Improve Ratings" CTA
    const val HighlyRatedThreshold = 4.3 // ≥ this → the calm light-gray variant (drawer parity)
    val HeaderToImproveRatings = 8.dp    // header card → CTA bar
    val ImproveRatingsRadius = 8.dp
    val ImproveRatingsPaddingH = 16.dp
    val ImproveRatingsPaddingV = 10.dp
    val ImproveRatingsStarBox = 20.dp    // star circle diameter
    val ImproveRatingsStarIcon = 14.dp
    val ImproveRatingsGap = 8.dp         // star → text
    val ImproveRatingsChevron = 16.dp
    val CardCornerRadius = 16.dp
    // Whole-tile tap target: each row owns its padding INSIDE the clickable, so the
    // ripple spans the full card width and the vertical gap. CardVerticalPadding (4) +
    // RowPaddingV (16) = 20 content inset top/bottom; between rows the gap is
    // RowPaddingV + RowPaddingV = 16+16 around the divider — all matching Figma.
    val CardVerticalPadding = 4.dp
    val RowPaddingH = 20.dp      // row content inset (clickable/ripple still full width)
    val RowPaddingV = 16.dp
    val DividerInset = 20.dp     // divider matches content width (inset from each card edge)
    val LeadingGap = 12.dp       // icon → label
    val TrailingGap = 8.dp       // value → badge → chevron
    val LeadingIconSize = 20.dp
    val ChevronSize = 16.dp
    val DividerThickness = 1.dp
    val BadgeCornerRadius = 6.dp
    val BadgePaddingH = 8.dp
    val BadgePaddingV = 4.dp
    // Nudge card + carousel
    val NudgeCardRadius = 12.dp
    val NudgeBorderWidth = 1.5.dp
    val NudgePadding = 16.dp
    val NudgeIconSize = 24.dp
    val NudgeContentGap = 12.dp
    // Figma single-line card is 68 (node 933:32501); kept at 72 so our longer nudge texts
    // (Aadhaar / PAN-Aadhaar) that wrap to 2 lines in the narrower peeking card fit at a
    // UNIFORM height (no shrink/flicker). Drop to 68 if all copy is guaranteed one line.
    val NudgeCardHeight = 72.dp
    val NudgeButtonHeight = 36.dp
    val NudgeButtonRadius = 8.dp
    val NudgeButtonPaddingH = 12.dp
    // HorizontalPager trailing peek: `contentPadding(end = NudgePeek)` leaves cards flush-left
    // and reserves a strip on the RIGHT so the next card peeks (icon-first). Card width =
    // viewport − NudgePeek; visible peek ≈ NudgePeek − NudgePageSpacing. Figma's own peek is
    // ~22 (card 323 in a 361 column); we run it a bit larger for a clearer "swipe for more"
    // signal (≈42 visible). The pager loops, so the last card's next wraps to the first — the
    // peek is never empty.
    val NudgePeek = 58.dp
    val NudgePageSpacing = 16.dp
    val DotsTopGap = 10.dp         // pager → dots
    val DotSize = 8.dp             // all dots same size (active differs by colour only)
    val DotGap = 5.dp
}
