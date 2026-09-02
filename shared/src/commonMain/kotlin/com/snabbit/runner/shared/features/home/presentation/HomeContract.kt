package com.snabbit.runner.shared.features.home.presentation

import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.home.domain.model.Banner
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.home.domain.model.MapFloatingState
import com.snabbit.runner.shared.features.home.presentation.ui.MapCoords
import com.snabbit.runner.shared.features.seva.domain.model.SevaPoint
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftPhase

/**
 * Render state for the runner Home screen.
 *
 * Modeled as a **product of small axes** rather than a single sealed `Mode`:
 *  - [phase] picks the background and the high-level card composition
 *  - [heroCards] / [bodyCards] are the actual cards rendered above / below the
 *    hero seam; the VM decides which cards for which phase
 *  - [moreFromSnabbit] is the recurring "More From Snabbit" banner list
 *  - future axes (`sheet`, `toast`, `bankDetailsMissing`, `penalty`, ...) compose
 *    here without forcing a sealed-mode case explosion
 *
 * Backgrounds derive from phase via `ShiftPhase.bg()` — the UI never branches
 * on phase directly for background choice.
 */
data class HomeUiState(
    val phase: ShiftPhase = ShiftPhase.PreShift,
    /**
     * True during first load — before `ShiftProjector` delivers its first
     * `current_state` envelope (or the load timeout fires). The hero renders
     * shimmer placeholders instead of [heroCards] while this holds. One-shot:
     * flips false on the first envelope and never returns. Defaults false so
     * previews/tests render content unless they opt in; the VM seeds it true.
     */
    val isLoading: Boolean = false,
    val heroCards: List<HomeCard> = emptyList(),
    val bodyCards: List<HomeCard> = emptyList(),
    val moreFromSnabbit: List<Banner> = emptyList(),
    /**
     * True while the first `home_banners` fetch is in flight — the section
     * renders a shimmer card instead of banners. Flips false when the fetch
     * resolves (BE list, or the Refer fallback on error/empty) and never
     * returns; a pull-to-refresh refetch keeps showing the current list.
     */
    val bannersLoading: Boolean = false,
    /** Currently-displayed sheet, or null when none. Dismissal handled via
     * [HomeUiIntent.DismissSheet]. */
    val sheet: HomeSheet? = null,
    /**
     * The single action intent currently in flight (network call pending),
     * or null when idle. Drives button-disable + double-tap protection. A
     * single slot is enough — Mark Provisional and Change Attendance fire
     * from different sheets and can't overlap. Promote to a set if a real
     * concurrent case appears.
     */
    val inFlight: HomeUiIntent? = null,
    /**
     * Floating widget rendered over the Map archetype (Figma 1582:7327) at
     * the bottom of the screen. Lives at chrome level, not inside a
     * [HomeCard], because the map is the SCREEN BACKGROUND in this
     * archetype — there's no body-scroll for a card to slot into. Null
     * outside the Map archetype.
     *
     * Derived from [phase] in [com.snabbit.runner.shared.features.home.presentation.HomeViewModel]
     * (SearchingForJobs → SearchingForJobs widget for now; more variants
     * land as their phases do).
     */
    val mapWidget: MapFloatingState? = null,
    /**
     * True when the runner tapped Logout while the BE still required
     * tomorrow's attendance (`PA_BEFORE_LOGOUT`). The VM opens the
     * MarkTomorrowAttendance sheet first; after the mark succeeds it
     * auto-chains [HomeUiIntent.TapLogout] → `shiftLogout()` so the
     * runner doesn't have to tap Logout twice. Cleared when the chain
     * fires OR the user dismisses the sheet.
     */
    val pendingLogoutAfterAttendance: Boolean = false,
    /**
     * Transient card stacked ABOVE [mapWidget] when the runner taps a seva
     * marker on the map. Auto-dismissed by the VM after 5 s. Null when no
     * announcement is active. Kept separate from [mapWidget] so the base
     * "Searching for jobs" pill remains visible underneath.
     */
    val sevaAnnouncement: MapFloatingState.Seva? = null,
    /**
     * Seva facilities near the runner (`GET /seva/nearby`), plotted as markers
     * on the Map archetype's background. Empty until the first location fix
     * resolves; refreshed on pull-to-refresh. A tapped marker's id is looked
     * up here to build [sevaAnnouncement].
     */
    val sevaPoints: List<SevaPoint> = emptyList(),
    /**
     * The map camera centre + "you are here" marker — the runner's live GPS
     * fix. Null until the first fix arrives (map falls back to
     * `MapBackgroundDefaultCoords`); retains the last fix across a transient
     * GPS drop rather than snapping back to the default.
     */
    val mapCenter: MapCoords? = null,
    /**
     * The runner's profile photo (`runners/me` → [RunnerProfileStore]), shown
     * inside the map's "you are here" marker — same source the Profile header
     * renders. Null until Dart pushes the profile (marker falls back to the
     * Person glyph).
     */
    val profilePhotoUrl: String? = null,
    /**
     * True once the runner's "Come Back to Work" request has been accepted
     * (200/409) or refused (400) — Dart parity: the CTA locks to "Request
     * submitted" and never re-fires while the `RUNNER_SUSPENDED` envelope is
     * still showing. Cleared implicitly when the runner leaves the suspended
     * state (a fresh envelope replaces the whole hero). A transport/other
     * failure does NOT set this, so the runner can retry.
     */
    val suspendRequestSubmitted: Boolean = false,
    /**
     * Backend-driven SOS pill visibility (`current_state.widget_data.sos_visibility.visible`) —
     * the backend hides SOS outside a runner's shift window. Defaults true so an absent field or a
     * DI-free preview always shows the button; only an explicit `false` hides it. Flutter parity
     * (`partner_home.dart:2289-2293`).
     */
    val sosVisible: Boolean = true,
    /** Gold-coin balance for the top-nav coins pill (`gold_coins_total` via
     *  [com.snabbit.runner.shared.features.gamification.data.GamificationProjector]). */
    val coinsCount: Int = 0,
    /** Red-card balance for the top-nav red card pill (`red_cards_total`). */
    val redCardsCount: Int = 0,
    /**
     * Profile gate shared by the coins + red card pills — Flutter parity with
     * the `HomeRewardsHeaderPill` guard: rate card v2 opted AND not
     * `RUNNER_SUSPENDED`. False until the profile loads (Dart's
     * `runnerStatus != null` guard). Tiering is not part of this gate — the
     * tier badge simply takes the coins slot in HomeTopNav when it resolves.
     */
    val rewardsPillsVisible: Boolean = false,
    /** [rewardsPillsVisible] AND the `expert_show_red_card_pill` RC flag (default off). */
    val redCardPillVisible: Boolean = false,
    /**
     * Transient feedback for the Saathi support call, surfaced as a DS `SnabbitToast` and cleared
     * by [HomeUiIntent.SaathiCallFeedbackShown]. Only set on IVR success ([SaathiCallFeedback.CallInitiated])
     * or a blank number ([SaathiCallFeedback.NumberUnavailable]); an IVR failure dials silently, so
     * the fallback path shows no toast (Flutter parity). Null when no feedback is pending.
     */
    val saathiCallFeedback: SaathiCallFeedback? = null,
    /**
     * True when the device's GPS service is off while the runner is on Home
     * (ECPO-873, reduced scope). Dart's app-startup flow owns location
     * permission/background/precise BEFORE Home mounts — this only reflects the
     * live GPS toggle, since that can flip off after Home is already showing.
     */
    val locationServiceOff: Boolean = false,
)

