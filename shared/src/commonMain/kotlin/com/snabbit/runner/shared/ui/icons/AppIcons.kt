package com.snabbit.runner.shared.ui.icons

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitColorsLight

/**
 * Exact design glyphs (from the Figma SVGs) that the DS `SnabbitIconName` set doesn't
 * carry — or renders with the wrong / an invisible glyph (Map, Chat, the accordion
 * chevron, the navigation-card customer & listen marks). Vendored app-side as
 * [ImageVector]s, mirroring the DS's own `snabbitGlyph` builder.
 *
 * Fills are baked from the DS palette ([SnabbitColorsLight]) so they render correctly via
 * `Image` (e.g. the non-square chevron). When passed to `SnabbitIcon(imageVector, color)`
 * the tint overrides the baked fill, so callers still pass the matching theme token.
 *
 * Long-term these belong in the DS `SnabbitIconName` set; kept here until they land there.
 */
internal object AppIcons {
    /** Person mark by the customer name (gray-900). */
    val Customer: ImageVector by lazy {
        glyph(16f, 16f, SnabbitColorsLight.gray900, CUSTOMER_HEAD, CUSTOMER_BODY)
    }

    /** Speaker mark in the "Listen" pill (gray-500). */
    val Listen: ImageVector by lazy { glyph(16f, 16f, SnabbitColorsLight.gray500, LISTEN) }

    /** Navigation / directions (paper-plane) action (brand pink). */
    val Map: ImageVector by lazy { glyph(20f, 20f, SnabbitColorsLight.pink600, MAP) }

    /** Call action (brand pink). */
    val Call: ImageVector by lazy { glyph(21f, 21f, SnabbitColorsLight.pink600, CALL) }

    /** Chat action (brand pink). */
    val Chat: ImageVector by lazy { glyph(21f, 21f, SnabbitColorsLight.pink600, CHAT) }

    /** Accordion collapsed-state chevron (points down, gray-400). Rendered 14×8 (non-square). */
    val ChevronDown: ImageVector by lazy { glyph(14f, 8f, SnabbitColorsLight.gray400, CHEVRON_DOWN) }

    /** Accordion expanded-state chevron (points up, gray-400). Rendered 14×8 (non-square). */
    val ChevronUp: ImageVector by lazy { glyph(14f, 8f, SnabbitColorsLight.gray400, CHEVRON_UP) }

    /**
     * "No internet" mark — three signal bars (red-600) crossed by an "X" (red-700). 32×32.
     * Multi-color, so render via foundation `Image` (NOT `SnabbitIcon`, which flattens it to a
     * single tint). Pairs with the connectivity banner's `bgErrorSubtle` wash.
     */
    val SignalOff: ImageVector by lazy {
        multiColorGlyph(
            32f, 32f,
            SIGNAL_BAR_1 to SnabbitColorsLight.red600,
            SIGNAL_BAR_2 to SnabbitColorsLight.red600,
            SIGNAL_BAR_3 to SnabbitColorsLight.red600,
            SIGNAL_X to SnabbitColorsLight.red700,
        )
    }

    /**
     * "Bad internet" mark — weak signal: the short bar filled (yellow-600), the taller two
     * faded (yellow-300). 32×32. Multi-color → render via foundation `Image`, not `SnabbitIcon`.
     */
    val SignalWeak: ImageVector by lazy {
        multiColorGlyph(
            32f, 32f,
            SIGNAL_BAR_1 to SnabbitColorsLight.yellow600,
            SIGNAL_BAR_2 to SnabbitColorsLight.yellow300,
            SIGNAL_BAR_3 to SnabbitColorsLight.yellow300,
        )
    }

    /** Chilli mark for the "Spice level" customer-preference row (gray-600). 16×16. */
    val SpiceLevel: ImageVector by lazy { glyph(16f, 16f, SnabbitColorsLight.gray600, SPICE_LEVEL) }

    /** Oil-drop mark for the "Oil level" customer-preference row (gray-600). 16×16. */
    val OilLevel: ImageVector by lazy { glyph(16f, 16f, SnabbitColorsLight.gray600, OIL_LEVEL) }

    /** Clock mark for the job-details "Job Timing" row (gray-600). 16×16. */
    val Clock: ImageVector by lazy { glyph(16f, 16f, SnabbitColorsLight.gray600, CLOCK) }

    /** Hourglass mark for the job-details "Duration" row (gray-600). 16×16. */
    val Hourglass: ImageVector by lazy { glyph(16f, 16f, SnabbitColorsLight.gray600, HOURGLASS) }

    /** Chef-hat glyph for the **Cook** New Job header (Figma 108:37873); the DS `SnabbitIconName`
     *  set has no ChefHat. Fill baked gray-900; the `SnabbitIcon(imageVector, color)` tint overrides
     *  it (callers pass `iconPrimary` to match the default spray-bottle expert glyph). 20×20.
     *  Note: source SVG's same-color stroke is dropped ([glyph] is fill-only) — negligible at 20dp. */
    val ServiceCook: ImageVector by lazy { glyph(20f, 20f, SnabbitColorsLight.gray900, SERVICE_COOK) }

    /**
     * "Block" / ban mark on the destructive block-customer CTA — a faint disc, a ring and a
     * diagonal slash, all gray-100 (#F3F4F6). Built directly (not via [glyph]) for the 20%-alpha
     * disc + stroked slash, and rendered via foundation `Image` (a single-tint `SnabbitIcon` would
     * flatten the faint disc). 20×20.
     */
    val Block: ImageVector by lazy { blockGlyph() }

