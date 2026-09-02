package com.snabbit.runner.shared.features.kavach.shared.designgaps

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * DESIGN-SYSTEM GAP REGISTRY for the Kavach/SOS surfaces.
 *
 * Policy (per product decision): Kavach UI consumes Snabbit DS components + tokens ONLY. A raw metric
 * or color lands here ONLY when the DS genuinely cannot express a Figma value — it must never be
 * inlined in a component file. Every entry cites its Figma node so it can be promoted into the DS
 * (SnabbitSpacing / SnabbitColors / a new component) later and then deleted from here.
 *
 * Keep this the single home for such gaps. One `object` per surface keeps them scannable.
 */
object KavachDesignGaps {

    /** Battery-low sheet — Figma node 19-17075 (frame `19:17639`). */
    object BatterySheet {
        /** Battery illustration width as a fraction of the sheet (Figma 122 on the 393-wide frame).
         *  The header bg is full-bleed (fillMaxWidth, natural height) and the illustration scales
         *  with screen width — no fixed dp, so nothing crops on narrow/wide devices. */
        val iconWidthFraction: Float = 0.31f
    }

    /** SOS confirmation sheet — Figma node 421-18176 (child `2417:19705`). */
    object SosConfirmSheet {
        /** Gap between the title and the button group (Figma 41px) — spacing scale jumps 40→48. */
        val titleToButtonsGap: Dp = 41.dp
        /** Siren illustration (Figma `2417:19735`, 138.31×130) — bespoke asset dims. */
        val sirenWidth: Dp = 138.dp
        val sirenHeight: Dp = 130.dp
        /** "Snabbit Kavach" pill height (Figma `2417:19743`, ~38) — bespoke asset height. */
        val pillHeight: Dp = 38.dp
    }

    /** SOS-active ("Help is on the way") screen — Figma node 421-15691. Assets scale by a width-
     *  fraction of the 393-wide frame; ContentScale.Fit keeps their aspect and height auto-derives.
     *  Pill stays height-driven (its exported asset carries transparent padding → a width-fraction
     *  would render it too tall). */
    object SosActive {
        val pillHeight: Dp = 38.dp             // Figma 177.5×38 (badge — height-driven)
        val glowWidthFraction: Float = 0.76f   // Figma 300 / 393 (square glow)
        val sirenWidthFraction: Float = 0.54f  // Figma 213 / 393 (aspect ~1.06)
        val shadowWidthFraction: Float = 0.79f // Figma 309 / 393 (aspect ~6.47)
    }

    /** Shared Kavach brand colors the SnabbitColors interface doesn't expose. */
    object Colors {
        /** Brand blue (activate/keep-phone CTA, wordmark, recording-dot inner). DS exposes only
         *  textInfoStrong #1B7DE9 / borderFocus — no CTA-role blue-500. */
        val kavachBlue500: Color = Color(0xFF3B82F6)
        /** Recording-dot ring, blue-100 — not on the SnabbitColors interface. */
        val recordingDotRing: Color = Color(0xFFDBEAFE)
    }

    /** Activate + monitoring Kavach card container (Figma 19-14862 / 19-15747). */
    object KavachCard {
        val gradientStopTop: Float = 0.219f      // #EBFDFF gradient stop
        val gradientStopBottom: Float = 0.565f   // #FFFFFF gradient stop
        val dotOuter: Dp = 16.dp                 // recording-dot ring
        val dotInner: Dp = 9.6.dp                // recording-dot core (Figma 9.6px)
    }

    /** Keep-phone sheet (Figma 19-15020). */
    object KeepPhoneSheet {
        val heroBandHeight: Dp = 150.dp
        val wordmarkTracking: TextUnit = (-0.5).sp
    }

    /** Low-memory pill / storage banner (Figma 19-16343). */
    object LowMemoryPill {
        val radius: Dp = 10.dp   // bottom-corner radius (md=8 / lg=12 straddle it)
    }

    /** Intro / consent sheet (Figma 421-17221). */
    object ConsentSheet {
        /** Sheet blue wash → white; no DS gradient token. Pairs with the Pass-2 rich hero. */
        val bgGradientTop: Color = Color(0xFF34A3FC)
        /** "Snabbit Kavach" title tracking (Figma Metropolis −1px). */
        val titleTracking: TextUnit = (-1).sp
        /** Feature-row + terms body, gray-600 — textBody #374151 / textSecondary #6B7280 bracket it. */
        val featureBodyColor: Color = Color(0xFF4B5563)
    }
}