/**
 * Outcome of a Saathi support call worth surfacing to the runner (resolved to copy by [HomeStrings]).
 * Mirrors Flutter `CallUtils.handleCallInitiation`: a placed IVR call is confirmed, a blank number is
 * reported gracefully. The dialer fallback (IVR failure) is intentionally silent here.
 */
enum class SaathiCallFeedback { CallInitiated, NumberUnavailable }

/**
 * Sheets the Home screen can present over its content. Server-driven flows
 * map to sealed variants (one per Figma DS sheet).
 *
 * Visual shell: `com.snabbit.design.organisms.SnabbitBottomSheet`
 * (Figma DS 1825:6967 — dark X cross + gray-50 panel rounded-top-16).
 */
sealed interface HomeSheet {
    /** Whether the user can dismiss the sheet (X cross / scrim tap / back).
     *  Mirrors the Figma DS 1825:6967 scaffold's optional non-dismissable
     *  mode. Sheets that REQUIRE an action (e.g. PA-before-logout) override
     *  to `false`. */
    val dismissible: Boolean get() = true

    /**
     * Figma DS 1596:11048 — Dart `earning_loss_bottom_sheet.dart`.
     *
     * Same visual sheet, two domain entries — mirrors Flutter:
     *  - [Mode.MarkTomorrow]: Absent on the TomorrowProvisional card →
     *    Dart `provisional_attendance.dart` → `JobHttp.markAttendance`.
     *  - [Mode.ChangeToday]: Change on a Present TodayStatus card →
     *    Dart `attendance_confirmed.dart:207` → `JobHttp.changeAttendance`.
     *
     * The mode discriminator routes Absent/Present taps to the correct
     * `Confirm*` intent (mark vs change). Visuals are identical.
     *
     * @param amount pre-formatted earnings string (e.g. `"₹800"`); null →
     *               the no-amount fallback copy.
     */
    data class EarningLoss(val amount: String?, val mode: Mode = Mode.MarkTomorrow) : HomeSheet {
        enum class Mode { MarkTomorrow, ChangeToday }
    }