    /**
     * 80×80 gradient alert mark (exclamation-in-a-circle) for the "unblock to block" header — an
     * orange linear gradient (#E16614 → #F9873B). The exclamation is a nonzero cut-out, so it shows
     * the surface behind (white on the block sheet). Gradient-filled → render via foundation `Image`.
     */
    val UnblockWarning: ImageVector by lazy { unblockWarningGlyph() }

    /**
     * 64×64 alert mark (exclamation-in-a-circle) for the general error state — filled red-600
     * (#DC2626). The alert keeps its own ~10-unit inset inside the 64 viewport, so rendering it at
     * full size inside the red-100 error badge reproduces `general_error_state_icon.svg`.
     */
    val AlertCircle: ImageVector by lazy { glyph(64f, 64f, SnabbitColorsLight.red600, ALERT_CIRCLE) }

    /**
     * 16×16 "job extended" mark — a green-600 clock with a green-600 "+" badge (Figma "Colored
     * Tooltip" 10:8540 / `job_extended_status_icon.svg`). The "+" carries a green-100 knockout stroke
     * so it reads against the clock. Baked colours → render via foundation `Image` (not `SnabbitIcon`).
     */
    val JobExtended: ImageVector by lazy { jobExtendedGlyph() }
}

/**
 * Builds an [ImageVector] from one or more raw SVG path strings at the given viewport,
 * filled with [fill]. [fill] is typed fully-qualified to avoid importing the DS-banned
 * `androidx.compose.ui.graphics.Color` on `:shared`.
 */
private fun glyph(
    width: Float,
    height: Float,
    fill: androidx.compose.ui.graphics.Color,
    vararg pathData: String,
): ImageVector {
    val brush: Brush = SolidColor(fill)
    return ImageVector.Builder(
        defaultWidth = width.dp,
        defaultHeight = height.dp,
        viewportWidth = width,
        viewportHeight = height,
    ).apply {
        pathData.forEach { addPath(PathParser().parsePathString(it).toNodes(), fill = brush) }
    }.build()
}

/**
 * Like [glyph] but with a per-path fill — for multi-color glyphs (e.g. the signal-bar icons,
 * where bars and the "X" overlay differ in shade). Because fills are baked per path, render
 * the result with foundation `Image` (a single-tint `SnabbitIcon` would override them).
 * [Pair.second] is typed fully-qualified to avoid importing the DS-banned
 * `androidx.compose.ui.graphics.Color` on `:shared`.
 */
private fun multiColorGlyph(
    width: Float,
    height: Float,
    vararg layers: Pair<String, androidx.compose.ui.graphics.Color>,
): ImageVector = ImageVector.Builder(
    defaultWidth = width.dp,
    defaultHeight = height.dp,
    viewportWidth = width,
    viewportHeight = height,
).apply {
    layers.forEach { (data, fill) ->
        addPath(PathParser().parsePathString(data).toNodes(), fill = SolidColor(fill))
    }
}.build()

/**
 * Builds the ban glyph: a faint disc (20% gray-100), a ring (donut → even-odd fill) and the 2dp
 * diagonal slash (stroked). Baked gray-100 to match the destructive CTA's content colour. [fill] is
 * typed fully-qualified to avoid importing the DS-banned `androidx.compose.ui.graphics.Color`.
 */
private fun blockGlyph(): ImageVector {
    val fill: androidx.compose.ui.graphics.Color = SnabbitColorsLight.gray100
    val brush: Brush = SolidColor(fill)
    return ImageVector.Builder(
        defaultWidth = 20f.dp,
        defaultHeight = 20f.dp,
        viewportWidth = 20f,
        viewportHeight = 20f,
    ).apply {
        addPath(PathParser().parsePathString(BLOCK_DISC).toNodes(), fill = brush, fillAlpha = 0.2f)
        addPath(
            PathParser().parsePathString(BLOCK_RING).toNodes(),
            pathFillType = PathFillType.EvenOdd,
            fill = brush,
        )
        addPath(
            PathParser().parsePathString(BLOCK_SLASH).toNodes(),
            stroke = brush,
            strokeLineWidth = 2f,
        )
    }.build()
}

/**
 * Builds the 80×80 gradient alert glyph (exclamation-in-a-circle) for the unblock-to-block header.
 * Filled with a linear gradient (#E16614 → #F9873B) matching the Figma export; the colours are
 * fully-qualified to avoid importing the DS-banned `androidx.compose.ui.graphics.Color`.
 */
private fun unblockWarningGlyph(): ImageVector {
    val brush: Brush = Brush.linearGradient(
        colors = listOf(
            androidx.compose.ui.graphics.Color(0xFFE16614),
            androidx.compose.ui.graphics.Color(0xFFF9873B),
        ),
        start = Offset(36.5f, 66f),
        end = Offset(56f, 8f),
    )
    return ImageVector.Builder(
        defaultWidth = 80f.dp,
        defaultHeight = 80f.dp,
        viewportWidth = 80f,
        viewportHeight = 80f,
    ).apply {
        addPath(PathParser().parsePathString(UNBLOCK_WARNING).toNodes(), fill = brush)
    }.build()
}

/**
 * Builds the 16×16 "job extended" glyph — a green-600 clock with a green-600 "+" badge; the badge
 * carries a green-100 stroke (the tooltip's bg) so it knocks out crisply where it overlaps the clock.
 * Baked colours → render with foundation `Image` (a single-tint `SnabbitIcon` would flatten them).
 */
