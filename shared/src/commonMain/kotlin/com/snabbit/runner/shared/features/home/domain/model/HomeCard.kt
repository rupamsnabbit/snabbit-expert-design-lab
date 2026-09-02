package com.snabbit.runner.shared.features.home.domain.model

import com.snabbit.runner.shared.features.shift.core.domain.model.AttendanceStatus
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftDay
import com.snabbit.runner.shared.features.shift.lunch.domain.model.BreakColorState

/** One card in `HomeUiState.heroCards` / `bodyCards`. */
sealed interface HomeCard {
    val key: String

    /**
     * AttendanceCard family — one DS card state per leaf (Expert App DS 2.0 →
     * AttendanceCard, node 1580-6419). New leaves land alongside their
     * composable in follow-up tasks (TodayStatus, OnLeave,
     * LeaveEndingToday, Present+Login, …) so the exhaustive `when` in
     * HomeCardRenderer is always closed.
     */
    sealed interface Attendance : HomeCard {
        /** Figma 76-35279 — "Mark attendance for tomorrow". */
        data class TomorrowProvisional(val day: ShiftDay) : Attendance {
            override val key: String get() = "attn_tomorrow"
        }

        /** Figma 76-40923 standalone; 318-43671 stacked above TomorrowProvisional. */
        data class TodayStatus(
            val day: ShiftDay,
            val status: AttendanceStatus,
            val canChange: Boolean,
            val noShowRedCards: Int,
            /** Server's `enable_login` from `RUNNER_LOGIN_HOTSPOT` AND the
             *  local login geofence (within `login_radius`, default 100 m —
             *  ECPO-808/836; geofence fails open on missing GPS/coords).
             *  Gates the Login CTA on the Present variant (Figma DS
             *  1580:6420). Stays false until the hotspot widget arrives —
             *  button shows in disabled state. */
            val canLoginNow: Boolean = false,
            /** True when this card is actually a **next-day / provisional** shift
             *  (server `RUNNER_ATTENDANCE_CONFIRMED`, or `RUNNER_ATTENDANCE_ABSENT`
             *  with `type == "TOMORROW"`) surfaced here because the projector folds
             *  Dart's separate tomorrow screens onto this card. Suppresses the
             *  today-only chrome: the FALSE_ATTENDANCE red-card change penalty and
             *  the Login CTA. Mirrors `Shift.isProvisional`. */
            val isProvisional: Boolean = false,
        ) : Attendance {
            override val key: String get() = "attn_today"
        }
    }

    /**
     * Hotspot navigation card — Figma DS 1491:13181 ("Hotspot" state) with
     * two visual sub-states from DS 76-31074:
     *
     *  - [reached] == false → "Your Hotspot" (gray) + pink "{distanceLabel} away".
     *  - [reached] == true  → "You have Reached" (green) + pink "0 km away".
     *
     * [reached] / [distanceLabel] are GPS-derived and ride from the platform
     * layer (commonMain has no geolocation); they default to not-reached
     * until that lands. [canLoginNow] is `RUNNER_LOGIN_HOTSPOT.enable_login`
     * AND the local login geofence (within `login_radius`, default 100 m —
     * ECPO-808/836) for the downstream login CTA (TL/OTP card lands in the
     * next slice).
     *
     * ponytail: the DS "Hotspot" variant has a photo strip — skipped per
     * product call. Add when the hotspot-photos data source materialises.
     */
    data class ShiftLogin(
        val hotspotName: String,
        val reached: Boolean,
        val distanceLabel: String?,
        val canLoginNow: Boolean,
        /** Hotspot coordinates — the destination handed to external maps when
         *  the runner taps the card's Map button ([HomeUiIntent.TapHotspotMap]
         *  → [HomeUiEffect.OpenDirections]). Null when the server omits them
         *  (the Map button then no-ops rather than opening a bad location). */
        val lat: Double?,
        val lng: Double?,
    ) : HomeCard {
        override val key: String get() = "hotspot_nav"
    }

    /**
     * Active-break card (the in-shift LUNCH lifecycle) — pink-gradient header
     * with the tiffin illustration, a `TIME LEFT` countdown ring, and the
     * "End Break & Start Earning" CTA. Rendered in the home body while the
     * runner is on a break.
     *
     * [remainingSeconds]/[totalSeconds] drive the ring sweep + `mm:ss`;
     * [colorState] drives the ring band (green→amber→red). Projected each
     * tick by `HomeViewModel` from the break read model + clock.
     *
     * Two genuinely separate countdowns share this card, distinguished by
     * [isStartingSoon] (Figma node 2636-52690):
     *  - starting-soon: [remainingSeconds]/[totalSeconds] count down the
     *    pre-start cooldown window (`cooldownStartMs` → `cooldownEndMs`);
     *    pill reads "LUNCH STARTING IN".
     *  - live break: [remainingSeconds]/[totalSeconds] count down the
     *    break-only window (`breakStartMs` → `breakEndMs`, i.e.
     *    `breakTotalSec`); pill reads "TIME LEFT". The cooldown time is
     *    already elapsed by then and isn't folded back in.
     *
     * @param remainingSeconds time left in the current sub-window, clamped at 0.
     * @param totalSeconds     full length of the current sub-window (ring fraction).
     * @param colorState       ring color band.
     * @param isStartingSoon   true while still inside the pre-start cooldown
     *   sub-window (`now < cooldownEndMs`).
     */
    data class Lunch(
        val remainingSeconds: Int,
        val totalSeconds: Int,
        val colorState: BreakColorState,
        val isStartingSoon: Boolean = false,
    ) : HomeCard {
        override val key: String get() = "lunch_active"
    }

    /**
     * Suspended-runner takeover card (`RUNNER_SUSPENDED`) — the CMP port of the
     * Dart `RunnerSuspended` widget. Occupies the whole hero slot (attendance /
     * map cards collapse), matching Dart's full-screen treatment. Two variants
     * keyed on [isAadhaarRekyc]:
     *  - `false` → "Your documents are being verified" + "Come Back to Work"
     *    (fires the unsuspend POST).
     *  - `true`  → "…Aadhaar verification is incomplete" + "Update Aadhaar"
     *    (bridges to the Dart re-KYC page).
     *
     * [isAadhaarRekyc] rides from `SuspendedProjector`, which reads it from the
     * bridge-fed `RunnerProfileStore` (`runners/me` → `is_aadhaar_rekyc`) — the
     * same source Dart uses; defaults `false` until Dart pushes a profile.
     */
    data class Suspended(
        val isAadhaarRekyc: Boolean,
    ) : HomeCard {
        override val key: String get() = "suspended"
    }

    /**
     * See-you-tomorrow takeover card (`RUNNER_SEE_YOU_TOMORROW`) — the CMP port
     * of Dart `see_you_tomorrow.dart`, shown after a shift logout. Like
     * [Suspended] it occupies the whole hero slot. Stateless: a static
     * "See you tomorrow!" panel with two nav CTAs ("Go to Earnings",
     * "Refer and Earn"), so it carries no data.
     */
    data object SeeYouTomorrow : HomeCard {
        override val key: String get() = "see_you_tomorrow"
    }
}