    /**
     * Figma DS 1583:6506 — Dart `provisional_attendance_before_logout.dart`.
     * Server-driven via the `PA_BEFORE_LOGOUT` widget. Forces the runner to
     * mark tomorrow's attendance before logging out — typically rendered
     * non-dismissable, but the DS scaffold supports the dismissable mode for
     * the design-review preview.
     */
    data class MarkTomorrowAttendance(
        val dateLabel: String,
        val shiftWindowLabel: String,
        override val dismissible: Boolean = false,
    ) : HomeSheet

    /**
     * Dart `attendance_change_sheet.dart`. Triggered on Change when either:
     *  - the runner is Absent / NoShow today (Figma DS 318-44202, plain chrome
     *    — `showPenaltyChrome == false`), or
     *  - the runner is Present with an active FALSE_ATTENDANCE sheet warning
     *    (the `RUNNER_LOGIN_HOTSPOT` flow, Dart `job_login.dart:330` →
     *    `AttendanceChangeSheet`) — penalty chrome (red-card cluster + CTA
     *    badges).
     *
     * The penalty variant is data-driven: `HomeTabContent` folds the
     * FALSE_ATTENDANCE warning into a `ChangeAttendancePenalty` and hands it to
     * the sheet; a null penalty renders the plain shape (same
     * `AttendanceSheetShell` as [MarkTomorrowAttendance] — illustration + dated
     * box + Absent/Present).
     */
    data class ChangeAttendanceConfirm(
        val dateLabel: String,
        val shiftWindowLabel: String,
        /** True when the underlying shift is next-day / provisional — suppresses
         *  the FALSE_ATTENDANCE red-card penalty chrome on this sheet, which
         *  applies only to a live today shift (Dart's tomorrow surfaces never
         *  show it). */
        val isProvisional: Boolean = false,
    ) : HomeSheet

    /**
     * Figma DS 1597:6691 — Dart `widgets/gamification/waiver_bottom_sheet.dart`.
     * Server-driven via `status: WAIVED` in the post-action response of any
     * gamified flow. Single "I will not repeat again" acknowledgement;
     * non-dismissable per the DS spec.
     */
    data class RedCardsWaived(
        val redCardCount: Int,
        override val dismissible: Boolean = false,
    ) : HomeSheet