private fun jobExtendedGlyph(): ImageVector {
    val fill: androidx.compose.ui.graphics.Color = SnabbitColorsLight.green600
    val knockout: androidx.compose.ui.graphics.Color = SnabbitColorsLight.green100
    return ImageVector.Builder(
        defaultWidth = 16f.dp,
        defaultHeight = 16f.dp,
        viewportWidth = 16f,
        viewportHeight = 16f,
    ).apply {
        addPath(PathParser().parsePathString(JOB_EXTENDED_CLOCK).toNodes(), fill = SolidColor(fill))
        addPath(
            PathParser().parsePathString(JOB_EXTENDED_PLUS).toNodes(),
            fill = SolidColor(fill),
            stroke = SolidColor(knockout),
            strokeLineWidth = 0.5f,
        )
    }.build()
}

// ── Raw SVG path data (verbatim from the design exports) ──────────────────────

// Job-extended clock+plus, 16×16 viewport — the two #059669 paths from `job_extended_status_icon.svg`
// (the "+" badge additionally strokes #D1FAE5 as a knockout). Rendered via [jobExtendedGlyph].
private const val JOB_EXTENDED_CLOCK =
    "M6.5 0.9375C5.21442 0.9375 3.95772 1.31872 2.8888 2.03295C1.81988 2.74718 0.986756 " +
        "3.76234 0.494786 4.95006C0.00281635 6.13778 -0.125905 7.44471 0.124899 " +
        "8.70559C0.375703 9.96646 0.994767 11.1247 1.90381 12.0337C2.81285 12.9427 3.97104 " +
        "13.5618 5.23192 13.8126C6.49279 14.0634 7.79973 13.9347 8.98744 13.4427C10.1752 " +
        "12.9507 11.1903 12.1176 11.9046 11.0487C12.6188 9.97979 13 8.72308 13 7.4375C12.9982 " +
        "5.71415 12.3128 4.06191 11.0942 2.84332C9.8756 1.62472 8.22335 0.93932 6.5 " +
        "0.9375ZM10 7.9375H6.5C6.36739 7.9375 6.24022 7.88482 6.14645 7.79105C6.05268 7.69729 " +
        "6 7.57011 6 7.4375V3.9375C6 3.80489 6.05268 3.67771 6.14645 3.58395C6.24022 3.49018 " +
        "6.36739 3.4375 6.5 3.4375C6.63261 3.4375 6.75979 3.49018 6.85356 3.58395C6.94732 " +
        "3.67771 7 3.80489 7 3.9375V6.9375H10C10.1326 6.9375 10.2598 6.99018 10.3536 " +
        "7.08395C10.4473 7.17771 10.5 7.30489 10.5 7.4375C10.5 7.57011 10.4473 7.69729 " +
        "10.3536 7.79105C10.2598 7.88482 10.1326 7.9375 10 7.9375Z"
private const val JOB_EXTENDED_PLUS =
    "M7.91797 12.1328C7.91797 11.7186 8.25376 11.3828 8.66797 11.3828L11.3047 " +
        "11.3828L11.3047 8.73437C11.3047 8.32016 11.6405 7.98437 12.0547 7.98437C12.4689 " +
        "7.98437 12.8047 8.32016 12.8047 8.73437L12.8047 11.3828L15.4492 11.3828C15.8634 " +
        "11.3828 16.1992 11.7186 16.1992 12.1328C16.1992 12.547 15.8634 12.8828 15.4492 " +
        "12.8828L12.8047 12.8828L12.8047 15.5156C12.8047 15.9298 12.4689 16.2656 12.0547 " +
        "16.2656C11.6405 16.2656 11.3047 15.9298 11.3047 15.5156L11.3047 12.8828L8.66797 " +
        "12.8828C8.25376 12.8828 7.91797 12.547 7.91797 12.1328Z"

