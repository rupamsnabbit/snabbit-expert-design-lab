package com.snabbit.runner.shared.core.designsystem

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.drawscope.DrawScope
import com.snabbit.runner.shared.features.tiering.domain.model.NudgeTheme
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import kotlin.math.hypot

/**
 * Per-tier + per-nudge-theme colours for the tiering surfaces, mirroring the
 * Flutter `AppColors` tiering palette exactly.
 *
 * Lives in the core/designsystem layer — the one place detekt allows raw
 * [androidx.compose.ui.graphics.Color] (its ForbiddenImport rule excludes that
 * directory). Feature composables reference these through the accessors below;
 * because each accessor's return type is inferred (Color), the feature files
 * never name or import Color and stay detekt-clean.
 *
 * Legacy tiers (`BASIC` / `PRO` / `ELITE`) fall back to the `BASE` palette, matching
 * the Flutter `_tierSpecificStyle` / badge / drawer fallbacks. (They're gated out of
 * the tiering surfaces by [Tier.isLegacyTier], so these fallbacks rarely render.)
 */
internal object TierColors {

    // ── Nudge accent / tint ──
    // accent = coins-card header bg + progress fill + border, and the tier-specific
    // themed row's border/title; tint = coins-card body + tier-specific row bg.
    fun accent(tier: Tier): Color = when (tier) {
        Tier.BASIC, Tier.BASE, Tier.PRO, Tier.ELITE -> Color(0xFF755E49)
        Tier.SILVER -> Color(0xFF6B7280)
        Tier.GOLD -> Color(0xFFA1700F)
        Tier.DIAMOND -> Color(0xFF33647C)
        Tier.PINK_DIAMOND -> Color(0xFFB31884)
    }

    fun tint(tier: Tier): Color = when (tier) {
        Tier.BASIC, Tier.BASE, Tier.PRO, Tier.ELITE -> Color(0xFFFFFBEB)
        Tier.SILVER -> Color(0xFFF9FAFB)
        Tier.GOLD -> Color(0xFFFFFBEB)
        Tier.DIAMOND -> Color(0xFFEBFAFF)
        Tier.PINK_DIAMOND -> Color(0xFFFEF1F7)
    }

    /**
     * `srcIn` tint for a themed nudge's leading icon — mirrors the Flutter
     * `TierNudgeListItem` `leadingImageColor` (`ColorFilter.mode(imageTint, srcIn)`)
     * fed by `ApplicableTieringNudge`'s `isTierSpecific ? null : style.imageTint`.
     * Null (icon keeps its own colours) for the TIER_SPECIFIC theme — which shows the
     * tier badge — and the job/pink variant. Returns a [ColorFilter] so feature code
     * never names `Color`/`ColorFilter`/`BlendMode` (detekt ForbiddenImport).
     */
    fun nudgeImageTint(theme: NudgeTheme, pinkStyle: Boolean): ColorFilter? {
        if (pinkStyle) return null
        val tint = when (theme) {
            NudgeTheme.TIER_SPECIFIC -> return null
            NudgeTheme.BENEFITS -> benefitsAccent
            NudgeTheme.MOTIVATION -> motivationAccent
            NudgeTheme.GENERIC -> genericBorder
        }
        return ColorFilter.tint(tint, BlendMode.SrcIn)
    }

    // ── Profile-card background (per-tier radial gradient) ──
    /**
     * The profile "Expert Tier" card background — a top-left radial gradient
     * darkening toward the bottom-right (Figma nodes 4561-46620 / -48556 / …),
     * size-aware so it fills any card. Stops are opaque, so they fully cover a
     * solid fill painted behind them.
     */
    fun cardRadialBrush(tier: Tier, size: Size): Brush = Brush.radialGradient(
        *cardStops(tier),
        center = Offset(size.width * CARD_GRADIENT_CENTER_X, 0f),
        radius = hypot(size.width, size.height).coerceAtLeast(1f),
    )