    /**
     * Break-offer sheet — auto-opened on the `LUNCH_REQUEST` envelope (mirrors
     * how `PA_BEFORE_LOGOUT` auto-mounts [MarkTomorrowAttendance]). "Take break"
     * → [HomeUiIntent.AcceptLunch]; "I don't need a break" → [HomeUiIntent.DenyLunch].
     * Visual design TBD — rendered on the existing sheet shell until the Figma
     * for the request affordance lands.
     */
    data object LunchRequest : HomeSheet

    /**
     * End-break confirmation — opened by the active-break card's
     * "End Break & Start Earning" CTA ([HomeUiIntent.RequestEndBreak]). Title
     * "Are you sure you want to end the break?", primary "End Break"
     * ([HomeUiIntent.ConfirmEndBreak]), secondary "Go Back" + X
     * ([HomeUiIntent.DismissSheet]). Figma "Shift & Job Lifecycle DS".
     */
    data object EndBreakConfirm : HomeSheet

    /** Runner-consent sheet for Snabbit Kavach — shown on home landing until consent is given.
     *  Non-dismissable: the only exit is granting consent (no close/scrim/back dismiss). */
    data object KavachConsent : HomeSheet {
        override val dismissible: Boolean get() = false
    }
}

/**
 * Every user action on the Home screen, as data. Sent through
 * [HomeViewModel.onIntent] — a single funnel so all state transitions live in
 * one exhaustive `when`.
 *
 * Tap intents fire for this slice but the reducer treats them as no-ops; they
 * become analytics + navigation effects when their seams land.
 */
sealed interface HomeUiIntent {
    /** Initial load / reload (re-fetch when DataSource exists; no-op for now). */
    data object Load : HomeUiIntent

    /** Home page scrolled to the "More From Snabbit" strip — analytics only
     *  (`home_screen_scrolled`), fired once per mount from the scroll observer. */
    data object HomeScrolled : HomeUiIntent

    data object TapBell : HomeUiIntent
    data object TapSos : HomeUiIntent
    data object TapSaathi : HomeUiIntent
    data object TapCoins : HomeUiIntent

    /** Top-nav red card pill — analytics + the red-cards rewards webview. */
    data object TapRedCards : HomeUiIntent

    /** The Saathi-call feedback toast finished (auto-dismiss or tap) — clears
     *  [HomeUiState.saathiCallFeedback] so it doesn't re-show on recomposition. */
    data object SaathiCallFeedbackShown : HomeUiIntent

    /** The runner tapped a "More From Snabbit" banner — `id` is `Banner.id`. */
    data class TapBanner(val id: String) : HomeUiIntent

    // ── Tomorrow card actions ─────────────────────────────────────────
    /** Runner tapped "Absent" on the TomorrowProvisional card. Opens the
     *  EarningLoss confirmation sheet (Figma DS 1825:6967 host + Dart
     *  EarningLossBottomSheet content). */
    data object TapAbsentTomorrow : HomeUiIntent

    /** Runner confirmed the mark from inside the EarningLoss sheet (or
     *  tapped Present directly on the card). Sheet closes; the actual
     *  `JobHttp.markAttendance` call is wired in PR-2. */
    data class ConfirmMarkProvisional(val present: Boolean) : HomeUiIntent

    /** Generic sheet dismissal (X tap, scrim tap, back press). */
    data object DismissSheet : HomeUiIntent

    /** User tapped "Turn on GPS" on the enable-location sheet. */
    data object EnableLocation : HomeUiIntent

    /** Kavach consent sheet → "I Agree" (records runner consent). */
    data object ConfirmKavachConsent : HomeUiIntent

    /** Confirm flip in the ChangeAttendanceConfirm sheet (PR-3 wires API). */
    data class ConfirmChangeAttendance(val present: Boolean) : HomeUiIntent

    /** "I will not repeat again" tap inside the Waiver sheet. */
    data object AcknowledgeWaiver : HomeUiIntent