// General-error alert-circle (exclamation-in-a-circle), 64×64 viewport — the #DC2626 path from the
// `general_error_state_icon.svg` export; the red-100 badge disc behind it is drawn in Compose.
private const val ALERT_CIRCLE =
    "M32.5495 10.3613C28.2642 10.3613 24.0752 11.6321 20.5121 14.0128C16.9491 16.3936 14.172 " +
        "19.7775 12.5321 23.7365C10.8922 27.6956 10.4631 32.052 11.2991 36.255C12.1352 40.4579 " +
        "14.1987 44.3185 17.2288 47.3486C20.259 50.3788 24.1196 52.4423 28.3225 53.2783C32.5255 " +
        "54.1144 36.8819 53.6853 40.841 52.0454C44.8 50.4055 48.1839 47.6284 50.5647 44.0653C52.9454 " +
        "40.5023 54.2162 36.3133 54.2162 32.028C54.2101 26.2835 51.9254 20.776 47.8634 16.714C43.8015 " +
        "12.6521 38.294 10.3674 32.5495 10.3613ZM32.5495 50.3613C28.9235 50.3613 25.3789 49.2861 " +
        "22.364 47.2716C19.3491 45.2571 16.9993 42.3938 15.6117 39.0439C14.2241 35.6939 13.861 " +
        "32.0077 14.5684 28.4513C15.2758 24.895 17.0219 21.6283 19.5859 19.0644C22.1498 16.5004 " +
        "25.4165 14.7543 28.9728 14.0469C32.5292 13.3395 36.2154 13.7026 39.5654 15.0902C42.9153 " +
        "16.4778 45.7786 18.8276 47.7931 21.8425C49.8076 24.8574 50.8828 28.402 50.8828 32.028C50.8773 " +
        "36.8886 48.944 41.5486 45.507 44.9855C42.0701 48.4225 37.4101 50.3558 32.5495 50.3613ZM30.8828 " +
        "33.6947V22.028C30.8828 21.586 31.0584 21.162 31.371 20.8495C31.6835 20.5369 32.1075 20.3613 " +
        "32.5495 20.3613C32.9915 20.3613 33.4154 20.5369 33.728 20.8495C34.0406 21.162 34.2162 21.586 " +
        "34.2162 22.028V33.6947C34.2162 34.1367 34.0406 34.5606 33.728 34.8732C33.4154 35.1857 32.9915 " +
        "35.3613 32.5495 35.3613C32.1075 35.3613 31.6835 35.1857 31.371 34.8732C31.0584 34.5606 30.8828 " +
        "34.1367 30.8828 33.6947ZM35.0495 41.1947C35.0495 41.6891 34.9029 42.1725 34.6282 42.5836C34.3535 " +
        "42.9947 33.963 43.3151 33.5062 43.5044C33.0494 43.6936 32.5467 43.7431 32.0618 43.6466C31.5768 " +
        "43.5502 31.1314 43.3121 30.7817 42.9624C30.4321 42.6128 30.194 42.1673 30.0975 41.6824C30.0011 " +
        "41.1974 30.0506 40.6948 30.2398 40.238C30.429 39.7811 30.7494 39.3907 31.1606 39.116C31.5717 " +
        "38.8413 32.055 38.6947 32.5495 38.6947C33.2125 38.6947 33.8484 38.9581 34.3173 39.4269C34.7861 " +
        "39.8957 35.0495 40.5316 35.0495 41.1947Z"

// Customer head modelled as a circle (cx 8.00049, cy 4.65674, r 2.46142) → two arcs.
private const val CUSTOMER_HEAD =
    "M5.53907 4.65674A2.46142 2.46142 0 1 0 10.46191 4.65674A2.46142 2.46142 0 1 0 5.53907 4.65674Z"
private const val CUSTOMER_BODY =
    "M12.9847 13.8004C13.4606 13.8004 13.8529 13.4126 13.7831 12.9419C13.6 11.7087 13.0259 10.5579 12.1338 9.66576C11.0372 8.56918 9.54989 7.95313 7.99909 7.95312C6.44828 7.95312 4.961 8.56918 3.86441 9.66576C2.97226 10.5579 2.39817 11.7087 2.21512 12.9419C2.14526 13.4126 2.53755 13.8004 3.01343 13.8004L12.9847 13.8004Z"

private const val LISTEN =
    "M10.5 1.99963V13.9996C10.4999 14.0932 10.4736 14.1848 10.424 14.2642C10.3745 14.3435 10.3036 14.4074 10.2196 14.4485C10.1355 14.4895 10.0416 14.5062 9.94855 14.4966C9.85548 14.487 9.76699 14.4514 9.69312 14.394L5.32812 10.9996H2.5C2.23478 10.9996 1.98043 10.8943 1.79289 10.7067C1.60536 10.5192 1.5 10.2648 1.5 9.99963V5.99963C1.5 5.73441 1.60536 5.48006 1.79289 5.29252C1.98043 5.10498 2.23478 4.99963 2.5 4.99963H5.32812L9.69312 1.60525C9.76699 1.54783 9.85548 1.51228 9.94855 1.50265C10.0416 1.49303 10.1355 1.5097 10.2196 1.55079C10.3036 1.59187 10.3745 1.65571 10.424 1.73506C10.4736 1.8144 10.4999 1.90607 10.5 1.99963ZM12.5 5.99963C12.3674 5.99963 12.2402 6.0523 12.1464 6.14607C12.0527 6.23984 12 6.36702 12 6.49963V9.49963C12 9.63223 12.0527 9.75941 12.1464 9.85318C12.2402 9.94695 12.3674 9.99963 12.5 9.99963C12.6326 9.99963 12.7598 9.94695 12.8536 9.85318C12.9473 9.75941 13 9.63223 13 9.49963V6.49963C13 6.36702 12.9473 6.23984 12.8536 6.14607C12.7598 6.0523 12.6326 5.99963 12.5 5.99963ZM14.5 4.99963C14.3674 4.99963 14.2402 5.0523 14.1464 5.14607C14.0527 5.23984 14 5.36702 14 5.49963V10.4996C14 10.6322 14.0527 10.7594 14.1464 10.8532C14.2402 10.9469 14.3674 10.9996 14.5 10.9996C14.6326 10.9996 14.7598 10.9469 14.8536 10.8532C14.9473 10.7594 15 10.6322 15 10.4996V5.49963C15 5.36702 14.9473 5.23984 14.8536 5.14607C14.7598 5.0523 14.6326 4.99963 14.5 4.99963Z"