    private fun cardStops(tier: Tier): Array<Pair<Float, Color>> = when (tier) {
        Tier.SILVER -> arrayOf(
            0f to Color(0xFFA2A2A2), 0.278f to Color(0xFF808080), 0.556f to Color(0xFF5E5E5E),
            0.778f to Color(0xFF404040), 0.889f to Color(0xFF313131), 1f to Color(0xFF222222),
        )
        Tier.GOLD -> arrayOf(
            0f to Color(0xFFA3710E), 0.278f to Color(0xFF7F5107), 0.556f to Color(0xFF5B3200), 1f to Color(0xFF3E2302),
        )
        Tier.DIAMOND -> arrayOf(
            0f to Color(0xFFBFD4E7), 0.556f to Color(0xFF93A6B6), 0.667f to Color(0xFF7A8995),
            0.778f to Color(0xFF616C75), 0.889f to Color(0xFF484E54), 1f to Color(0xFF2F3133),
        )
        Tier.PINK_DIAMOND -> arrayOf(
            0f to Color(0xFFB31884), 0.308f to Color(0xFF8D0F5B), 0.617f to Color(0xFF670632), 1f to Color(0xFF670632),
        )
        Tier.BASIC, Tier.BASE, Tier.PRO, Tier.ELITE -> arrayOf(
            0f to Color(0xFF91755B), 0.278f to Color(0xFF755C46), 0.556f to Color(0xFF584331),
            0.778f to Color(0xFF403024), 1f to Color(0xFF271D17),
        )
    }

    private const val CARD_GRADIENT_CENTER_X = 0.04f

    // ── Themed (non-tier) nudge styles ──
    val genericBorder = Color(0xFFF70F79)
    val genericTitle = Color(0xFF111827)
    val genericBg = Color(0xFFFFFFFF)
    val benefitsAccent = Color(0xFF059669)
    val benefitsTitle = Color(0xFF047857)
    val benefitsTint = Color(0xFFECFDF5)
    val motivationAccent = Color(0xFF2563EB)
    val motivationTint = Color(0xFFEFF6FF)

    // ── Tier badge (v2): background / border / text ──
    fun badgeBg(tier: Tier): Color = when (tier) {
        Tier.BASIC, Tier.BASE, Tier.PRO, Tier.ELITE -> Color(0xFFDFCFC2)
        Tier.SILVER -> Color(0xFFE5E7EB)
        Tier.GOLD -> Color(0xFFFEF3C7)
        Tier.DIAMOND -> Color(0xFFCEE8F6)
        Tier.PINK_DIAMOND -> Color(0xFFFDE4EF)
    }

    fun badgeBorder(tier: Tier): Color = when (tier) {
        Tier.BASIC, Tier.BASE, Tier.PRO, Tier.ELITE -> Color(0xFFFFFFFF)
        Tier.SILVER -> Color(0xFF9CA3AF)
        Tier.GOLD -> Color(0xFFFDE68A)
        Tier.DIAMOND -> Color(0xFFA6C8D8)
        Tier.PINK_DIAMOND -> Color(0xFFFBC9DF)
    }

    fun badgeText(tier: Tier): Color = when (tier) {
        Tier.BASIC, Tier.BASE, Tier.PRO, Tier.ELITE -> Color(0xFF2A180E)
        Tier.SILVER -> Color(0xFF374151)
        Tier.GOLD -> Color(0xFFB45309)
        Tier.DIAMOND -> Color(0xFF2C466F)
        Tier.PINK_DIAMOND -> Color(0xFFB31884)
    }

    // ── Week-flag pennant fill ──
    fun weekFlag(tier: Tier): Color = when (tier) {
        Tier.BASIC, Tier.BASE, Tier.PRO, Tier.ELITE -> Color(0xFF755E49)
        Tier.SILVER -> Color(0xFF4B5563)
        Tier.GOLD -> Color(0xFFA1700F)
        Tier.DIAMOND -> Color(0xFF33647C)
        Tier.PINK_DIAMOND -> Color(0xFFB31884)
    }

    // ── Tier badge v2 (app-bar "medal": white icon circle + gradient name capsule) ──
    /** White disc behind the tier icon (Figma badge-v2 top circle). */
    val badgeCircleBg = Color(0xFFFFFFFF)