    /**
     * Show the "red cards waived off" sheet with [redCardCount] cards. Fired by
     * the host when a gamification post-action outcome has `status == waived`
     * (routed from `PostActionOverlayHost.onWaived`).
     */
    data class ShowRedCardsWaived(val redCardCount: Int) : HomeUiIntent

    // ── Today card actions ───────────────────────────────────────────
    /** Runner tapped "Change" on the TodayStatus card. Opens the
     *  ChangeAttendanceConfirm sheet (Figma DS 1596:11119). */
    data object TapChangeAttendance : HomeUiIntent

    // ── Hotspot navigation card actions ──────────────────────────────
    /** Runner tapped the hotspot nav card body (anywhere except the Map
     *  button). Opens external maps in directions mode to the hotspot, same
     *  as [TapHotspotMap] — but kept a SEPARATE intent so the card-body tap
     *  and the Map-chip tap can carry distinct analytics events. Null coords
     *  no-op (nothing to navigate to). */
    data class TapHotspot(val lat: Double?, val lng: Double?) : HomeUiIntent

    /** Runner tapped the Map button on the hotspot nav card — opens external
     *  maps in directions mode to the hotspot ([lat]/[lng]). The VM emits
     *  [HomeUiEffect.OpenDirections]; null coords no-op (nothing to navigate
     *  to). Mirrors [NavigateSeva]. */
    data class TapHotspotMap(val lat: Double?, val lng: Double?) : HomeUiIntent

    /** Runner tapped Login on the Today Present card. Fires only when the
     *  server's `enable_login` is true; reducer no-ops until the login
     *  flow lands. */
    data object TapLogin : HomeUiIntent

    /** Runner tapped Logout on the map floating widget (Figma 1582:9128).
     *  Reducer no-ops until the logout flow is wired (the Flutter side
     *  already owns logout end-to-end). */
    data object TapLogout : HomeUiIntent

    // ── Break (lunch) actions ────────────────────────────────────────
    /** Runner tapped the "Take break" chip on the map lunch pill — opens
     *  the LunchRequest confirm sheet manually (the auto-open via
     *  `observeLunchRequestSheet` already fired once on phase entry; this
     *  re-opens if the runner dismissed it, and gives an explicit affordance
     *  during LUNCH_COOLDOWN too). */
    data object OpenLunchRequestSheet : HomeUiIntent

    /** "Take break" in the LUNCH_REQUEST sheet → `POST .../lunch/accept`. */
    data object AcceptLunch : HomeUiIntent

    /** "I don't need a break" in the LUNCH_REQUEST sheet → `POST .../lunch/deny`. */
    data object DenyLunch : HomeUiIntent

    /** "End Break & Start Earning" on the active-break card → opens the
     *  end-break confirm sheet (does NOT end the break directly). */
    data object RequestEndBreak : HomeUiIntent

    /** "End Break" in the confirm sheet → `POST .../break/end`. */
    data object ConfirmEndBreak : HomeUiIntent

    /** Runner tapped a seva marker on the map. [sevaId] identifies which
     *  facility (from [HomeUiState.sevaPoints]); the VM looks it up to fill
     *  the seva helper card (Figma 969:56727), which auto-dismisses after 5s. */
    data class TapSeva(val sevaId: String) : HomeUiIntent

    // ── Suspended card actions (RUNNER_SUSPENDED) ────────────────────
    /** "Come Back to Work" on the non-Aadhaar suspended card → fires the
     *  unsuspend POST. No-op once already submitted / in-flight. */
    data object RequestComeBack : HomeUiIntent

    /** "Update Aadhaar" on the Aadhaar-reKYC suspended card → emits
     *  [HomeUiEffect.NavigateToAadhaarReKyc] (bridges to the Dart re-KYC
     *  page). No unsuspend call on this path — Dart parity. */
    data object UpdateAadhaar : HomeUiIntent

    /** "Go to Earnings" on the suspended / see-you-tomorrow card → emits
     *  [HomeUiEffect.NavigateToEarnings] (bridges to the Dart earnings page). */
    data object TapGoToEarnings : HomeUiIntent