private const val SERVICE_COOK =
    "M3.99902 10.9033L3.51074 10.7432C1.92543 10.2211 0.782227 8.727 0.782227 6.96875C0.782459 4.77538 2.56146 2.99707 4.75488 2.99707C5.09976 2.99708 5.43308 3.04128 5.75 3.12305L6.28516 3.26074L6.55078 2.77637C7.22663 1.54374 8.53451 0.709998 10.0361 0.709961C10.7515 0.709961 11.4214 0.900612 12.001 1.23145C11.5331 1.51023 11.1006 1.84662 10.7139 2.2334C10.1023 2.84501 9.61633 3.57066 9.28516 4.37012C9.07388 4.88019 8.92755 5.41384 8.84961 5.95801L8.82129 6.19238C8.73437 7.00625 9.40459 7.60156 10.1191 7.60156C10.8768 7.6015 11.404 6.99858 11.4902 6.36426C11.5355 6.03123 11.6237 5.70457 11.7529 5.39258C11.9498 4.91742 12.2387 4.48591 12.6025 4.12207C12.9664 3.75824 13.3979 3.4693 13.873 3.27246C14.0211 3.21116 14.1724 3.15883 14.3262 3.11621C14.4909 3.07417 14.6702 3.04421 14.8643 3.02246H14.8652C15.0133 3.00562 15.1644 2.99708 15.3174 2.99707C17.5108 2.99707 19.2898 4.77538 19.29 6.96875C19.29 8.72682 18.1468 10.221 16.5615 10.7432L16.0732 10.9033V14.3818H8.90625C8.12159 14.3819 7.48535 15.0181 7.48535 15.8027C7.48553 16.5873 8.1217 17.2236 8.90625 17.2236H16.0732V19.29H3.99902V10.9033Z"

private const val MAP =
    "M2.22992 8.59777L15.7928 2.84991C16.8803 2.38903 17.9318 3.36956 17.548 4.48654L12.7609 18.4176C12.3271 19.6798 10.5821 19.7813 10.1668 18.5685L8.39998 13.4091C8.26257 13.0078 7.94051 12.7075 7.53057 12.5984L2.26041 11.1961C1.02156 10.8664 1.00102 9.11857 2.22992 8.59777Z"

private const val CALL =
    "M17.4168 13.5247L13.5891 11.8095L13.5785 11.8047C13.3798 11.7197 13.1631 11.6856 12.9479 11.7054C12.7326 11.7253 12.5258 11.7985 12.346 11.9184C12.3248 11.9324 12.3045 11.9476 12.285 11.9639L10.3074 13.6498C9.05454 13.0413 7.76104 11.7575 7.15248 10.5209L8.84085 8.51322C8.8571 8.49291 8.87254 8.47259 8.88717 8.45066C9.00451 8.27134 9.07571 8.06579 9.09442 7.85231C9.11313 7.63882 9.07878 7.42403 8.99442 7.22703V7.21728L7.27435 3.38309C7.16283 3.12574 6.97107 2.91137 6.72769 2.77196C6.48432 2.63255 6.20238 2.5756 5.92398 2.60959C4.82301 2.75447 3.81243 3.29515 3.08098 4.13067C2.34953 4.96619 1.94724 6.03939 1.94923 7.14984C1.94923 13.6011 7.19798 18.8498 13.6492 18.8498C14.7597 18.8518 15.8329 18.4495 16.6684 17.7181C17.5039 16.9866 18.0446 15.9761 18.1895 14.8751C18.2235 14.5968 18.1667 14.3149 18.0274 14.0716C17.8882 13.8282 17.674 13.6364 17.4168 13.5247Z"

private const val CHAT =
    "M17.5492 3.89999H3.24924C2.90446 3.89999 2.5738 4.03696 2.33 4.28076C2.08621 4.52455 1.94924 4.85521 1.94924 5.19999V18.2C1.94774 18.4479 2.01787 18.691 2.1512 18.8999C2.28452 19.1089 2.47537 19.275 2.70081 19.3781C2.87259 19.4581 3.05975 19.4997 3.24924 19.5C3.55442 19.4993 3.84947 19.3905 4.08206 19.1929L4.08937 19.1872L6.74299 16.9H17.5492C17.894 16.9 18.2247 16.763 18.4685 16.5192C18.7123 16.2754 18.8492 15.9448 18.8492 15.6V5.19999C18.8492 4.85521 18.7123 4.52455 18.4685 4.28076C18.2247 4.03696 17.894 3.89999 17.5492 3.89999ZM12.9992 12.35H7.79924C7.62685 12.35 7.46152 12.2815 7.33962 12.1596C7.21773 12.0377 7.14924 11.8724 7.14924 11.7C7.14924 11.5276 7.21773 11.3623 7.33962 11.2404C7.46152 11.1185 7.62685 11.05 7.79924 11.05H12.9992C13.1716 11.05 13.337 11.1185 13.4589 11.2404C13.5808 11.3623 13.6492 11.5276 13.6492 11.7C13.6492 11.8724 13.5808 12.0377 13.4589 12.1596C13.337 12.2815 13.1716 12.35 12.9992 12.35ZM12.9992 9.74999H7.79924C7.62685 9.74999 7.46152 9.68151 7.33962 9.55961C7.21773 9.43772 7.14924 9.27239 7.14924 9.09999C7.14924 8.9276 7.21773 8.76227 7.33962 8.64038C7.46152 8.51848 7.62685 8.44999 7.79924 8.44999H12.9992C13.1716 8.44999 13.337 8.51848 13.4589 8.64038C13.5808 8.76227 13.6492 8.9276 13.6492 9.09999C13.6492 9.27239 13.5808 9.43772 13.4589 9.55961C13.337 9.68151 13.1716 9.74999 12.9992 9.74999Z"