    /** The name capsule's top→bottom gradient (Figma badge-v2 ribbon), per tier. */
    fun capsuleBrush(tier: Tier): Brush = Brush.verticalGradient(
        when (tier) {
            Tier.SILVER -> listOf(Color(0xFFF3F4F6), Color(0xFF9CA3AF))
            Tier.GOLD -> listOf(Color(0xFFFFFBEB), Color(0xFFFDE68A))
            Tier.DIAMOND -> listOf(Color(0xFFF3F4F6), Color(0xFFBFDBFE))
            Tier.PINK_DIAMOND -> listOf(Color(0xFFFDE4EF), Color(0xFFF9AECF))
            Tier.BASIC, Tier.BASE, Tier.PRO, Tier.ELITE -> listOf(Color(0xFFF9FAFB), Color(0xFFAF9C9C))
        },
    )

    /** The capsule's tier-name text colour, per tier. */
    fun capsuleText(tier: Tier): Color = when (tier) {
        Tier.SILVER -> Color(0xFF374151)
        Tier.GOLD -> Color(0xFFB45309)
        Tier.DIAMOND -> Color(0xFF425C6A)
        Tier.PINK_DIAMOND -> Color(0xFFB31884)
        Tier.BASIC, Tier.BASE, Tier.PRO, Tier.ELITE -> Color(0xFF755E49)
    }

    // ── Job/coin nudge (pink) — Flutter `tierNudgePink*` / `tierNudgeText` ──
    val jobPinkBg = Color(0xFFFDE4EF)
    val jobPinkText = Color(0xFF374151)

    // ── Udaan intro banner (SnabbitUdaanBanner) — Flutter AppColors.udaanBanner* parity ──
    /** Footer (copy + CTA) section background. */
    val udaanBannerBg = Color(0xFFFEF1F7)
    /** 1px outer border. */
    val udaanBannerBorder = Color(0xFFF9AECF)
    /** Dark "View" / "Accept" CTA fill (white label via [onAccent]). */
    val udaanButtonBg = Color(0xFF1F2937)
    /** "Introducing Snabbit Udaan" title. */
    val udaanBannerTitle = Color(0xFF670632)
    /** "A new way to reward good work" subtitle. */
    val udaanBannerSubtitle = Color(0xFF4B5563)

    // ── Udaan post-intro "Play video" row (SnabbitUdaanPlayVideoRow) ──
    // The post-intro counterpart to the intro banner (shares [udaanButtonBg] +
    // [onAccent] for its dark pill). NOTE: Figma gives this card a WHITE bg — it
    // deliberately differs from the Flutter widget's gray `udaanPlayVideoBg`.
    /** White card background (Figma #FFFFFF). */
    val udaanPlayVideoBg = Color(0xFFFFFFFF)
    /** "Snabbit Udaan" row title (Figma #374151 = Flutter AppColors.udaanPlayVideoTitle parity). */
    val udaanPlayVideoTitle = Color(0xFF374151)

    // ── Neutral chrome shared across tiers ──
    /** "{Tier} Level" header label + coin count — white on the accent header. */
    val onAccent = Color(0xFFFFFFFF)
}

/**
 * Paints the profile tier card's three concentric decorative rings in the bottom-right
 * corner — a white→transparent vertical gradient at ~2% opacity (Figma "Ellipse 13868/69/70").
 * Identical across tiers. Call inside `drawBehind {}` AFTER [TierColors.cardRadialBrush];
 * overflow past the card is clipped by the surrounding rounded [Surface].
 *
 * Geometry is Figma-as-fractions-of-card-WIDTH: three ellipses (Ø 220.46 / 172.69 / 126.76
 * on the 361-wide frame) concentric at ≈ 85.6% across, 93.6% down.
 */
internal fun DrawScope.drawTierCardRings() {
    val cx = size.width * 0.856f
    val cy = size.height * 0.936f
    for (frac in floatArrayOf(0.305f, 0.239f, 0.176f)) {
        val r = size.width * frac
        drawCircle(
            brush = Brush.verticalGradient(
                colors = listOf(Color.White, Color.White.copy(alpha = 0f)),
                startY = cy - r,
                endY = cy + r,
            ),
            radius = r,
            center = Offset(cx, cy),
            alpha = 0.02f,
        )
    }
}
