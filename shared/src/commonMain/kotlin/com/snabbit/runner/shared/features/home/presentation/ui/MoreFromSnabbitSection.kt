package com.snabbit.runner.shared.features.home.presentation.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.home.domain.model.Banner
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.home_banner_refer_fallback
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import org.jetbrains.compose.resources.painterResource

/**
 * "More From Snabbit" section: header + BE-driven promo banners.
 *
 * One banner → a single full-width row. Two or more → an auto-scrolling
 * **circular** [HorizontalPager] with a trailing peek (the next card's leading
 * edge stays visible — the "there's more" affordance) and dot indicators.
 * Pattern copy of `ProfileNudgeCarousel`; the auto-advance is the one addition
 * (a [LaunchedEffect] ticker that skips while the user is dragging).
 *
 * Banner is intentionally product-shaped (bg image, copy, click path) — stays
 * local; not promoted to `design_ext` because there's no DS parent.
 */
@Composable
fun MoreFromSnabbitSection(
    banners: List<Banner>,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
    /** First-fetch in flight — render a shimmer card instead of banners. */
    isLoading: Boolean = false,
) {
    if (banners.isEmpty() && !isLoading) return
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = SnabbitTheme.spacing.layoutPaddingSm),
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
    ) {
        // Figma: Body-M/16-Semibold. Compose's BodyMd is 14sp (naming drift
        // from Figma); BodyLg is 16sp/Normal. Override fontWeight to SemiBold.
        SnabbitText(
            text = strings.moreFromSnabbitHeader,
            variant = SnabbitTextVariant.BodyLg,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textPrimary,
        )
        when {
            banners.isEmpty() -> BannerShimmer() // isLoading — full-card silhouette
            banners.size == 1 -> {
                val banner = banners.first()
                BannerRow(banner = banner, onClick = { onIntent(HomeUiIntent.TapBanner(banner.id)) })
            }
            else -> BannerCarousel(banners = banners, onIntent = onIntent)
        }
    }
}

/** Banner-card silhouette with the sweeping shimmer fill ([shimmer] — shared
 *  with [HomeHeroShimmer]) — same size/shape as [BannerRow] so nothing jumps
 *  when the fetched banner replaces it. */
@Composable
private fun BannerShimmer() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(150.dp)
            .clip(RoundedCornerShape(SnabbitTheme.borderRadius.xl))
            .shimmer(),
    )
}

/**
 * Circular auto-scrolling pager. Huge virtual page count started mid-range on
 * a real-index boundary (the `ProfileNudgeCarousel` trick) so swiping and the
 * auto-advance wrap both ways forever — the peek is always filled and
 * last → first animates forward, never jump-scrolls back.
 */
@Composable
private fun BannerCarousel(
    banners: List<Banner>,
    onIntent: (HomeUiIntent) -> Unit,
) {
    val pageCount = banners.size
    val startPage = (Int.MAX_VALUE / 2).let { it - it % pageCount }
    val pagerState = rememberPagerState(initialPage = startPage, pageCount = { Int.MAX_VALUE })

    // Auto-advance ticker. Skips a beat while the user is dragging (never
    // fights the finger) and resumes from wherever they left the pager.
    // Cancels with composition — no work once Home leaves the screen.
    LaunchedEffect(pageCount) {
        while (true) {
            delay(AutoScrollIntervalMs)
            if (!pagerState.isScrollInProgress) {
                try {
                    pagerState.animateScrollToPage(pagerState.currentPage + 1)
                } catch (e: CancellationException) {
                    // A touch landing mid-animation makes the pager's MutatorMutex
                    // cancel this scroll — that must not kill the ticker loop.
                    // ensureActive() rethrows only if the EFFECT itself was
                    // cancelled (composition left), preserving real cancellation.
                    currentCoroutineContext().ensureActive()
                }
            }
        }
    }

    Column(
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        HorizontalPager(
            state = pagerState,
            contentPadding = PaddingValues(end = BannerPeek),
            pageSpacing = SnabbitTheme.spacing.layoutPaddingSm,
            modifier = Modifier.fillMaxWidth(),
        ) { page ->
            val banner = banners[page % pageCount]
            BannerRow(banner = banner, onClick = { onIntent(HomeUiIntent.TapBanner(banner.id)) })
        }
        // Horizontal line indicator: grey rounded track, a brand segment
        // (1/pageCount of the track) slides to the active page.
        val activeIndex = pagerState.currentPage % pageCount
        val segmentWidth = IndicatorTrackWidth / pageCount
        val segmentOffset by animateDpAsState(
            targetValue = segmentWidth * activeIndex,
            label = "bannerIndicatorOffset",
        )
        Box(
            modifier = Modifier
                .width(IndicatorTrackWidth)
                .height(IndicatorHeight)
                .clip(CircleShape)
                .background(SnabbitTheme.colors.bgNeutralMuted),
        ) {
            Box(
                modifier = Modifier
                    .offset(x = segmentOffset)
                    .width(segmentWidth)
                    .fillMaxHeight()
                    .clip(CircleShape)
                    .background(SnabbitTheme.colors.bgBrand),
            )
        }
    }
}