// Chevrons — 14×8. Scientific-notation zeros (`4.76837e-07`) normalised to 0.
private const val CHEVRON_DOWN =
    "M0.182465 1.06754L6.43246 7.31754C6.49051 7.37565 6.55944 7.42175 6.63531 7.4532C6.71119 7.48465 6.79252 7.50084 6.87465 7.50084C6.95679 7.50084 7.03812 7.48465 7.11399 7.4532C7.18986 7.42175 7.25879 7.37565 7.31684 7.31754L13.5668 1.06754C13.6841 0.95026 13.75 0.7912 13.75 0.625347C13.75 0.459495 13.6841 0.300435 13.5668 0.18316C13.4496 0.0658843 13.2905 0 13.1247 0C12.9588 0 12.7997 0.0658843 12.6825 0.18316L6.87465 5.99175L1.06684 0.18316C1.00877 0.125091 0.939833 0.0790281 0.863962 0.0476015C0.788092 0.0161748 0.706774 0 0.624652 0C0.54253 0 0.461212 0.0161748 0.385342 0.0476015C0.309471 0.0790281 0.240533 0.125091 0.182465 0.18316C0.124395 0.241229 0.0783329 0.310167 0.0469065 0.386037C0.01548 0.461908 -0.000696182 0.543226 -0.000696182 0.625347C-0.000696182 0.707469 0.01548 0.788787 0.0469065 0.864658C0.0783329 0.940528 0.124395 1.00947 0.182465 1.06754Z"
private const val CHEVRON_UP =
    "M0.182465 6.4333L6.43246 0.183304C6.49051 0.125194 6.55944 0.0790939 6.63531 0.0476413C6.71119 0.0161886 6.79252 0 6.87465 0C6.95679 0 7.03812 0.0161886 7.11399 0.0476413C7.18986 0.0790939 7.25879 0.125194 7.31684 0.183304L13.5668 6.4333C13.6841 6.55058 13.75 6.70964 13.75 6.87549C13.75 7.04134 13.6841 7.2004 13.5668 7.31768C13.4496 7.43495 13.2905 7.50084 13.1247 7.50084C12.9588 7.50084 12.7997 7.43495 12.6825 7.31768L6.87465 1.50909L1.06684 7.31768C1.00877 7.37575 0.939833 7.42181 0.863962 7.45324C0.788092 7.48466 0.706774 7.50084 0.624652 7.50084C0.54253 7.50084 0.461212 7.48466 0.385342 7.45324C0.309471 7.42181 0.240533 7.37575 0.182465 7.31768C0.124395 7.25961 0.0783329 7.19067 0.0469065 7.1148C0.01548 7.03893 -0.000696182 6.95761 -0.000696182 6.87549C-0.000696182 6.79337 0.01548 6.71205 0.0469065 6.63618C0.0783329 6.56031 0.124395 6.49137 0.182465 6.4333Z"

// Signal-bar icons (32×32). Bars are rects expressed as line paths (shared by SignalOff &
// SignalWeak); SIGNAL_X is the exported no-signal overlay. Geometry verbatim from the Figma SVG.
private const val SIGNAL_BAR_1 =
    "M8.66667 18.7708L12.66667 18.7708L12.66667 24.66663L8.66667 24.66663Z"
private const val SIGNAL_BAR_2 =
    "M15.3333 12.7292L19.3333 12.7292L19.3333 24.6615L15.3333 24.6615Z"
private const val SIGNAL_BAR_3 =
    "M22 7.33333L26 7.33333L26 24.66663L22 24.66663Z"
private const val SIGNAL_X =
    "M12.9355 7.7334C13.1124 7.7334 13.2822 7.80365 13.4072 7.92871C13.5323 8.05377 13.6025 8.22353 13.6025 8.40039C13.6025 8.57718 13.5322 8.74706 13.4072 8.87207L10.2783 12L13.4072 15.1279C13.4692 15.1899 13.5182 15.2638 13.5518 15.3447C13.5852 15.4256 13.6025 15.5121 13.6025 15.5996C13.6025 15.6872 13.5853 15.7746 13.5518 15.8555C13.5183 15.9362 13.469 16.0095 13.4072 16.0713C13.3454 16.1331 13.2721 16.1823 13.1914 16.2158C13.1105 16.2493 13.0231 16.2666 12.9355 16.2666C12.8481 16.2666 12.7615 16.2493 12.6807 16.2158C12.5998 16.1823 12.5258 16.1332 12.4639 16.0713L9.33594 12.9424L6.20801 16.0713C6.08299 16.1963 5.91312 16.2666 5.73633 16.2666C5.55947 16.2666 5.38971 16.1963 5.26465 16.0713C5.13959 15.9462 5.06934 15.7765 5.06934 15.5996C5.06939 15.4228 5.13963 15.2529 5.26465 15.1279L8.39258 12L5.26465 8.87207C5.13963 8.74706 5.06939 8.57718 5.06934 8.40039C5.06934 8.22353 5.13959 8.05377 5.26465 7.92871C5.38971 7.80365 5.55947 7.7334 5.73633 7.7334C5.86906 7.73344 5.99766 7.77306 6.10645 7.8457L6.20801 7.92871L9.33594 11.0566L12.4639 7.92871C12.5889 7.8037 12.7588 7.73345 12.9355 7.7334Z"

