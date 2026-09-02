package com.snabbit.runner.shared.features.home.domain.model

/**
 * State for the floating widget that sits at the bottom of the map card —
 * Figma DS Expert-App-2.O 1582:7472 ("Map widget").
 *
 * One variant per lifecycle phase the map card surfaces:
 *  - [SearchingForJobs]: pre-job, "Searching for jobs nearby" pill.
 *  - [Seva]:             job assigned, customer name + Seva chip + distance.
 *  - [LunchRequest]:     break offered, tiffin card with title.
 *  - [Lunch]:            lunch window incoming, "Lunch in {time}" warmpill.
 *  - [Logout]:           shift end approaching, "Shift ends at {time}" + Logout CTA.
 *
 * Labels are pre-formatted strings (server-localized in production); the
 * widget composables render them verbatim. The envelope → variant mapping
 * lives in [com.snabbit.runner.shared.features.shift.core.data.ShiftProjector] and is
 * deferred to the next slice — until then the mapper hardcodes
 * [SearchingForJobs].
 */
sealed interface MapFloatingState {
    /** Default pre-job widget — Figma 1582:7470. */
    data object SearchingForJobs : MapFloatingState

    /**
     * Job-assigned widget — Figma 1582:7471. Also drives the seva-marker
     * helper card (Figma 969:56727), which stacks above the base floating
     * pill when the runner taps a seva marker on the map.
     *
     * @param customerName     headline (e.g. `"Jyoti Nivas"`).
     * @param tagLabel         dark chip text (e.g. `"Seva"`).
     * @param address          street address shown under the name. Empty
     *                         hides the row.
     * @param distanceLabel    pink subtext (e.g. `"300 meters away"`). Empty
     *                         hides the row.
     * @param lat / @param lng facility coordinates — tapping the widget opens
     *                         external maps in directions mode to this point.
     */
    data class Seva(
        /** Facility id — echoed back so the map can render that pin in its
         *  selected state while this card is up. */
        val id: String,
        val customerName: String,
        val tagLabel: String,
        val address: String = "",
        val distanceLabel: String = "",
        val lat: Double,
        val lng: Double,
    ) : MapFloatingState

    /** Break-offer card — `LUNCH_REQUEST` envelope. Tiffin illustration + title pill.
     *  The label is resolved in the widget (from HomeStrings), not baked here. */
    data object LunchRequest : MapFloatingState

    /**
     * Lunch-incoming widget — Figma 1582:7550. Warm-cream gradient pill.
     *
     * @param remainingSeconds seconds until the break starts. The `mm:ss` label
     *   is formatted in the widget (mirrors [HomeCard.Lunch], which also carries
     *   raw seconds), so no copy lives in this state.
     */
    data class Lunch(val remainingSeconds: Int) : MapFloatingState

    /**
     * End-of-shift widget — Figma 1582:9128. White pill + pink Logout CTA.
     *
     * @param shiftEndLabel pre-formatted clock time (e.g. `"Shift ends at 6:00PM"`).
     * @param ctaEnabled false during the pre-logout reminder window (shift
     *   end − 30 min, ECPO-819): the pill shows with the Logout button
     *   dimmed and inert — logout isn't allowed until shift end, when the
     *   envelope flips to `RUNNER_LOGOUT` and the CTA goes live.
     */
    data class Logout(
        val shiftEndLabel: String,
        val ctaEnabled: Boolean = true,
    ) : MapFloatingState
}