@Composable
private fun BannerRow(banner: Banner, onClick: () -> Unit) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    // ponytail: 18.dp not in spacing tokens (Figma uses 18 for banner inset).
    // Closest token is layoutPaddingSm (16) — kept at 18 to match design.
    val bannerInset = 18.dp
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(150.dp)
            .clip(shape)
            // Neutral placeholder — visible until the bg image loads (and the
            // permanent look for the blank-bgImageUrl Refer fallback). Dark so
            // the textInverse copy stays legible either way.
            .background(SnabbitTheme.colors.bgNeutralStrong, shape)
            // Card is the single semantic tap target for TalkBack; the CTA
            // label doubles as its action label.
            .clickable(onClick = onClick, role = Role.Button, onClickLabel = banner.ctaLabel),
    ) {
        // BE-driven background; the bundled Refer artwork backs the fallback
        // banner (blank URL) so the card looks real even fully offline. A
        // failed remote load leaves the neutral placeholder above intact.
        if (banner.bgImageUrl.isBlank()) {
            Image(
                painter = painterResource(Res.drawable.home_banner_refer_fallback),
                contentDescription = null, // decorative — the copy below carries meaning
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            SnabbitRemoteImage(
                model = banner.bgImageUrl,
                contentDescription = null, // decorative — the copy below carries meaning
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }
        Column(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(bannerInset),
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs),
        ) {
            // Figma: Outfit/SemiBold/16.9. BodyLg (16) + SemiBold override.
            SnabbitText(
                text = banner.title,
                variant = SnabbitTextVariant.BodyLg,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textInverse,
            )
            // Figma: Outfit/Bold/26.3. Heading2 is 24/SemiBold; weight → Bold.
            banner.subtitle?.let { subtitle ->
                SnabbitText(
                    text = subtitle,
                    variant = SnabbitTextVariant.Heading2,
                    fontWeight = FontWeight.Bold,
                    color = SnabbitTheme.colors.textInverse,
                )
            }
        }
        Box(modifier = Modifier.align(Alignment.BottomStart).padding(bannerInset)) {
            // White pill + steel-blue label. Figma asks #296A90 — not in the
            // DS palette; closest token DS 0.16 exposes is textNeutralShadow
            // (#1D4366). teal500 (#4089B7) is nearer but ships in a later DS —
            // swap when the dependency moves.
            SnabbitButton(
                text = banner.ctaLabel,
                onClick = onClick,
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.XS,
                containerColor = SnabbitTheme.colors.bgPrimary,
                contentColor = SnabbitTheme.colors.textNeutralShadow,
                // BE-driven CTA icon (`button_icon`). Leading per the promo
                // mock (icon-then-label); 16.dp matches SafetyHomeCard's
                // in-button icon on the same XS/S sizes.
                leadingIcon = banner.ctaIconUrl?.let { iconUrl ->
                    {
                        SnabbitRemoteImage(
                            model = iconUrl,
                            contentDescription = null, // decorative — label carries meaning
                            modifier = Modifier.size(16.dp),
                        )
                    }
                },
            )
        }
    }
}

/** Carousel auto-advance cadence. [ASSUMPTION] 4s — confirm with design. */
private const val AutoScrollIntervalMs = 4_000L

// ponytail: peek width mirrors ProfileNudgeCarousel's proven 58dp (visible peek
// ≈ peek − pageSpacing); swap for the Figma value when the banner spec lands.
private val BannerPeek = 58.dp

// ponytail: indicator dims eyeballed from the promo mock (track ≈ quarter of
// the card width, 4dp tall) — swap for Figma values / a DS indicator atom
// when either lands.
private val IndicatorTrackWidth = 96.dp
private val IndicatorHeight = 4.dp