// Customer-preference row glyphs (16×16, gray-600). Verbatim from the Figma export; the chilli
// is already mirrored in the exported path (Figma applies the flip), so no runtime transform.
private const val SPICE_LEVEL =
    "M10.4538 2.52625C10.343 1.95632 10.0377 1.44259 9.58995 1.07296C9.14223 0.703333 8.57996 0.500793 7.99938 0.5C7.86677 0.5 7.73959 0.552678 7.64582 0.646447C7.55206 0.740215 7.49938 0.867392 7.49938 1C7.49938 1.13261 7.55206 1.25979 7.64582 1.35355C7.73959 1.44732 7.86677 1.5 7.99938 1.5C8.317 1.5 8.62643 1.60083 8.88308 1.78795C9.13974 1.97508 9.33036 2.23884 9.4275 2.54125C8.47606 2.67974 7.60619 3.15588 6.97678 3.88271C6.34738 4.60953 6.00045 5.53853 5.99938 6.5C5.99938 9.42188 4.39 11.375 1.21625 12.3125C0.999162 12.3758 0.809927 12.5108 0.679428 12.6954C0.548929 12.8801 0.484871 13.1036 0.497707 13.3293C0.510543 13.5551 0.599516 13.7698 0.750107 13.9385C0.900697 14.1072 1.10401 14.2199 1.32688 14.2581C2.26627 14.4205 3.21793 14.5014 4.17125 14.5C6.72 14.5 9.55625 13.9281 11.5169 12.2837C13.1644 10.9025 13.9994 8.95625 13.9994 6.5C13.9983 5.51815 13.6366 4.57089 12.9829 3.83827C12.3292 3.10565 11.4291 2.63873 10.4538 2.52625ZM11.9994 5.9375L10.2231 5.05188C10.1537 5.01711 10.0771 4.99902 9.99938 4.99902C9.9217 4.99902 9.84509 5.01711 9.77563 5.05188L7.99938 5.9375L7.16375 5.52C7.3675 4.93009 7.75016 4.41841 8.25843 4.05623C8.7667 3.69405 9.37527 3.4994 9.99938 3.4994C10.6235 3.4994 11.2321 3.69405 11.7403 4.05623C12.2486 4.41841 12.6313 4.93009 12.835 5.52L11.9994 5.9375Z"
private const val OIL_LEVEL =
    "M10.875 2.98423C10.103 2.09263 9.23409 1.28977 8.28438 0.590485C8.20031 0.531592 8.10015 0.5 7.9975 0.5C7.89485 0.5 7.7947 0.531592 7.71063 0.590485C6.76266 1.29006 5.89545 2.09291 5.125 2.98423C3.40688 4.95736 2.5 7.03736 2.5 8.99986C2.5 10.4586 3.07946 11.8575 4.11091 12.8889C5.14236 13.9204 6.54131 14.4999 8 14.4999C9.45869 14.4999 10.8576 13.9204 11.8891 12.8889C12.9205 11.8575 13.5 10.4586 13.5 8.99986C13.5 7.03736 12.5931 4.95736 10.875 2.98423ZM11.4906 9.58361C11.361 10.3078 11.0126 10.9749 10.4923 11.495C9.972 12.0152 9.30484 12.3635 8.58062 12.493C8.55396 12.4973 8.52701 12.4996 8.5 12.4999C8.37458 12.4998 8.25375 12.4527 8.16148 12.3677C8.06921 12.2828 8.01223 12.1662 8.00185 12.0413C7.99146 11.9163 8.02843 11.7919 8.10542 11.6929C8.18242 11.5939 8.2938 11.5275 8.4175 11.5067C9.45312 11.3324 10.3319 10.4536 10.5075 9.41611C10.5297 9.28533 10.603 9.16872 10.7112 9.09195C10.8193 9.01517 10.9536 8.98452 11.0844 9.00673C11.2152 9.02895 11.3318 9.1022 11.4085 9.21039C11.4853 9.31857 11.516 9.45282 11.4937 9.58361H11.4906Z"

// Job-details row glyphs (16×16, gray-600). Verbatim from the Figma export.
private const val CLOCK =
    "M8 1.5C6.71442 1.5 5.45772 1.88122 4.3888 2.59545C3.31988 3.30968 2.48676 4.32484 1.99479 5.51256C1.50282 6.70028 1.37409 8.00721 1.6249 9.26809C1.8757 10.529 2.49477 11.6872 3.40381 12.5962C4.31285 13.5052 5.47104 14.1243 6.73192 14.3751C7.99279 14.6259 9.29973 14.4972 10.4874 14.0052C11.6752 13.5132 12.6903 12.6801 13.4046 11.6112C14.1188 10.5423 14.5 9.28558 14.5 8C14.4982 6.27665 13.8128 4.62441 12.5942 3.40582C11.3756 2.18722 9.72335 1.50182 8 1.5ZM11.5 8.5H8C7.86739 8.5 7.74022 8.44732 7.64645 8.35355C7.55268 8.25979 7.5 8.13261 7.5 8V4.5C7.5 4.36739 7.55268 4.24021 7.64645 4.14645C7.74022 4.05268 7.86739 4 8 4C8.13261 4 8.25979 4.05268 8.35356 4.14645C8.44732 4.24021 8.5 4.36739 8.5 4.5V7.5H11.5C11.6326 7.5 11.7598 7.55268 11.8536 7.64645C11.9473 7.74021 12 7.86739 12 8C12 8.13261 11.9473 8.25979 11.8536 8.35355C11.7598 8.44732 11.6326 8.5 11.5 8.5Z"