    /** "Refer and Earn" on the see-you-tomorrow card → routes through
     *  `ProfileRouteDecider.referAndEarn` (the shared refer decider), the same
     *  destination as the Refer banner / Profile tile. */
    data object TapReferAndEarn : HomeUiIntent

    /** Runner tapped the X pill on the seva helper card. Clears the
     *  announcement immediately (cancels the 5s auto-dismiss). */
    data object DismissSevaHelper : HomeUiIntent

    /** Runner tapped the seva floating widget — hand off to external maps for
     *  directions to [lat]/[lng]. The VM emits [HomeUiEffect.OpenDirections]. */
    data class NavigateSeva(val lat: Double, val lng: Double) : HomeUiIntent
}

/**
 * One-shot side effects emitted by [HomeViewModel] — UI-observable events that
 * MUST NOT replay when the UI re-subscribes (e.g. on config change, recompose
 * across navigation). Surfaced via [HomeViewModel.effects] as a `SharedFlow`,
 * not a `StateFlow`, so a re-collector doesn't see prior snackbars / nav
 * commands.
 *
 * Strict MVI separation: persistent screen state goes on [HomeUiState];
 * transient one-shots go here.
 */
sealed interface HomeUiEffect {
    /** Show a transient error snackbar. Carries the domain [error], which the
     *  screen resolves to copy via [HomeStrings.errorFor] so the VM holds no
     *  user-facing text. [message] is an optional server-supplied override shown
     *  verbatim when present (e.g. the unsuspend endpoint's body `message`/`detail`,
     *  Dart parity) — falls back to the typed-error copy when null. */
    data class ShowSnackbar(val error: RunnerActionError, val message: String? = null) : HomeUiEffect

    /**
     * Navigate into the shift-login flow (intro sheet → camera → upload).
     * Fired when the user taps Login on the `RUNNER_LOGIN_HOTSPOT` card. The
     * Home-tab host pushes the [com.snabbit.runner.shared.features.shift.presentation.login.ShiftLogin]
     * destination onto the `NavigationController`; the flow pops back on its Finish.
     */
    data object NavigateToShiftLogin : HomeUiEffect

    /**
     * Open external maps in directions mode to [lat]/[lng]. The UI hands the
     * built maps URI to the platform (`LocalUriHandler`) — Google Maps if
     * installed, else the browser / system chooser.
     */
    data class OpenDirections(val lat: Double, val lng: Double) : HomeUiEffect

    /**
     * Open the Dart Aadhaar re-KYC page (`/aadhaar-reverification`). Fired from
     * the Aadhaar-reKYC suspended card's "Update Aadhaar" CTA. The Home-tab host
     * bridges it to Flutter via `KmpNavigationBridge` — the page is not migrated
     * to CMP and owns its own post-verify refresh.
     */
    data object NavigateToAadhaarReKyc : HomeUiEffect

    /**
     * Open the Dart earnings page. Fired from the suspended card's "Go to
     * Earnings" CTA (Dart `navigateToEarningsPage`). Bridged to Flutter by the
     * Home-tab host — earnings is not migrated to CMP. [rateCardV2Effective]
     * mirrors Dart's `user.isRateCardV2Effective` branch: `true` opens the
     * monthly-summary webview, `false` the native Payout Home page.
     */
    data class NavigateToEarnings(val rateCardV2Effective: Boolean) : HomeUiEffect

    /**
     * Open the shift-end earnings summary after a shift logout. Fired only from
     * the attendance-chained logout (Dart `PA_BEFORE_LOGOUT`), and only for
     * rate-card-v2 runners — mirroring Dart's "View Today's Earnings" button,
     * which is v2-only and absent on the plain `RUNNER_LOGOUT` path. Bridged by
     * the Home-tab host to the Dart `v1/payouts/shift-end-summary` webview.
     */
    data object NavigateToShiftEndEarnings : HomeUiEffect
}