private const val HOURGLASS =
    "M12.5 4.7275V2.5C12.5 2.23478 12.3946 1.98043 12.2071 1.79289C12.0196 1.60536 11.7652 1.5 11.5 1.5H4.5C4.23478 1.5 3.98043 1.60536 3.79289 1.79289C3.60536 1.98043 3.5 2.23478 3.5 2.5V4.75C3.50034 4.90519 3.53663 5.05818 3.60603 5.19698C3.67543 5.33579 3.77605 5.45662 3.9 5.55L7.16687 8L3.9 10.45C3.77605 10.5434 3.67543 10.6642 3.60603 10.803C3.53663 10.9418 3.50034 11.0948 3.5 11.25V13.5C3.5 13.7652 3.60536 14.0196 3.79289 14.2071C3.98043 14.3946 4.23478 14.5 4.5 14.5H11.5C11.7652 14.5 12.0196 14.3946 12.2071 14.2071C12.3946 14.0196 12.5 13.7652 12.5 13.5V11.2725C12.4996 11.1179 12.4637 10.9655 12.3948 10.8271C12.326 10.6886 12.2262 10.568 12.1031 10.4744L8.82938 8L12.1031 5.52563C12.2262 5.43205 12.326 5.31136 12.3948 5.17294C12.4637 5.03452 12.4996 4.88209 12.5 4.7275ZM11.5 2.5V4H4.5V2.5H11.5ZM11.5 13.5H4.5V11.25L8 8.625L11.5 11.2719V13.5Z"

// Block / ban glyph (20×20, gray-100). Verbatim from the Figma export (node 13:9921): the disc is
// a 20%-alpha fill, the ring a donut filled even-odd, the slash a 2dp stroked line.
private const val BLOCK_DISC =
    "M17.5 10C17.5 11.4834 17.0601 12.9334 16.236 14.1668C15.4119 15.4001 14.2406 16.3614 12.8701 16.9291C11.4997 17.4968 9.99168 17.6453 8.53683 17.3559C7.08197 17.0665 5.7456 16.3522 4.6967 15.3033C3.64781 14.2544 2.9335 12.918 2.64411 11.4632C2.35472 10.0083 2.50325 8.50032 3.07091 7.12987C3.63856 5.75943 4.59986 4.58809 5.83323 3.76398C7.0666 2.93987 8.51664 2.5 10 2.5C11.9891 2.5 13.8968 3.29018 15.3033 4.6967C16.7098 6.10322 17.5 8.01088 17.5 10Z"
private const val BLOCK_RING =
    "M10 1.6748C12.2072 1.67714 14.3231 2.55552 15.8838 4.11621C17.4445 5.67691 18.3229 7.79284 18.3252 10L18.3193 10.3086C18.2623 11.847 17.7794 13.3416 16.9219 14.625C16.0071 15.994 14.7067 17.0613 13.1855 17.6914C11.6645 18.3214 9.99074 18.4862 8.37598 18.165C6.76108 17.8438 5.27755 17.051 4.11328 15.8867C2.94901 14.7224 2.15618 13.2389 1.83496 11.624C1.51379 10.0093 1.67861 8.33554 2.30859 6.81445C2.93869 5.29326 4.00596 3.99289 5.375 3.07812C6.74403 2.16338 8.35348 1.67481 10 1.6748ZM12.5547 3.83301C11.3351 3.32785 9.99292 3.1957 8.69824 3.45312C7.40342 3.71068 6.21379 4.34676 5.28027 5.28027C4.34676 6.21379 3.71068 7.40342 3.45312 8.69824C3.1957 9.99292 3.32786 11.3351 3.83301 12.5547C4.33823 13.7743 5.19435 14.8164 6.29199 15.5498C7.38965 16.2832 8.67988 16.6748 10 16.6748L10.3311 16.666C11.9801 16.5823 13.5447 15.8909 14.7178 14.7178C15.9691 13.4664 16.6727 11.7697 16.6748 10L16.6709 9.75293C16.6252 8.51936 16.2374 7.32107 15.5498 6.29199C14.8164 5.19435 13.7743 4.33823 12.5547 3.83301Z"
private const val BLOCK_SLASH =
    "M4.70711 4.29289L15.4054 14.9912"

// Unblock-to-block header alert (80×80). Verbatim from the Figma export (node 13:12130); the
// exclamation is a nonzero cut-out of the gradient-filled circle.
private const val UNBLOCK_WARNING =
    "M40 72.5C22.0503 72.5 7.5 57.9497 7.5 40C7.5 22.0503 22.0503 7.5 40 7.5C57.9497 7.5 72.5 22.0535 72.5 40C72.5 57.9465 57.9497 72.5 40 72.5ZM40 23.75C39.138 23.75 38.3114 24.0924 37.7019 24.7019C37.0924 25.3114 36.75 26.138 36.75 27V43.25C36.75 44.112 37.0924 44.9386 37.7019 45.5481C38.3114 46.1576 39.138 46.5 40 46.5C40.862 46.5 41.6886 46.1576 42.2981 45.5481C42.9076 44.9386 43.25 44.112 43.25 43.25V27C43.25 26.138 42.9076 25.3114 42.2981 24.7019C41.6886 24.0924 40.862 23.75 40 23.75ZM40 56.25C40.862 56.25 41.6886 55.9076 42.2981 55.2981C42.9076 54.6886 43.25 53.862 43.25 53C43.25 52.138 42.9076 51.3114 42.2981 50.7019C41.6886 50.0924 40.862 49.75 40 49.75C39.138 49.75 38.3114 50.0924 37.7019 50.7019C37.0924 51.3114 36.75 52.138 36.75 53C36.75 53.862 37.0924 54.6886 37.7019 55.2981C38.3114 55.9076 39.138 56.25 40 56.25Z"
